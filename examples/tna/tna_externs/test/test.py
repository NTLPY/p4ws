#
# Unit tests for the TNA ECMP example
# Copyright 2025 NTLPY
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: NTLPY <59137305+NTLPY@users.noreply.github.com>
#

from config import *
import random

import bfrt_grpc.client as gc
import ptf.testutils as testutils
from bfruntime_client_base_tests import BfRuntimeTest
from p4testutils.misc_utils import *
from scapy.packet import Packet, bind_layers, Raw
from scapy.fields import BitField
from scapy.layers.l2 import Ether
from scapy.layers.inet import UDP

dev_id = 0
p4_program_name = "tna_externs"

logger = get_logger()
swports = get_sw_ports()


class Debug(Packet):
    name = "debug"
    fields_desc = [
        BitField("op", 0, 32),
        BitField("in8", 0, 8),
        BitField("in16", 0, 16),
        BitField("in32", 0, 32),
        BitField("out8", 0, 8),
        BitField("out16", 0, 16),
        BitField("out32", 0, 32)
    ]


bind_layers(UDP, Debug, dport=DEBUG_PORT)


def get_any_packet(test, port):
    result = testutils.dp_poll(test, 0, port)
    assert isinstance(result, test.dataplane.PollSuccess)
    out_raw = result.packet
    out = Ether()
    out.dissect(out_raw)
    return out[Debug]


def put_debug(test, port, debug):
    pkt = simple_udp_packet(udp_dport=DEBUG_PORT, udp_payload=debug.build())
    testutils.send_packet(test, port, pkt)


def get_debug(test, port):
    out = get_any_packet(test, port)
    debug = out[Debug]
    debug.payload = Raw()
    return debug


class HashEcmpTest(BfRuntimeTest):
    def setUp(self):
        client_id = 0
        BfRuntimeTest.setUp(self, client_id, p4_program_name)
        setup_random()

    def runTest(self):
        print("*** DEBUG_OP_HASH_IDENTITY_32")
        for data in [0xF, 0xFF, 0xFFF, 0xFFFF, 0xFFFFF, 0xFFFFFF, 0xFFFFFFFF,
                     0x1, 0x12, 0x123, 0x1234, 0x12345, 0x123456, 0x1234567, 0x12345678]:
            put_debug(self, 0, Debug(op=DEBUG_OP_HASH_IDENTITY_32, in32=data))
            debug = get_debug(self, 0)
            print("Hash<bit<8>>(HashAlgorithm_t.IDENTITY).get((bit<32>)0x{:08X}) = 0x{:08X}".format(
                data, debug.out8))
            print("Hash<bit<16>>(HashAlgorithm_t.IDENTITY).get((bit<32>)0x{:08X}) = 0x{:08X}".format(
                data, debug.out16))
            print("Hash<bit<32>>(HashAlgorithm_t.IDENTITY).get((bit<32>)0x{:08X}) = 0x{:08X}".format(
                data, debug.out32))


class Wred:
    def __init__(self, obj: gc._Table, target: gc.Target):
        self.obj = obj
        self.target = target

        self.__load_cache()

    def __make_key(self, index: int):
        return self.obj.make_key([gc.KeyTuple("$WRED_INDEX", index)])

    @staticmethod
    def __parse_key(key: gc._Key):
        key_fields = key.to_dict()
        index = key_fields["$WRED_INDEX"]["value"]
        return index

    def __make_data(self, time_constant_ns: float, min_thresh_cells: int,
                    max_thresh_cells: int, max_probability: float):
        return self.obj.make_data([
            gc.DataTuple("$WRED_SPEC_TIME_CONSTANT_NS",
                         float_val=time_constant_ns),
            gc.DataTuple("$WRED_SPEC_MIN_THRESH_CELLS", min_thresh_cells),
            gc.DataTuple("$WRED_SPEC_MAX_THRESH_CELLS", max_thresh_cells),
            gc.DataTuple("$WRED_SPEC_MAX_PROBABILITY",
                         float_val=max_probability)
        ])

    @staticmethod
    def __parse_data(data: gc._Data):
        data_fields = data.to_dict()
        return {
            "time_constant_ns": data_fields["$WRED_SPEC_TIME_CONSTANT_NS"],
            "min_thresh_cells": data_fields["$WRED_SPEC_MIN_THRESH_CELLS"],
            "max_thresh_cells": data_fields["$WRED_SPEC_MAX_THRESH_CELLS"],
            "max_probability": data_fields["$WRED_SPEC_MAX_PROBABILITY"]
        }

    @staticmethod
    def __parse_entry(key: gc._Key, data: gc._Data):
        return Wred.__parse_key(key), Wred.__parse_data(data)

    def __load_cache(self):
        __cache = {}
        for data, key in self.obj.entry_get(self.target):
            index, data_dict = self.__parse_entry(key, data)
            __cache[index] = data_dict
        self.__cache = __cache

    def set(self,
            index: int,
            min_thresh_cells: int = 0xFF000000,
            max_thresh_cells: int = 0xFF000000,
            max_probability: float = 0.0,
            time_constant_ns: float = 0.7867820858955383):
        key = self.__make_key(index)
        data = self.__make_data(
            time_constant_ns, min_thresh_cells, max_thresh_cells, max_probability)
        self.obj.entry_mod(self.target, [key], [data])
        del self.__cache[index]

    def get(self, index: int):
        if index not in self.__cache:
            key = self.__make_key(index)
            for data, key in self.obj.entry_get(self.target, [key]):
                index, data_dict = self.__parse_entry(key, data)
                self.__cache[index] = data_dict

        return self.__cache[index]

    def reset(self, index: int):
        key = self.obj.make_key([gc.KeyTuple("$WRED_INDEX", index)])
        self.obj.entry_del(self.target, [key])
        del self.__cache[index]

    @staticmethod
    def expected_drop(num_cells: int,
                      min_thresh_cells: int = 0xFF000000,
                      max_thresh_cells: int = 0xFF000000,
                      max_probability: float = 0.0,
                      time_constant_ns: float = 0.7867820858955383):
        if num_cells < min_thresh_cells:
            return 0.0
        elif num_cells > max_thresh_cells:
            return 1
        else:
            drop_probability = (num_cells - min_thresh_cells) / \
                (max_thresh_cells - min_thresh_cells) * max_probability
            return drop_probability


class WredTest(BfRuntimeTest):
    def setUp(self):
        client_id = 0
        BfRuntimeTest.setUp(self, client_id, p4_program_name)
        setup_random()

        bfrt_info = self.interface.bfrt_info_get()
        self.wred_table: gc._Table = bfrt_info.table_get("SwitchIngress.wred")

    def runTest(self):
        print("*** DEBUG_OP_WRED")

        target = gc.Target(device_id=0, pipe_id=0xffff)
        wred = Wred(self.wred_table, target)

        kmin, kmax, pmax = 1280, 5120, 0.1

        wred.set(0, min_thresh_cells=kmin,
                 max_thresh_cells=kmax, max_probability=pmax, time_constant_ns=0.7867820858955383)

        print("WRED Kmin={} Kmax={} Pmax={:.2f}".format(kmin, kmax, pmax))
        cells_list = [0] + list(range(kmin, kmax + 320 + 1, 320))
        for num_cells in cells_list:
            total_cnt = 2000
            drop_cnt = 0
            for i in range(total_cnt):
                put_debug(self, 0, Debug(op=DEBUG_OP_WRED, in32=num_cells))
                drop = get_debug(self, 0).out8
                assert drop in [0, 1], "WRED output should be 0 or 1"
                drop_cnt += drop

            print("WRED drop at cell {:4d}: {:.3f} - {:.3f}".format(num_cells, drop_cnt / total_cnt,
                  Wred.expected_drop(num_cells, kmin, kmax, pmax)))

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

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

import random

import bfrt_grpc.client as gc
import ptf.testutils as testutils
from bfruntime_client_base_tests import BfRuntimeTest
from p4testutils.misc_utils import *

dev_id = 0
p4_program_name = "tna_ecmp"

logger = get_logger()
swports = get_sw_ports()


class EcmpTest(BfRuntimeTest):
    """@brief Populate the selector table and the action profile.
    """

    def setUp(self):
        client_id = 0
        BfRuntimeTest.setUp(self, client_id, p4_program_name)
        setup_random()

    def runTest(self):
        ig_port = swports[1]
        eg_ports = swports[2:][:4]

        target = gc.Target(device_id=dev_id, pipe_id=0xffff)

        # Get bfrt_info and set it as part of the test
        bfrt_info = self.interface.bfrt_info_get(p4_program_name)
        ip_lpm_table: gc._Table = bfrt_info.table_get("SwitchIngress.ip_lpm")
        ip_lpm_table.info.key_field_annotation_add("hdr.ip.daddr", "ipv4")
        ip_ecmp_ap: gc._Table = bfrt_info.table_get("SwitchIngress.ip_ecmp_ap")
        ip_ecmp: gc._Table = bfrt_info.table_get("SwitchIngress.ip_ecmp")

        # Add entry for each port
        ip_ecmp_ap.entry_add(
            target,
            [ip_ecmp_ap.make_key([gc.KeyTuple('$ACTION_MEMBER_ID',
                                              port)]) for port in swports],
            [ip_ecmp_ap.make_data([gc.DataTuple('port', port)],
                                  'SwitchIngress.set_port') for port in swports])

        # Add new member to ECMP group
        ip_dst = '192.168.0.2'
        group_id = 0
        group_members = eg_ports
        group_member_status = [True] * len(group_members)
        ip_ecmp.entry_add(
            target,
            [ip_ecmp.make_key([gc.KeyTuple('$SELECTOR_GROUP_ID', group_id)])],
            [ip_ecmp.make_data([gc.DataTuple('$MAX_GROUP_SIZE', 256),
                                gc.DataTuple('$ACTION_MEMBER_ID',
                                             int_arr_val=group_members),
                                gc.DataTuple('$ACTION_MEMBER_STATUS',
                                             bool_arr_val=group_member_status)])])
        ip_lpm_table.entry_add(
            target,
            [ip_lpm_table.make_key(
                [gc.KeyTuple('hdr.ip.daddr', ip_dst, prefix_len=24)])],
            [ip_lpm_table.make_data([gc.DataTuple('$SELECTOR_GROUP_ID', group_id)])])

        stats = [0 for _ in range(len(eg_ports))]
        try:
            logger.info("Start sending 400 packets to port %d", ig_port)
            for _ in range(400):
                ip_src = '{}.{}.{}.{}'.format(
                    *(random.randint(1, 255) for _ in range(4)))
                udp_dport = random.randint(1, 65535)
                udp_sport = random.randint(1024, 65535)

                pkt = testutils.simple_udp_packet(
                    ip_src=ip_src, udp_dport=udp_dport, udp_sport=udp_sport)

                testutils.send_packet(self, ig_port, pkt)

                idx = testutils.verify_any_packet_any_port(
                    self, [pkt], eg_ports)

                stats[idx] += 1
        finally:
            #
            # We must clean up in the reverse order of creation
            #
            ip_lpm_table.entry_del(
                target,
                [ip_lpm_table.make_key(
                    [gc.KeyTuple('hdr.ip.daddr', ip_dst, prefix_len=24)])])
            ip_ecmp.entry_del(
                target,
                [ip_ecmp.make_key([gc.KeyTuple('$SELECTOR_GROUP_ID', group_id)])])

            ip_ecmp_ap.entry_del(
                target,
                [ip_ecmp_ap.make_key([gc.KeyTuple('$ACTION_MEMBER_ID',
                                                  port)]) for port in swports])

        sum_stats = sum(stats)
        stats = [int(c / sum_stats * 100) for c in stats]
        logger.info("Packets received on each port: %s",
                    ' '.join('{}%'.format(s) for s in stats))

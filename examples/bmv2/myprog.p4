/**
 * Copyright 2025 P4WS
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Author: NTLPY <59137305+NTLPY@users.noreply.github.com>
 */

#define V1MODEL_VERSION 20200408
#include <p4ws/arch.p4>
#include <p4ws/utils.p4>
#include <p4ws/ether.p4>
#include <p4ws/ip.p4>

struct header_t {
    eth_h eth;
    ip_h ip;
}

struct metadata_t {}

// ---------------------------------------------------------------------------
// Parser
// ---------------------------------------------------------------------------
parser SwitchParser(
        packet_in pkt,
        out header_t hdr,
        inout metadata_t md,
        inout standard_metadata_t intr_md) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.eth);
        transition parse_ipv4;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ip);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Verify Checksum
// ---------------------------------------------------------------------------
control SwitchVerifyChecksum(inout header_t hdr, inout metadata_t md) {
    apply {  }
}

// ---------------------------------------------------------------------------
// Ingress Processing
// ---------------------------------------------------------------------------
control SwitchIngress(
        inout header_t hdr,
        inout metadata_t md,
        inout standard_metadata_t intr_md) {

    bit<16> vrf = (bit<16>)intr_md.ingress_port;
    bit<2> color;
    direct_counter(CounterType.packets_and_bytes) cntr;
    direct_meter<bit<2>>(MeterType.bytes) mtr;

    action hit(PortId_t port) {
        intr_md.egress_spec = port;
        mtr.read(color);
    }

    action miss() {
        mark_to_drop(intr_md); // Drop packet.
    }

    table forward {
        key = {
            hdr.eth.dest : exact;
        }

        actions = {
            hit;
            @defaultonly miss;
        }

        const default_action = miss;
        size = 1024;
    }

    action route(mac_addr_t srcMac, mac_addr_t dstMac, PortId_t dst_port) {
        intr_md.egress_spec = dst_port;
        hdr.eth.dest = dstMac;
        hdr.eth.source = srcMac;
    }

    action nat(ip_addr_t srcAddr, ip_addr_t dstAddr, PortId_t dst_port) {
        intr_md.egress_spec = dst_port;
        hdr.ip.daddr = dstAddr;
        hdr.ip.saddr = srcAddr;
    }

    table ipRoute {
        key = {
            vrf : exact;
            hdr.ip.daddr : exact;
        }

        actions = {
            route;
            nat;
        }

        size = 1024;
        counters = cntr;
        meters = mtr;
    }

    action nop() { }

    table forward_timeout {
        key = {
            hdr.eth.dest : exact;
        }

        actions = {
            hit;
	        nop;
        }

        const default_action = nop();
        size = 200000;
    }

    apply {
        forward.apply();
        vrf = 16w0;
        ipRoute.apply();
        forward_timeout.apply();
    }
}

// ---------------------------------------------------------------------------
// Egress Processing
// ---------------------------------------------------------------------------
control SwitchEgress(
        inout header_t hdr,
        inout metadata_t md,
        inout standard_metadata_t intr_md) {

    apply { }
}

// ---------------------------------------------------------------------------
// Compute Checksum
// ---------------------------------------------------------------------------
control SwitchComputeChecksum(
        inout header_t hdr,
        inout metadata_t md) {

    apply {
        update_checksum(hdr.ip.isValid(), {
            hdr.ip.version,
            hdr.ip.ihl,
            hdr.ip.tos,
            hdr.ip.tot_len,
            hdr.ip.id,
            hdr.ip.flags,
            hdr.ip.frag_off,
            hdr.ip.ttl,
            hdr.ip.protocol,
            hdr.ip.saddr,
            hdr.ip.daddr},
            hdr.ip.check, HashAlgorithm.csum16);
    }
}

// ---------------------------------------------------------------------------
// Deparser
// ---------------------------------------------------------------------------
control SwitchDeparser(
        packet_out pkt,
        in header_t hdr) {

    apply {
        pkt.emit(hdr);
    }
}

V1Switch(SwitchParser(),
         SwitchVerifyChecksum(),
         SwitchIngress(),
         SwitchEgress(),
         SwitchComputeChecksum(),
         SwitchDeparser()) main;

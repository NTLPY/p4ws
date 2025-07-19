/**
 * Copyright 2024 Intel Corporation
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

#include <core.p4>
#if __TARGET_TOFINO__ == 3
#include <t3na.p4>
#elif __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

#include <utils.p4>
#include <ether.p4>
#include <ip.p4>

struct header_t {
    eth_h eth;
    ip_h ip;
}

struct metadata_t {}

// ---------------------------------------------------------------------------
// Ingress parser
// ---------------------------------------------------------------------------
parser SwitchIngressParser(
        packet_in pkt,
        out header_t hdr,
        out metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    TofinoIngressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, ig_intr_md);
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
// Ingress Deparser
// ---------------------------------------------------------------------------
control SwitchIngressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

    Checksum() ipv4_checksum;

    apply {
        hdr.ip.check = ipv4_checksum.update({
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
            hdr.ip.daddr});

         pkt.emit(hdr);
    }
}

control SwitchIngress(
        inout header_t hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    bit<16> vrf = (bit<16>)ig_intr_md.ingress_port;
    bit<2> color;
    DirectCounter<bit<32>>(CounterType_t.PACKETS_AND_BYTES) cntr;
    DirectMeter(MeterType_t.BYTES) meter;

    action hit(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action miss(bit<3> drop) {
        ig_dprsr_md.drop_ctl = drop; // Drop packet.
    }

    table forward {
        key = {
            hdr.eth.dest : exact;
        }

        actions = {
            hit;
            @defaultonly miss;
        }

        const default_action = miss(0x1);
        size = 1024;
    }

    action route(mac_addr_t srcMac, mac_addr_t dstMac, PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        hdr.eth.dest = dstMac;
        hdr.eth.source = srcMac;
        cntr.count();
        color = (bit<2>) meter.execute();
        ig_dprsr_md.drop_ctl = 0;
    }

    action nat(ip_addr_t srcAddr, ip_addr_t dstAddr, PortId_t dst_port) {
        ig_tm_md.ucast_egress_port = dst_port;
        hdr.ip.daddr = dstAddr;
        hdr.ip.saddr = srcAddr;
        cntr.count();
        color = (bit<2>) meter.execute();
        ig_dprsr_md.drop_ctl = 0;
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
        meters = meter;
    }

    action nop() {}

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

        // No need for egress processing, skip it and use empty controls for egress.
        ig_tm_md.bypass_egress = 1w1;
    }
}

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         EmptyEgressParser(),
         EmptyEgress(),
         EmptyEgressDeparser()) pipe;

Switch(pipe) main;

/**
 * Copyright 2025 NTLPY
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
 * See the License for the specific language governing perdropions and
 * limitations under the License.
 *
 * Author: NTLPY <59137305+NTLPY@users.noreply.github.com>
 */

#include <p4ws/arch.p4>
#include <p4ws/utils.p4>
#include <p4ws/ether.p4>
#include <p4ws/ip.p4>
#include <p4ws/ipv6.p4>
#include <p4ws/tcp.p4>
#include <p4ws/udp.p4>
#include <p4ws/infiniband/base.p4>
#include <p4ws/infiniband/transport.p4>
#include <p4ws/infiniband/parser.p4>
#include <p4ws/qos/ecn.p4>

struct header_t {
    eth_h eth;
    ip_h ip;
    ipv6_h ipv6;
    tcp_h tcp;
    udp_h udp;

    ib_hdr_t ib_hdr;
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
    InfiniBandParser() ib_parser;

    state start {
        tofino_parser.apply(pkt, ig_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.eth);
        transition select(hdr.eth.proto)
        {
            ether_type_t.IP: parse_ip;
            default: accept;
        }
    }

    state parse_ip {
        pkt.extract(hdr.ip);
        transition select(hdr.ip.protocol)
        {
            ip_protocol_t.TCP: parse_tcp;
            ip_protocol_t.UDP: parse_udp;
            default: accept;
        }
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition select(hdr.ipv6.nexthdr)
        {
            ip_protocol_t.TCP: parse_tcp;
            ip_protocol_t.UDP: parse_udp;
            default: accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dest) {
            ROCE_V2_UDP_DPORT : parse_ib;
            default: accept;
        }
    }

    state parse_ib {
        ib_parser.apply(pkt, hdr.ib_hdr);
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
    }
}

// ---------------------------------------------------------------------------
// Egress parser
// ---------------------------------------------------------------------------
parser SwitchEgressParser(
        packet_in pkt,
        out header_t hdr,
        out metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {

    TofinoEgressParser() tofino_parser;
    InfiniBandParser() ib_parser;

    state start {
        tofino_parser.apply(pkt, eg_intr_md);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.eth);
        transition select(hdr.eth.proto)
        {
            ether_type_t.IP: parse_ip;
            default: accept;
        }
    }

    state parse_ip {
        pkt.extract(hdr.ip);
        transition select(hdr.ip.protocol)
        {
            ip_protocol_t.TCP: parse_tcp;
            ip_protocol_t.UDP: parse_udp;
            default: accept;
        }
    }

    state parse_ipv6 {
        pkt.extract(hdr.ipv6);
        transition select(hdr.ipv6.nexthdr)
        {
            ip_protocol_t.TCP: parse_tcp;
            ip_protocol_t.UDP: parse_udp;
            default: accept;
        }
    }

    state parse_tcp {
        pkt.extract(hdr.tcp);
        transition accept;
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.dest) {
            ROCE_V2_UDP_DPORT : parse_ib;
            default: accept;
        }
    }

    state parse_ib {
        ib_parser.apply(pkt, hdr.ib_hdr);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Egress Deparser
// ---------------------------------------------------------------------------
control SwitchEgressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {

    Checksum() ip_checksum;
    apply {
        hdr.ip.check = ip_checksum.update({
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

// ---------------------------------------------------------------------------
// Switch Egress MAU
// ---------------------------------------------------------------------------
control SwitchEgress(
        inout header_t hdr,
        inout metadata_t eg_md,
        in    egress_intrinsic_metadata_t                 eg_intr_md,
        in    egress_intrinsic_metadata_from_parser_t     eg_prsr_md,
        inout egress_intrinsic_metadata_for_deparser_t    eg_dprsr_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_oport_md) {

    MarkEcn() mark_ecn;
    apply {
        if (hdr.ip.isValid()) {
            // Check ECN capability
            if (hdr.ib_hdr.bth.isValid()) { // For RoCEv2, use WRED-ECN for DCQCN
                mark_ecn.apply(hdr.ip.tos[1:0], mark_ecn_type_t.WRED_ECN, 0, eg_intr_md.deq_qdepth);
            }
            else { // For TCP, use standard ECN marking
                mark_ecn.apply(hdr.ip.tos[1:0], mark_ecn_type_t.ECN, 0, eg_intr_md.deq_qdepth);
            }
        }
    }
}

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         SwitchEgressParser(),
         SwitchEgress(),
         SwitchEgressDeparser()) pipe;

Switch(pipe) main;

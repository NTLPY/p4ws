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
#include <p4ws/ether.p4>
#include <p4ws/ip.p4>
#include <p4ws/ipv6.p4>
#include <p4ws/tcp.p4>
#include <p4ws/udp.p4>
#include <p4ws/utils.p4>

#include "config.p4"

header debug_h {
    bit<32> op;
    bit<8>  in8;
    bit<16> in16;
    bit<32> in32;
    bit<8>  out8;
    bit<16> out16;
    bit<32> out32;
}

struct header_t {
    eth_h eth;
    ip_h ip;
    ipv6_h ipv6;
    tcp_h tcp;
    udp_h udp;
    debug_h debug;
}

struct metadata_t {
}

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
        transition select(hdr.udp.dest)
        {
            DEBUG_PORT: parse_debug;
            default: accept;
        }
    }

    state parse_debug {
        pkt.extract(hdr.debug);
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

control SwitchIngress(
        inout header_t hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    Hash<bit<8>>(HashAlgorithm_t.IDENTITY) hash_identity_8;
    Hash<bit<16>>(HashAlgorithm_t.IDENTITY) hash_identity_16;
    Hash<bit<32>>(HashAlgorithm_t.IDENTITY) hash_identity_32;

    BypassEgress() bypass_egress;

    apply {
        //
        // 7.8 Hash
        //
        // I. IDENTITY
        if (hdr.debug.op == DEBUG_OP_HASH_IDENTITY_32) {
            hdr.debug.out8 = hash_identity_8.get(hdr.debug.in32);
        }
        if (hdr.debug.op == DEBUG_OP_HASH_IDENTITY_32) {
            hdr.debug.out16 = hash_identity_16.get(hdr.debug.in32);
        }
        if (hdr.debug.op == DEBUG_OP_HASH_IDENTITY_32) {
            hdr.debug.out32 = hash_identity_32.get(hdr.debug.in32);
        }

        // Just echo it back to the ingress port.
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;

        // No need for egress processing, skip it and use empty controls for egress.
        bypass_egress.apply(ig_tm_md);
    }
}

Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         EmptyEgressParser(),
         EmptyEgress(),
         EmptyEgressDeparser()) pipe;

Switch(pipe) main;

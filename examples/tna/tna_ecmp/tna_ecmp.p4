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

struct header_t {
    eth_h eth;
    ip_h ip;
    ipv6_h ipv6;
    tcp_h tcp;
    udp_h udp;
}

struct ip_ecmp_hash_t {
    ip_addr_t saddr;
    ip_addr_t daddr;
    bit<16> l4_source;
    bit<16> l4_dest;
    bit<8> protocol;
}

struct metadata_t {
    ip_ecmp_hash_t ip_ecmp_hash;
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

    Hash<bit<8>>(HashAlgorithm_t.CRC16) hash_fn;
    // Action Profile Size = max group size x max number of groups
    ActionProfile(256) ip_ecmp_ap;
    ActionSelector(ip_ecmp_ap, // action profile
                   hash_fn, // hash extern
                   SelectorMode_t.FAIR, // Selector algorithm
                   256, // max group size
                   256 // max number of groups
                   ) ip_ecmp;

    action set_port(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 0x1; // Drop packet.
    }

    table ip_lpm {
        key = {
            hdr.ip.daddr : lpm;
            ig_md.ip_ecmp_hash.saddr : selector;
            ig_md.ip_ecmp_hash.daddr : selector;
            ig_md.ip_ecmp_hash.l4_source : selector;
            ig_md.ip_ecmp_hash.l4_dest : selector;
            ig_md.ip_ecmp_hash.protocol : selector;
        }

        actions = {
            set_port;
            drop;
        }

        const default_action = drop;
        size = 2048;
        implementation = ip_ecmp;
    }

    BypassEgress() bypass_egress;

    apply {
        if (hdr.ip.isValid()) {
            ig_md.ip_ecmp_hash.saddr = hdr.ip.saddr;
            ig_md.ip_ecmp_hash.daddr = hdr.ip.daddr;
            ig_md.ip_ecmp_hash.protocol = hdr.ip.protocol;

            ig_md.ip_ecmp_hash.l4_source = 0;
            ig_md.ip_ecmp_hash.l4_dest = 0;

            if (hdr.tcp.isValid()) {
                ig_md.ip_ecmp_hash.l4_source = hdr.tcp.source;
                ig_md.ip_ecmp_hash.l4_dest = hdr.tcp.dest;
            } else if (hdr.udp.isValid()) {
                ig_md.ip_ecmp_hash.l4_source = hdr.udp.source;
                ig_md.ip_ecmp_hash.l4_dest = hdr.udp.dest;
            }
            ip_lpm.apply();
        }
        else {
            drop();
        }

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

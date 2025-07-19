/**
 * Utilities for P4 Programs
 *
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
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Author: NTLPY <59137305+NTLPY@users.noreply.github.com>
 */

#ifndef P4WS_UTILS_P4
#define P4WS_UTILS_P4

struct empty_header_t {}

struct empty_metadata_t {}

parser TofinoIngressParser(
        packet_in pkt,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        transition select(ig_intr_md.resubmit_flag) {
            1 : parse_resubmit;
            0 : parse_port_metadata;
        }
    }

    state parse_resubmit {
        // Parse resubmitted packet here.
        transition reject;
    }

    state parse_port_metadata {
        pkt.advance(PORT_METADATA_SIZE);
        transition accept;
    }
}

parser TofinoEgressParser(
        packet_in pkt,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}

/**
 * Bypass egress control block.
 *
 * This control block sets the bypass_egress field in the intrinsic metadata
 * to indicate that the packet should bypass the egress pipeline.
 *
 * All egress process will be skipped.
 */
control BypassEgress(inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    apply {
        ig_tm_md.bypass_egress = 1w1;
    }
}

/**
 * Empty egress parser blocks.
 *
 * @note If you need to use empty egress parser blocks, you need call BypassEgress
 *       control block in ingress.
 */
parser EmptyEgressParser(
        packet_in pkt,
        out empty_header_t hdr,
        out empty_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        transition accept;
    }
}

/**
 * Empty egress deparser blocks.
 *
 * @note If you need to use empty egress deparser blocks, you need call BypassEgress
 *       control block in ingress.
 */
control EmptyEgressDeparser(
        packet_out pkt,
        inout empty_header_t hdr,
        in empty_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
    apply {}
}

/**
 * Empty egress control blocks.
 */
control EmptyEgress(
        inout empty_header_t hdr,
        inout empty_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {
    apply {}
}

#endif // P4WS_UTILS_P4

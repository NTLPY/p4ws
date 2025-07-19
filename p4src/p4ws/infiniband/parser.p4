/**
 * InfiniBand Parsers
 *
 * Reference:
 * - InfiniBand Architecture Specification Volume 1, Release 1.4
 * - linux/include/rdma/ib_verbs.h
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

#ifndef P4WS_INFINIBAND_PARSER_P4
#define P4WS_INFINIBAND_PARSER_P4

#include <p4ws/compiler.p4>
#include <p4ws/infiniband/transport.p4>
#include <p4ws/infiniband/mgmt.p4>

header_union ib_ext_h {
    ib_deth_h deth;
}

header_union ib_cm_t {
    ib_cm_req_h     req;
    ib_cm_rej_h     rej;
    ib_cm_rep_h     rep;
    ib_cm_rtu_h     rtu;
    ib_cm_dreq_h    dreq;
    ib_cm_drep_h    drep;
}

struct ib_hdr_t {
    ib_bth_h    bth;
    ib_ext_h    ext;
#ifdef P4WS_ENABLE_INFINIBAND_MGMT
    ib_mad_h    mad;
#ifdef P4WS_ENABLE_INFINIBAND_CM
    ib_cm_t     cm;
#endif // P4WS_ENABLE_INFINIBAND_CM
#endif // P4WS_ENABLE_INFINIBAND_MGMT
}

parser InfiniBandCmParser(
    packet_in pkt,
    in ib_mad_attribute_id_t ib_mad_attribute_id,
    out ib_cm_t ib_cm) {
    state start {
        transition select(ib_mad_attribute_id) {
            ib_mad_attribute_id_t.CONNECT_REQUEST : parse_cm_req;
            ib_mad_attribute_id_t.CONNECT_REJECT : parse_cm_rej;
            ib_mad_attribute_id_t.CONNECT_REPLY : parse_cm_rep;
            ib_mad_attribute_id_t.READY_TO_USE : parse_cm_rtu;
            ib_mad_attribute_id_t.DISCONNECT_REQUEST : parse_cm_dreq;
            ib_mad_attribute_id_t.DISCONNECT_REPLY : parse_cm_drep;
            default : accept;
        }
    }

    state parse_cm_req {
        pkt.extract(ib_cm.req);
        transition accept;
    }

    state parse_cm_rej {
        pkt.extract(ib_cm.rej);
        transition accept;
    }

    state parse_cm_rep {
        pkt.extract(ib_cm.rep);
        transition accept;
    }

    state parse_cm_rtu {
        pkt.extract(ib_cm.rtu);
        transition accept;
    }

    state parse_cm_dreq {
        pkt.extract(ib_cm.dreq);
        transition accept;
    }

    state parse_cm_drep {
        pkt.extract(ib_cm.drep);
        transition accept;
    }
}

parser InfiniBandMadParser(
    packet_in pkt,
    out ib_hdr_t ib_hdr) {

#ifdef P4WS_ENABLE_INFINIBAND_CM
    InfiniBandCmParser() cm_parser;
#endif // P4WS_ENABLE_INFINIBAND_CM

    state start {
        pkt.extract(ib_hdr.mad);
        transition select(ib_hdr.mad.mgmt_class) {
            ib_mgmt_class_t.COM_MGT : parse_cm;
            default : accept;
        }
    }

    state parse_cm {
#ifdef P4WS_ENABLE_INFINIBAND_CM
        cm_parser.apply(pkt, ib_hdr.mad.attribute_id, ib_hdr.cm);
#endif // P4WS_ENABLE_INFINIBAND_CM
        transition accept;
    }
}

/**
 * InfiniBand Parser
 *
 * Parse InfiniBand headers including BTH, DETH, and MAD.
 *
 * Define `P4WS_ENABLE_INFINIBAND_MGMT` to enable MAD parsing.
 * Define `P4WS_ENABLE_INFINIBAND_CM` to enable CM parsing.
 */
parser InfiniBandParser(
    packet_in pkt,
    out ib_hdr_t ib_hdr) {

#ifdef P4WS_ENABLE_INFINIBAND_MGMT
    InfiniBandMadParser() mad_parser;
#endif // P4WS_ENABLE_INFINIBAND_MGMT

    state start {
        pkt.extract(ib_hdr.bth);
        transition select(ib_hdr.bth.opcode) {
            ib_opcode_t.UD_SEND_ONLY : parse_deth;
            ib_opcode_t.UD_SEND_ONLY_WITH_IMMEDIATE : parse_deth;
            default: accept;
        }
    }

    state parse_deth {
        pkt.extract(ib_hdr.ext.deth);
        transition select(ib_hdr.ext.deth.src_qp)
        {
            IB_QP_1 : parse_mad;
            default : accept;
        }
    }

    state parse_mad {
#ifdef P4WS_ENABLE_INFINIBAND_MGMT
        mad_parser.apply(pkt, ib_hdr);
#endif // P4WS_ENABLE_INFINIBAND_MGMT
        transition accept;
    }

}

#endif // P4WS_INFINIBAND_PARSER_P4

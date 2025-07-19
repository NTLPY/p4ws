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

#ifndef INFINIBAND_PARSER_P4
#define INFINIBAND_PARSER_P4

#include <compiler.p4>
#include <infiniband/transport.p4>

header_union ib_ext_h {
    ib_deth_h deth;
}

struct ib_hdr_t {
    ib_bth_h bth;
    ib_ext_h ext;
}

parser InfiniBandParser(
    packet_in pkt,
    out ib_hdr_t ib_hdr) {
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
            default: accept;
        }
    }
}

#endif // INFINIBAND_PARSER_P4

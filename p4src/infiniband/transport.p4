/**
 * InfiniBand Definitions
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

#ifndef INFINIBAND_TRANSPORT_P4
#define INFINIBAND_TRANSPORT_P4

//!< Type of Partition Key
typedef bit<16> ib_p_key_t;

//!< Type of Queue Pair
typedef bit<24> ib_qp_t;

//!< Type of EE Context
typedef bit<24> ib_eecn_t;

/**
 * Well-known Queue Pair
 */
const ib_qp_t IB_QP_0 = 0x000;
const ib_qp_t IB_QP_1 = 0x001;

//!< Type of PSN
typedef bit<24> ib_psn_t;

//!< Type of Queue Key
typedef bit<32> ib_q_key_t;

/**
 * Well-known Queue Key (C9-49)
 */
const ib_q_key_t IB_Q_KEY_QP_1 = 0x80010000;

/**
 * OpCodes (C9-2)
 */
enum bit<8> ib_opcode_t {
    /* transport types -- just used to define real constants */
    RC = 0x00,
    UC = 0x20,
    RD = 0x40,
    UD = 0x60,
    /* per IBTA 1.3 vol 1 Table 38, A10.3.2 */
    CNP = 0x80,
    /* Manufacturer specific */
    MSP = 0xe0,

    /* real constants follow -- see comment about above IB_OPCODE()
        macro for more details */

    /* RC */
    RC_SEND_FIRST                       = 0x00,
    RC_SEND_MIDDLE                      = 0x01,
    RC_SEND_LAST                        = 0x02,
    RC_SEND_LAST_WITH_IMMEDIATE         = 0x03,
    RC_SEND_ONLY                        = 0x04,
    RC_SEND_ONLY_WITH_IMMEDIATE         = 0x05,
    RC_RDMA_WRITE_FIRST                 = 0x06,
    RC_RDMA_WRITE_MIDDLE                = 0x07,
    RC_RDMA_WRITE_LAST                  = 0x08,
    RC_RDMA_WRITE_LAST_WITH_IMMEDIATE   = 0x09,
    RC_RDMA_WRITE_ONLY                  = 0x0A,
    RC_RDMA_WRITE_ONLY_WITH_IMMEDIATE   = 0x0B,
    RC_RDMA_READ_REQUEST                = 0x0C,
    RC_RDMA_READ_RESPONSE_FIRST         = 0x0D,
    RC_RDMA_READ_RESPONSE_MIDDLE        = 0x0E,
    RC_RDMA_READ_RESPONSE_LAST          = 0x0F,
    RC_RDMA_READ_RESPONSE_ONLY          = 0x10,
    RC_ACKNOWLEDGE                      = 0x11,
    RC_ATOMIC_ACKNOWLEDGE               = 0x12,
    RC_COMPARE_SWAP                     = 0x13,
    RC_FETCH_ADD                        = 0x14,
    RC_SEND_LAST_WITH_INVALIDATE        = 0x16,
    RC_SEND_ONLY_WITH_INVALIDATE        = 0x17,
    RC_FLUSH                            = 0x1C,
    RC_ATOMIC_WRITE                     = 0x1D,

    /* UC */
    UC_SEND_FIRST                       = 0x20,
    UC_SEND_MIDDLE                      = 0x21,
    UC_SEND_LAST                        = 0x22,
    UC_SEND_LAST_WITH_IMMEDIATE         = 0x23,
    UC_SEND_ONLY                        = 0x24,
    UC_SEND_ONLY_WITH_IMMEDIATE         = 0x25,
    UC_RDMA_WRITE_FIRST                 = 0x26,
    UC_RDMA_WRITE_MIDDLE                = 0x27,
    UC_RDMA_WRITE_LAST                  = 0x28,
    UC_RDMA_WRITE_LAST_WITH_IMMEDIATE   = 0x29,
    UC_RDMA_WRITE_ONLY                  = 0x2A,
    UC_RDMA_WRITE_ONLY_WITH_IMMEDIATE   = 0x2B,

    /* RD */
    RD_SEND_FIRST                       = 0x40,
    RD_SEND_MIDDLE                      = 0x41,
    RD_SEND_LAST                        = 0x42,
    RD_SEND_LAST_WITH_IMMEDIATE         = 0x43,
    RD_SEND_ONLY                        = 0x44,
    RD_SEND_ONLY_WITH_IMMEDIATE         = 0x45,
    RD_RDMA_WRITE_FIRST                 = 0x46,
    RD_RDMA_WRITE_MIDDLE                = 0x47,
    RD_RDMA_WRITE_LAST                  = 0x48,
    RD_RDMA_WRITE_LAST_WITH_IMMEDIATE   = 0x49,
    RD_RDMA_WRITE_ONLY                  = 0x4A,
    RD_RDMA_WRITE_ONLY_WITH_IMMEDIATE   = 0x4B,
    RD_RDMA_READ_REQUEST                = 0x4C,
    RD_RDMA_READ_RESPONSE_FIRST         = 0x4D,
    RD_RDMA_READ_RESPONSE_MIDDLE        = 0x4E,
    RD_RDMA_READ_RESPONSE_LAST          = 0x4F,
    RD_RDMA_READ_RESPONSE_ONLY          = 0x50,
    RD_ACKNOWLEDGE                      = 0x51,
    RD_ATOMIC_ACKNOWLEDGE               = 0x52,
    RD_COMPARE_SWAP                     = 0x53,
    RD_FETCH_ADD                        = 0x54,
    RD_FLUSH                            = 0x55,

    /* UD */
    UD_SEND_ONLY                        = 0x64,
    UD_SEND_ONLY_WITH_IMMEDIATE         = 0x65
}

/**
 * 9.2 Base Transport Header (C9-1)
 */
header ib_bth_h {
    ib_opcode_t opcode;
    bit<1>      se;
    bit<1>      m;
    bit<2>      pad_cnt;
    bit<4>      tver;
    ib_p_key_t  p_key;
    bit<1>      fecn;
    bit<1>      becn;
    bit<6>      resv6;
    ib_qp_t     dest_qp;
    bit<1>      a;
    bit<7>      resv7;
    ib_psn_t    psn;
}

/**
 * 9.3.2 Datagram Extended Transport Header (DETH)
 */
header ib_deth_h {
    ib_q_key_t  q_key;
    bit<8>      resv8;
    ib_qp_t     src_qp;
}

#endif // INFINIBAND_TRANSPORT_P4

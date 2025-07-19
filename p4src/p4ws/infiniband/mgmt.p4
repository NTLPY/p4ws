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

#ifndef P4WS_INFINIBAND_MGMT_P4
#define P4WS_INFINIBAND_MGMT_P4

/**
 * 13.4.4 Management Classes (C13-5)
 */
enum bit<8> ib_mgmt_class_t {
    COM_MGT = 0x07
}

/**
 * 16.7.3 Attributes (C16-15.1.3)
 */
enum bit<16> ib_mad_attribute_id_t {
    CLASS_PORT_INFO         = 0x0001,
    CONNECT_REQUEST         = 0x0010,
    MSG_RCPT_ACK            = 0x0011,
    CONNECT_REJECT          = 0x0012,
    CONNECT_REPLY           = 0x0013,
    READY_TO_USE            = 0x0014,
    DISCONNECT_REQUEST      = 0x0015,
    DISCONNECT_REPLY        = 0x0016,
    SERVICE_ID_RES_REQ      = 0x0017,
    SERVICE_ID_RES_REQ_RESP = 0x0018,
    LOAD_ALTERNATE_PATH     = 0x0019,
    ALTERNATE_PATH_RESPONSE = 0x001A,
    SUGGEST_ALTERNATE_PATH  = 0x001B,
    SUGGEST_PATH_RESPONSE   = 0x001C,
}

/**
 * 13.4.2 Management Datagram (C13-4.2-1.1) [24 Bytes]
 */
header ib_mad_h {
    bit<8>                  base_version;
    ib_mgmt_class_t         mgmt_class;
    bit<8>                  class_version;
    bit<1>                  r;
    bit<7>                  method;
    bit<16>                 status;
    bit<16>                 class_specific;
    bit<64>                 transaction_id;
    ib_mad_attribute_id_t   attribute_id;
    bit<16>                 additional_status;
    bit<32>                 attribute_modifier;
}

/**
 * 12.6.5 REQ - Request For Communication (o12-1)
 */
header ib_cm_req_h {
    bit<32>     local_communication_id;
    bit<8>      resv8;
    bit<24>     vender_id;
    bit<64>     service_id;
    bit<64>     local_ca_guid;
    bit<32>     resv32;
    ib_q_key_t  local_q_key;
    ib_qp_t     local_qpn;
    bit<8>      responder_resources;
    ib_eecn_t   local_eecn;
    bit<8>      initiator_depth;
    ib_eecn_t   remote_eecn;
    bit<5>      remote_cm_response_timeout;
    bit<2>      transport_service_type;
    bit<1>      end_to_end_flow_control;
    ib_psn_t    starting_psn;
    bit<5>      local_cm_response_timeout;
    bit<3>      retry_count;
    ib_p_key_t  p_key;
    bit<4>      path_packet_payload_mtu;
    bit<1>      rdc_exists;
    bit<3>      rnr_retry_count;
    bit<4>      max_cm_retries;
    bit<1>      srq;
    bit<3>      extended_transport_type;
    ib_lid_t    primary_local_port_lid;
    ib_lid_t    primary_remote_port_lid;
    ib_gid_t    primary_local_port_gid;
    ib_gid_t    primary_remote_port_gid;
    // Unused below
}

/**
 * 12.6.5 REJ - Reject (C12-4)
 */
header ib_cm_rej_h {
    bit<32> local_communication_id;
    bit<32> remote_communication_id;
    // Unused below
}

/**
 * 12.6.8 REP - Reply To Request For Communication (o12-3)
 */
header ib_cm_rep_h {
    bit<32>     local_communication_id;
    bit<32>     remote_communication_id;
    ib_q_key_t  local_q_key;
    ib_qp_t     local_qpn;
    // Unused below
}

/**
 * 12.6.8 RTU - Reply To Request For Communication (o12-4)
 */
header ib_cm_rtu_h {
    bit<32> local_communication_id;
    bit<32> remote_communication_id;
    // Unused below
}

/**
 * 12.6.10 DREQ - Request for communication Release (Disconnection REQuest) (o12-5)
 */
header ib_cm_dreq_h {
    bit<32> local_communication_id;
    bit<32> remote_communication_id;
    ib_qp_t remote_qpn;
    // Unused below
}

/**
 * 12.6.11 DREP - Reply to Request for communication Release (o12-6)
 */
header ib_cm_drep_h {
    bit<32> local_communication_id;
    bit<32> remote_communication_id;
    // Unused below
}

#endif // P4WS_INFINIBAND_MGMT_P4

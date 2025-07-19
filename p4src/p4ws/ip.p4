/**
 * INET Definitions
 *
 * Reference:
 * - linux/include/uapi/linux/ip.h
 * - linux/include/uapi/linux/in.h
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

#ifndef P4WS_IP_P4
#define P4WS_IP_P4

typedef bit<32> ip_addr_t;

/* Standard well-defined IP protocols.  */
enum bit<8> ip_protocol_t {
    IP      = 0,    // Dummy protocol for TCP
    ICMP    = 1,    // Internet Control Message Protocol
    IGMP    = 2,    // Internet Group Management Protocol
    TCP     = 6,    // Transmission Control Protocol
    UDP     = 17,   // User Datagram Protocol
    IPV6    = 41,   // IPv6 header
    RAW     = 255,  // Raw IP packet
}

header ip_h {
    bit<4>          version;
    bit<4>          ihl;
    bit<8>          tos;
    bit<16>         tot_len;
    bit<16>         id;
    bit<3>          flags;
    bit<13>         frag_off;
    bit<8>          ttl;
    ip_protocol_t   protocol;
    bit<16>         check;
    ip_addr_t       saddr;
    ip_addr_t       daddr;
}

#endif // P4WS_IP_P4

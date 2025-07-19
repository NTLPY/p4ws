/**
 * Ethernet Definitions
 *
 * Reference:
 * - linux/include/uapi/if_ether.h
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

#ifndef ETHER_P4
#define ETHER_P4

typedef bit<48> mac_addr_t;
typedef bit<16> ether_type_t;

const ether_type_t ETHER_TYPE_IP        = 0x0800;
const ether_type_t ETHER_TYPE_ARP       = 0x0806;
const ether_type_t ETHER_TYPE_IPV6      = 0x86DD;
const ether_type_t ETHER_TYPE_VLAN      = 0x8100;
const ether_type_t ETHER_TYPE_MPLS_UC   = 0x8847;
const ether_type_t ETHER_TYPE_MPLS_MC   = 0x8848;

header eth_h {
    mac_addr_t      dest;
    mac_addr_t      source;
    ether_type_t    proto;
}

#endif // ETHER_P4

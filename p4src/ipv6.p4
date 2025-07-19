/**
 * INET6 Definitions
 *
 * Reference:
 * - linux/include/uapi/linux/ipv6.h
 * - linux/include/uapi/linux/in6.h
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

#ifndef IPV6_P4
#define IPV6_P4

#include <ip.p4>

typedef bit<128> ipv6_addr_t;

header ipv6_h {
    bit<4>      version;
    bit<8>      traffic_class;
    bit<20>     flow_label;
    bit<16>     payload_len;
    bit<8>      nexthdr;
    bit<8>      hop_limit;
    ipv6_addr_t saddr;
    ipv6_addr_t daddr;
}

#endif // IPV6_P4

/**
 * UDP Definitions
 *
 * Reference:
 * - RFC 768
 * - linux/include/uapi/linux/udp.h
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

#ifndef P4WS_UDP_P4
#define P4WS_UDP_P4

header udp_h {
    bit<16> source;
    bit<16> dest;
    bit<16> len;
    bit<16> check;
}

#endif // P4WS_UDP_P4

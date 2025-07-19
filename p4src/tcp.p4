/**
 * TCP Definitions
 *
 * Reference:
 * - RFC 9293
 * - linux/include/uapi/linux/tcp.h
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

#ifndef TCP_P4
#define TCP_P4

enum bit<8> tcp_flags_e {
    TCP_FIN = 0x01, // No more data from sender
    TCP_SYN = 0x02, // Synchronize sequence numbers
    TCP_RST = 0x04, // Reset the connection
    TCP_PSH = 0x08, // Push function
    TCP_ACK = 0x10, // Acknowledgment field is significan
    TCP_URG = 0x20, // Urgent pointer field is significant
    TCP_ECE = 0x40, // ECN-Echo
    TCP_CWR = 0x80, // Congestion Window Reduced
}

header tcp_h {
    bit<16> source;
    bit<16> dest;
    bit<32> seq;
    bit<32> ack_seq;
    bit<4>  doff;
    bit<4>  res;
    bit<8>  flags;
    bit<16> window;
    bit<16> check;
    bit<16> urg_ptr;
}

#endif // TCP_P4

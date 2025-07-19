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

#ifndef INFINIBAND_BASE_P4
#define INFINIBAND_BASE_P4

//!< 4.1.3 Local Identifiers (C4-5)
typedef bit<16> ib_lid_t;
//!< 4.1.1 Global Identifiers (C4-3)
typedef bit<128> ib_gid_t;

//!< UDP Port of RoCEv2
const bit<16> ROCE_V2_UDP_DPORT = 4791;

#endif // INFINIBAND_BASE_P4

/**
 * ECN
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

#ifndef P4WS_ECN_P4
#define P4WS_ECN_P4

#include <p4ws/ip.p4>

typedef bit<7> mark_ecn_profile_t;

enum bit<1> mark_ecn_type_t {
    ECN         = 0,
    WRED_ECN    = 1,
}

/**
 * Mark ECN by queue depth.
 *
 * @param[inout] ecn         ECN field
 * @param[in]    ecn_type    ECN marking type
 * @param[in]    ecn_profile ECN marking profile
 * @param[in]    qdepth      Queue depth
 */
control MarkEcn(inout bit<2> ecn, in mark_ecn_type_t ecn_type, in mark_ecn_profile_t ecn_profile, in bit<19> qdepth) {
    Counter<bit<32>, bit<8>>(256, CounterType_t.PACKETS) ecn_capable_counter;
    Counter<bit<32>, bit<8>>(256, CounterType_t.PACKETS) ecn_counter;
    Wred<bit<19>, bit<8>>(256, 1, 0) wred;

    apply {
        bit<8> wred_index = ecn_type ++ ecn_profile;

        bit<8> drop = wred.execute(qdepth, wred_index);
        if ((ecn == ip_ecn_t.ECT_1 || ecn == ip_ecn_t.ECT_0))
        {
            ecn_capable_counter.count(wred_index);
            if (drop == 1)
            {
                ecn_counter.count(wred_index);
                ecn = ip_ecn_t.CE;
            }
        }
    }
}

#endif // P4WS_ECN_P4

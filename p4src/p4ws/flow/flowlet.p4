/**
 * Flowlet
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

#ifndef P4WS_FLOW_FLOWLET_P4
#define P4WS_FLOW_FLOWLET_P4

#include <p4ws/arch.p4>

#if __P4_ARCH__ != tna
#error "Flowlet detection is not supported on this architecture"
#endif

#ifndef P4WS_FLOWLET_TIMESTAMP_T
#define P4WS_FLOWLET_TIMESTAMP_T bit<32>
#endif

control FlowletDetection<FLOW_ID_T>(in FLOW_ID_T flow_id, in P4WS_FLOWLET_TIMESTAMP_T now, out bit new_flowlet)
    (int flowlet_table_size) {

#if __P4_ARCH__ == tna
    P4WS_FLOWLET_TIMESTAMP_T delta;

    Counter<bit<32>, bit<1>>(1, CounterType_t.PACKETS) flowlet_counter;

    Register<P4WS_FLOWLET_TIMESTAMP_T, FLOW_ID_T>(flowlet_table_size, 0) flowlet_table;
    RegisterAction<P4WS_FLOWLET_TIMESTAMP_T, FLOW_ID_T, P4WS_FLOWLET_TIMESTAMP_T>(flowlet_table) check_delta = {
        void apply(inout P4WS_FLOWLET_TIMESTAMP_T prev, out P4WS_FLOWLET_TIMESTAMP_T delta_) {
            delta_ = now - prev;
            prev = now;
        }
    };

    Register<P4WS_FLOWLET_TIMESTAMP_T, bit<1>>(1, 100) flowlet_timeout;
    RegisterAction<P4WS_FLOWLET_TIMESTAMP_T, bit<1>, bit>(flowlet_timeout) check_timeout = {
        void apply(inout P4WS_FLOWLET_TIMESTAMP_T timeout, out bit _new_flowlet) {
            if (delta > timeout) {
                _new_flowlet = 1;
            } else {
                _new_flowlet = 0;
            }
        }
    };
#endif
    apply {
        delta = check_delta.execute(flow_id);
        new_flowlet = check_timeout.execute(0);
        if (new_flowlet == 1) {
            flowlet_counter.count(0);
        }
    }
}

#endif // P4WS_FLOW_FLOWLET_P4

/**
 * P4 Architecture
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

#ifndef P4WS_ARCH_P4
#define P4WS_ARCH_P4

#ifdef __TARGET_TOFINO__

#if __TARGET_TOFINO__ == 3
#define __P4_ARCH__ t3na
#include <t3na.p4>
#elif __TARGET_TOFINO__ == 2
#define __P4_ARCH__ t2na
#include <t2na.p4>
#elif __TARGET_TOFINO__ == 1
#define __P4_ARCH__ tna
#include <tna.p4>
#else
#error "Unsupported TNA version."
#endif

#else // __TARGET_TOFINO__ not defined
#error "Architecture not determined."
#endif

#endif // P4WS_ARCH_P4

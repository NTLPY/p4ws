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

/**
 * Determine P4 architecture.
 */
#if defined(__P4_ARCH_TNA__)
#define __P4_ARCH__ tna
#elif defined(__P4_ARCH_T2NA__)
#define __P4_ARCH__ t2na
#elif defined(__P4_ARCH_T3NA__)
#define __P4_ARCH__ t3na
#else

// P4 architecture is not provided, guess it.
#ifdef __TARGET_TOFINO__
#if __TARGET_TOFINO__ == 1
#define __P4_ARCH_TNA__
#define __P4_ARCH__ tna
#elif __TARGET_TOFINO__ == 2
#define __P4_ARCH_T2NA__
#define __P4_ARCH__ t2na
#elif __TARGET_TOFINO__ == 3
#define __P4_ARCH_T3NA__
#define __P4_ARCH__ t3na
#else
#error "Unsupported TNA version."
#endif
#endif // __TARGET_TOFINO__

#endif

/**
 * Include P4 architecture headers.
 */
#if defined(__P4_ARCH_TNA__)
#include <tna.p4>
#elif defined(__P4_ARCH_T2NA__)
#include <t2na.p4>
#elif defined(__P4_ARCH_T3NA__)
#include <t3na.p4>
#else
#error "Unknown or unsupported P4 architecture."
#endif

#endif // P4WS_ARCH_P4

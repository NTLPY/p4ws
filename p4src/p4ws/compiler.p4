/**
 * Compiler Utilities
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

#ifndef P4WS_COMPILER_P4
#define P4WS_COMPILER_P4

/**
 * Some P4 compilers do not support header unions.
 * This is a workaround to allow cross-compiler compatibility.
 * It replaces `header_union` with `struct` if header unions are unsupported.
 */
#ifndef P4WS_DISABLE_HEADER_UNION_CROSS_COMPILER

#if (defined __TARGET_TOFINO__ && (__p4c_major__ < 9 || (__p4c_major__ == 9 && __p4c_minor__ < 13) || (__p4c_major__ == 9 && __p4c_minor__ == 13 && __p4c_patchlevel__ <= 3)))
#define HEADER_UNION_UNSUPPORTED
#endif

#ifdef HEADER_UNION_UNSUPPORTED
#define header_union struct
#endif

#endif

#endif // P4WS_COMPILER_P4

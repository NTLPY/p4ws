#!/usr/bin/env bash
#
# Activate environment for Barefoot SDE.
# Copyright 2025 P4WS
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: NTLPY <59137305+NTLPY@users.noreply.github.com>
#

if [ "${BASH_SOURCE-}" = "$0" ]; then
    echo "You must source this script: \$ source $0" >&2
    exit 1
fi

BFSDE_LD_LIBRARY_PATH=`python3 -c "from p4ws.targets.bfsde import get_bfsde_ld_library_path; print(get_bfsde_ld_library_path())"`
if [ $? -ne 0 ]; then
  echo "*** Error: Obtain LD_LIBRARY_PATH failed"
fi
echo Barefoot SDE LD_LIBRARY_PATH: ${BFSDE_LD_LIBRARY_PATH}
export LD_LIBRARY_PATH="${BFSDE_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

BFSDE_PYTHONPATH=`python3 -c "from p4ws.targets.bfsde import get_bfsde_python_path_for_p4_test; print(\":\".join(get_bfsde_python_path_for_p4_test(\"${1}\")))"`
if [ $? -ne 0 ]; then
  echo "*** Error: Obtain PYTHONPATH failed"
fi
echo Barefoot SDE PYTHONPATH: ${BFSDE_PYTHONPATH}
export PYTHONPATH="${BFSDE_PYTHONPATH}:${PYTHONPATH}"

#!/usr/bin/env bash
#
# Activate environment for P4WS.
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

WORKSPACE_PATH="$(realpath "$(dirname "$(realpath "${BASH_SOURCE-}")")/..")"
echo "*** Assume you are in a P4WS development environment: ${WORKSPACE_PATH}"

OLD_PYTHONPATH="${PYTHONPATH}"
export PYTHONPATH="${WORKSPACE_PATH}/src:${PYTHONPATH}"
python3 -c 'import p4ws; print(p4ws.__version__)' >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "*** Error: p4ws Python package not found in the development environment."
  export PYTHONPATH="${OLD_PYTHONPATH}"
  return 1
fi

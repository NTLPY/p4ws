#!/usr/bin/env python3
#
# Setup settings of vscode.
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

import os
import commentjson as json

from p4ws.targets.bfsde import get_bfsde_python_path_for_p4_test


def get_workspace_path():
    """
    Get the workspace path for the current P4WS project.
    """
    return os.path.abspath(os.path.dirname(os.path.dirname(__file__)))


def main():
    workspace_path = get_workspace_path()
    print("Workspace path:", workspace_path)

    # Create the .vscode directory if it doesn't exist
    vscode_dir = os.path.join(workspace_path, ".vscode")
    os.makedirs(vscode_dir, exist_ok=True)

    # Create or update settings.json
    settings_json_path = os.path.join(vscode_dir, "settings.json")
    settings = json.load(open(settings_json_path)) if os.path.exists(
        settings_json_path) else {}
    if not isinstance(settings, dict):
        print("Error: root of settings.json is not a dict.")
        return 1

    # Update 'python.analysis.extraPaths'
    python_analysis_extra_paths = settings.setdefault(
        "python.analysis.extraPaths", [])
    if not isinstance(python_analysis_extra_paths, list):
        print("Error: 'python.analysis.extraPaths' is not a list.")
        return 1
    bfsde_python_path = get_bfsde_python_path_for_p4_test()
    for python_path in bfsde_python_path:
        if python_path not in python_analysis_extra_paths:
            python_analysis_extra_paths.append(python_path)

    json.dump(settings, open(settings_json_path, "w"),
              indent=4, sort_keys=True)
    print("Writed settings to {}".format(settings_json_path))
    return 0


if __name__ == "__main__":
    exit(main())

#!/usr/bin/env bash

mkdir -p logs

# Touch these two files to ensure they have the current user's access permissions.
touch out.json shell.sh

sudo -E env PYTHONPATH=${PYTHONPATH}              \
    python3 -m p4ws loadmn                        \
    --topo-file topo-2sw.json --net-file net.json \
    --out-file out.json --shell-file shell.sh     \
    --log-level info

rm out.json shell.sh

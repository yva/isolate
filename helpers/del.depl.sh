#!/bin/bash
set -eu -o pipefail

[ -z "${DEBUG:-}" ] || set -x

dpl="$1"
source /opt/auth/shared/bash.sh

for i in $(s "$dpl" | sed -r 's/\x1B\[[0-9;]*[JKmsu]//g' | grep -Eo '^[0-9]+'); do
auth-del-host  "$i"
done

auth-del-project-config "$dpl"
s "$dpl"

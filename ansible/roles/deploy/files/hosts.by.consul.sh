#!/bin/bash
set -eu -o pipefail
[ -z "${DEBUG:-}" ] || set -x

dpl="$1"
usr="${2:-yva}"

source /opt/auth/shared/bash.sh


## add host by consul
linefound=''
while read -r line || [ -n "$line" ]; do 
  if echo "$line" | grep "^Node\s*Address\s*Status\s*" >/dev/null; then
    linefound=1
    break
  fi
done

if [ -z "$linefound" ]; then 
  echo "Consul line not found" >&2
  exit 1
fi

while read -r line || [ -n "$line" ]; do 
  hst="$(echo "$line" | tr -s ' ' | cut -d' ' -f1)"
  ipport="$(echo "$line" | tr -s ' ' | cut -d' ' -f2)"
  ip="$(echo "$ipport" | cut -d':' -f1)"
  if [ -n "$hst" ] && [ -n "$ip" ]; then 
    echo "[  INFO] Add to >$dpl< Host: $hst IP: $ip"
    auth-add-host --project "$dpl" --server-name "$hst" --ip "$ip" --user "$usr" 
  else
    echo ">${line}< not parsed"
  fi
done
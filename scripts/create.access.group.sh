#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
set -eu -o pipefail

# merge jsons from params from left (less priority) 2 right (more priority)
function merge_json_left2right() {
  local kv
  kv="$(echo "$1" | jq -cer '.')"
  shift
  while [[ $# -gt 0 ]]; do
    kv1="$(echo "$1" | jq -cer '.')"
    kv=$(printf '%s\n%s' "$kv" "$kv1" | jq -scer '.[0] * .[1]')
    shift
  done
  echo "$kv"
}

env_dir="$DIR/../shared/groups"
settings="$DIR/../configs/settings.json"

group=
key=
base='0'
params=()
while [[ $# -gt 0 ]]; do
  case "${1}" in
    '--access-group') shift; group="$1";; 
    '--key') shift; key="$1";; 
    '--db') shift; base="$1";;     
    *) params+=("$1")
  esac
  shift;
done

[ -n "$group" ] || { echo "No group"; exit 1; }
[ -n "$key" ] || { echo "No key"; exit 1; }

# settings
prev="$(cat "$settings")"
merge_json_left2right "$prev" '{  "'"$group"'": {    "auth_key": "'"$key"'"  }}' > "$settings"

# env
envf="${env_dir}/${group}.sh"
cat > "${envf}" << EOL 
ISOLATE_REDIS_DB=$base;
ISOLATE_ACCESS_GROUP='${group}';

export ISOLATE_REDIS_DB;
export ISOLATE_ACCESS_GROUP;    
EOL
chmod +r "$envf"


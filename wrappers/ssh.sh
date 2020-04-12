#!/bin/bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
set -eu -o pipefail

settings_file="/opt/auth/configs/settings.json"
group=
params=()
while [[ $# -gt 0 ]]; do
  case "${1}" in
    '--access-group') shift; group="$1";; 
    *) params+=("$1")
  esac
  shift;
done

if [ -z "$group" ]; then
  echo "Error: Group not found. empty!" >&2
  exit 1
fi

if [ ! -e "$settings_file" ]; then
  echo "Error! No settings file >$settings_file< found!" >&2
  exit 1
fi

if ! key_file="$(jq -cer '.["'"$group"'"].auth_key' "$settings_file")"; then 
  echo "Error! Settings file $settings_file  parse failed for  >$group<!" >&2
  exit 1
fi

if [ -z "$key_file" ]; then
  echo "Error! Not found key_file in $settings_file  for group >$group<!" >&2
  exit 1
fi

# call with auth file added
"$DIR/ssh.py" "${params[@]}" '--auth-key' "$key_file"
#!/usr/bin/env bash
set -eu -o pipefail

[ -z "${DEBUG:-}" ] || set -x
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

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

# file with export sources list
list="$(pwd)/dumper.json"

# options
vagrant=
expminutes='30'
filter=()
total_env='{}'
modes=()
while [[ $# -gt 0 ]]; do
    case "$1" in
    # name of file with export lst
      '--config') shift;
        list="$1"
      ;;
    # filter by target deployment
      '--filter'|'-f') shift;
        filter+=("$1")
      ;;
    # mode
      '--mode') shift;
        modes+=("$1")
      ;;
    # vagrant mode for debug
      '--vagrant')
        vagrant=1
      ;;
    # environment
      '--env') shift;
        kv='{"'"${1%%=*}"'": "'"${1#*=}"'"}'
        total_env="$(merge_json_left2right "$total_env" "$kv")"
      ;;
    # time to live azure access token
      '--expire'|'-e') shift;
        expminutes="$1"
      ;;
    esac
    shift;
done

if [ -z "$vagrant" ]; then 
# load isolate env
export PS1=tmpv
. /etc/bash.bashrc
fi

dumpdate="$(date --iso-8601=seconds)"
version="$(jq -cr '.meta.version|select(type=="object")' "$list")"

# get current dump
dump="$(jq -cer '.' "$list")"  
  
# make azure connection parameters
end="$(date -d'+'"$expminutes"' minutes' '+%Y-%m-%dT%H:%MZ')"
account="$(echo "$dump" | jq -cer '.azure.account')"
container="$(echo "$dump" | jq -cer '.azure.container')"
path="$(echo "$dump" | jq -cer '.azure.path')"
subscription="$(echo "$dump" | jq -cer '.azure.subscription')"
  
sas="$( az storage container generate-sas \
  --name "$container" \
  --subscription "$subscription" \
  --account-name "$account" \
  --https-only \
  --permissions acwrl \
  --expiry "$end" \
  --output tsv
)"

#export YVA_DUMP_PARAMS
meta="$( jq -cer '.' <<EOL
{
  "who": "$(who -m | tr '\n' ',')",
  "id": "$(id -a| tr '\n' ',')",
  "time": "${dumpdate}"
}
EOL
)"

settings_global=
if dpl_settings="$( echo "$dump" | jq -cer '.settings|select(type=="object")')"; then 
  if file="$( echo "$dpl_settings" | jq -cer '.file')"; then
    settings_global="$settings_global --settings '$file'"
  fi
  if config="$( echo "$dpl_settings" | jq -cer '.config')"; then
    settings_global="$settings_global --config '$config'"
  fi    
  if compress="$( echo "$dpl_settings" | jq -cer '.compress')"; then
    [ "${compress:-}" != 'true' ] || settings_global="$settings_global --compress"
  fi
  if meta0="$( echo "$dpl_settings" | jq -cer '.meta')"; then
    meta="$(merge_json_left2right "$meta" "$meta0")"
  fi
fi

# run export by list
IFS=' ' read -a dlps <<< $( echo "$dump" | jq -cer '.deployments|keys_unsorted[]' | tr '\n' ' ')

[ -n "${DEBUG:-}" ] && d_part="export DEBUG=1"

for dpl in "${dlps[@]}"; do

  # check filter by deployment
  if [[ "${#filter[@]}" -gt 0 ]]; then
    skip=1
    for f in "${filter[@]}"; do 
      if [[ "${f}" == "${dpl}" ]]; then 
        skip=
        break
      fi
    done
    if [ -n "$skip" ]; then 
        echo "Filtered: $dpl by >${filter[*]}<" 1>&2
        continue;
    fi
  fi

  #current deployment
  dpljson="$(echo "${dump}" | jq -cer '.deployments["'"$dpl"'"]')"

  # append host specific environments
  env_params="$total_env"
  if _env="$(echo "$dpljson" | jq -cer '.env|select(type=="object")')"; then
    env_params="$(merge_json_left2right "$env_params" "$_env")"
  fi

  #settings
  settings_dpl="${settings_global:-}"
  modes_depl=()
  if mset="$(echo "$dpljson" | jq -cr '.modes[]' 2>/dev/null)"; then
    IFS=' ' read -a modes_depl <<< $( echo "$mset" | tr '\n' ' ')
  fi
  modes_=("${modes[@]:-}" "${modes_depl[@]:-}")
  for mode in ${modes_[@]:-}; do 
    [ -n "$mode" ] || continue 
    if [ -z "$dpl_settings" ]; then echo "Error on >$dpl< mode >$mode< not found">&2; exit 1; fi
    if ! cnt="$(echo "$dpl_settings" | jq -cer ".modes.${mode}")"; then 
      echo "Error on >$dpl< mode >$mode< not found">&2
      exit 1
    else
      settings_dpl="$settings_dpl --modify '$cnt'"
    fi
  done

  #create dpl related dump path & azure params
  command="$( cat <<EOL
  if LC_ALL=C type -t Y_dump >/dev/null; then
    ${d_part:-} 
    Y_dump --meta '$meta' \
      --account '${account}' \
      --container '${container}' \
      --sas '${sas}' \
      --az_dir '${path}/${dpl}' \
      --name '${dumpdate}' \
      --env '$env_params' \
      ${settings_dpl:-}
  else
    echo "Y_dump function is not defined. Old version of deployment?"
  fi
EOL
    )" 
  (
    if [ -z "$vagrant" ]; then 
      to="$(echo "$dump" | jq -cer '.deployments["'"$dpl"'"].name')"
      hst="$(echo "$dump" | jq -cr '.deployments["'"$dpl"'"].host|select(type=="string")')"
      echo "$command" | g "$to" "${hst:-mngr0}"
    else
      echo "$command" | vagrant ssh
    fi
  ) >&2
  # out result

  echo "{ \"name\": \"$dpl\", \"path\": \"${path}/${dpl}/${dumpdate}\", \"account\" : \"$account\", \"container\": \"$container\", \"url\" : \"${account}.blob.core.windows.net/${container}/${path}/${dpl}/${dumpdate}\"}"

done

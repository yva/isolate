#!/usr/bin/env bash
set -eu -o pipefail

[ -z "${DEBUG:-}" ] || set -x
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# file with export sources list
list="$(pwd)/dumper.json"

# options
vagrant=
expminutes='30'
filter=()

while [[ $# -gt 0 ]]; do
    case "$1" in
    # name of file with export lst
      '--list') shift;
        list="$1"
      ;;
    # name of file with export lst
      '--filter'|'-f') shift;
        filter+=("$1")
      ;;
    # vagrant mode for debug
      '--vagrant')
        vagrant=1
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
set +eu
export PS1=tmpv
. /etc/bash.bashrc
set -eu
fi

dumpdate="$(date --iso-8601=seconds)"
version="$(jq -cr '.meta.version|select(type=="object")' "$list")"

IFS=' ' read -a dumps <<< $( jq -cer '.|del(.meta)|keys_unsorted[]' "$list" | tr '\n' ' ')
for dumpname in "${dumps[@]}"; do 

  # check filter
  if [[ "${#filter[@]}" -gt 0 ]]; then
    skip=1
    for f in "${filter[@]}"; do 
      if [[ "${f}" == "${dumpname}" ]]; then 
        skip=
        break
      fi
    done
    if [ -n "$skip" ]; then 
        echo "Filtered: $dumpname by >${filter[*]}<" 1>&2
        continue;
    fi
  fi

# get current dump
  dump="$(jq -cer ".${dumpname}" "$list")"  
  
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
  YVA_DUMP_PARAMS="$(jq -cer '.' <<- EOL
  { 
    "account" : "$account",
    "container": "$container",
    "sas": "$sas",
    "path": "$path/${dumpdate}"
  }
EOL
)"
#export YVA_DUMP_PARAMS

  dpl_settings_opt=
  if dpl_settings="$( echo "$dump" | jq -cer '.settings|select(type=="object")')"; then 
    if file="$( echo "$dpl_settings" | jq -cer '.file')"; then
      dpl_settings_opt="$dpl_settings_opt --settings '$file'"
    fi
    if config="$( echo "$dpl_settings" | jq -cer '.config')"; then
      dpl_settings_opt="$dpl_settings_opt --config '$config'"
    fi    
    if compress="$( echo "$dpl_settings" | jq -cer '.compress')"; then
      [ "${compress:-}" != 'true' ] || dpl_settings_opt="$dpl_settings_opt --compress"
    fi        
  fi

# meta
  meta="$(echo "$dump" | jq -cer '.meta')"
  meta0="$( jq -cer '.' <<-EOL
  {
    "who": "$(who -m | tr '\n' ',')",
    "id": "$(id -a| tr '\n' ',')",
    "time": "${dumpdate}"
  }
EOL
  )"
  meta=$(printf '%s\n%s' "$meta" "$meta0" | jq -scer '.[0]*.[1]')
  # run export by list
  IFS=' ' read -a dlps <<< $( echo "$dump" | jq -cer '.deployments|keys_unsorted[]' | tr '\n' ' ')

  [ -n "${DEBUG:-}" ] && d_part="export DEBUG=1"

  for dpl in "${dlps[@]}"; do

    env_params=''
    if _env="$(echo "$dump" | jq -cer '.deployments["'"$dpl"'"].env|select(type=="object")')"; then
      env_params="$env_params --env '$_env'"
    fi

    command="$( cat <<EOL
    if LC_ALL=C type -t Y_dump >/dev/null; then
      ${d_part:-} 
      Y_dump --meta '$meta' --azure '$YVA_DUMP_PARAMS' --name '$dpl' ${dpl_settings_opt:-} ${env_params:-}
    else
      echo "Y_dump function is not defined. Old version of deployment?"
    fi
EOL
    )" 
    if [ -z "$vagrant" ]; then 
      to="$(echo "$dump" | jq -cer '.deployments["'"$dpl"'"].name')"
      echo "$command" | g "$to" "mngr0"
    else
      echo "$command" | vagrant ssh
    fi

  done

done

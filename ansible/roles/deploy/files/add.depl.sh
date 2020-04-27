#!/bin/bash
set -eu -o pipefail
[ -z "${DEBUG:-}" ] || set -x
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

dpl="$1"
proxy="$2"
usr="${3:-yva}"

if ! echo "$proxy" | grep '^[.0-9]*$' >/dev/null; then
  # remove protocol prefix
  proxy="${proxy#http*://}"
  # remove path
  proxy="${proxy%%/*}"
  # remove port
  proxy="${proxy%%:*}"
  # make DNS request
  proxy="$(dig $proxy +short | grep '^[.0-9]*$' | head -n1)"
fi

# resolve prpoxy from url 
if [ -z  "$proxy" ]; then
  echo "Error! Stopped by no proxy or proxy $proxy not resolved!" >&2
  exit 1
fi

source /opt/auth/shared/bash.sh

# add proxy
auth-add-host --project "$dpl" --server-name proxy --ip "$proxy" --user "$usr"
id=$(s "$dpl" proxy |  sed -r 's/\x1B\[[0-9;]*[JKmsu]//g' | grep -oE '^[0-9]+')
auth-add-project-config "$dpl" --proxy-id "$id" --user "$usr" --nosudo 

## add host by consul
if ! echo 'consul members' | g "$dpl" proxy | "$DIR/hosts.by.consul.sh" "$dpl" "$usr"; then 
echo "consul add not worked, add default host"
auth-add-host --project "$dpl" --server-name mngr0 --ip 10.0.0.4 --user "$usr" 
fi
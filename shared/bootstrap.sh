umask 0077;
USER="${USER:-NO_USER_ENV}";
ISOLATE_DATA_ROOT="${ISOLATE_DATA_ROOT:-/opt/auth}";
ISOLATE_SHARED="${ISOLATE_DATA_ROOT}/shared";
ISOLATE_GROUP_CONFIG="${ISOLATE_DATA_ROOT}/configs/settings.json"
ISOLATE_HELPER="${ISOLATE_SHARED}/helper.py";
ISOLATE_DEPLOY_LOCK="${ISOLATE_DATA_ROOT}/.deploy";
ISOLATE_COLORS=true;
ISOLATE_DEFAULT_PROJECT="${ISOLATE_DEFAULT_PROJECT:-main}";

export USER;
export ISOLATE_DATA_ROOT;
export ISOLATE_SHARED;
export ISOLATE_HELPER;
export ISOLATE_COLORS;
export ISOLATE_DEPLOY_LOCK;
export ISOLATE_COLORS;
export ISOLATE_DEFAULT_PROJECT;


export LANG="en_US.UTF-8";
export LC_COLLATE="en_US.UTF-8";
export LC_CTYPE="en_US.UTF-8";
export LC_MESSAGES="en_US.UTF-8";
export LC_MONETARY="en_US.UTF-8";
export LC_NUMERIC="en_US.UTF-8";
export LC_TIME="en_US.UTF-8";
export LC_ALL="en_US.UTF-8";

PYTHONDONTWRITEBYTECODE=1;
export PYTHONDONTWRITEBYTECODE;

# envsust but dont subst undefined
function envsubst_butundef() {
  local ENVLIST
  # get all env which set 
  ENVLIST="$(compgen -e | sed -e 's/^/${/g' -e 's/$/}/' | tr '\n' ' ')"
  # subst 2 value 
  envsubst "$ENVLIST"
}

## apply kv from json with env subst
function apply_env_kv() {
  #input { key: value }
  local kv="${1}"
  local base64decode
  local keys

  [ "${2:-}" != '--decode' ] || base64decode=1

  # get list of installed applications and reverse it
  IFS=' ' read -a keys <<< "$(echo "$kv" | jq -cer '.|keys_unsorted[]' | tr '\n' ' ')"
 
  for key in "${keys[@]}"; do
    local rawvalue
    local value
    rawvalue="$(echo "$kv" | jq -cer '.["'"$key"'"]')"
    [ -z "${base64decode:-}" ] || rawvalue="$(echo "$rawvalue" | base64 -d)"
    value="$(echo  "$rawvalue" | envsubst_butundef)"
    set -a
    # if some variables not subst at value - we dont set it. leave in string
    eval "$key='${value}'"
    set +a
  done
}

gen-oath-safe () {
    bash --norc "${ISOLATE_DATA_ROOT}/shared/gen-oath-safe.sh" "${@}";
}

add-support-user-helper () {
    echo "";
    cat /opt/auth/add-support-user.sh;
    echo "";
}

redis-dev () {
    redis-cli -a "${ISOLATE_REDIS_PASS}" "${@}";
}

deploy_lock () {
    while [ ! -d "${ISOLATE_DATA_ROOT}" ]; do
        echo "ISOLATE Git root not found: ${ISOLATE_DATA_ROOT} awaiting deploy...";
        sleep 1;
    done

    while [ -f "${ISOLATE_DEPLOY_LOCK}" ]; do
        echo "Lock found: ${ISOLATE_DEPLOY_LOCK} awaiting deploy end...";
        sleep 1;
    done
}

auth_callback_cleanup () {
    # cat "${ISOLATE_SESSION}" 2>/dev/null;
    rm -f "${ISOLATE_SESSION}" > /dev/null 2>&1 || /bin/true;
}

auth_callback () {
    if [[ $# -eq 0 ]] ; then
        return
    fi
    SESS_DIR="${HOME}/.auth_sess";
    if [[ ! -d "${SESS_DIR}" ]] ; then
        mkdir -p "${SESS_DIR}";
    fi

    ISOLATE_SESSION=$(mktemp "${SESS_DIR}/ssh_XXXXXXXXX");
    export ISOLATE_SESSION;
    trap auth_callback_cleanup SIGHUP SIGINT SIGTERM EXIT;

    "${@}";

    source "${ISOLATE_SESSION}" > /dev/null 2>&1;
    auth_callback_cleanup;

    if [ "${ISOLATE_CALLBACK}" == "${ISOLATE_SESSION}" ]; then
        ${ISOLATE_CALLBACK_CMD:-/bin/false};
    fi
}

# set env 4 isolte group
# we set 
_set_access_group() {

  local kv
  local group="${1:-default}"
  if kv="$( jq -cer '.["'"${group}"'"].kv' "$ISOLATE_GROUP_CONFIG")"; then
    apply_env_kv "$kv"
    export ISOLATE_ACCESS_GROUP="$1"
    export PS1="[\\[\\033[35;5;75m\\]${group}\\[\\033[0m\\]][\\[\\033[38;5;75m\\]\\h\\[\\033[0m\\]][\\w]\\$ "
  else
    echo "Error load env $1, group info not found!" >&2 
  fi
}

g () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: g <project|host> [server_name] [ --user | --port | --nosudo | --debug ] \\n";
        return
    elif [[ $# -gt 0 ]] ; then
        deploy_lock
        auth_callback "${ISOLATE_HELPER}" go "${@}";
    fi
}

s () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: s <query> \\n";
        return
    elif [[ $# -gt 0 ]] ; then
        deploy_lock
        "${ISOLATE_HELPER}" search "${@}";
    fi
}

ag() {
     if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: ag <group>\\n Switch 2 default \\n";
        _set_access_group
        return
    elif [[ $# -gt 0 ]] ; then
        _set_access_group "$1"
    fi 
}

auth-add-user () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: auth-add-user <username> \\n";
        return
    elif [[ $# -gt 0 ]] ; then
        useradd "${1}" -m --groups auth -s /bin/bash;
        passwd "${1}";
    fi
}

auth-add-host () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: auth-add-host --project <project_name> --server-name <server_name> --ip 1.2.3.4 --port 22 --user root --nosudo \\n";
        return
    elif [[ $# -gt 0 ]] ; then
        "${ISOLATE_DATA_ROOT}/shared/auth-manager.py" "add-host" "${@}";
    fi
}

auth-dump-host () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: auth-dump-host <server_id>\\n";
        return
    elif [[ $# -gt 0 ]] ; then
        "${ISOLATE_DATA_ROOT}/shared/auth-manager.py" "dump-host" --server-id "${@}";
    fi
}

auth-del-host () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: auth-del-host <server_id>\\n";
        return
    elif [[ $# -gt 0 ]] ; then
        "${ISOLATE_DATA_ROOT}/shared/auth-manager.py" "del-host" --server-id "${@}";
    fi
}

auth-add-project-config () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: auth-add-project-config <project_name> --port 3222 --user root3 --nosudo \\n";
        return
    elif [[ $# -gt 0 ]] ; then
        "${ISOLATE_DATA_ROOT}/shared/auth-manager.py" "add-project-config" --project "${@}";
    fi
}

auth-del-project-config () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: auth-del-project-config <project_name>\\n";
        return
    elif [[ $# -gt 0 ]] ; then
        "${ISOLATE_DATA_ROOT}/shared/auth-manager.py" "del-project-config" --project "${@}";
    fi
}

auth-dump-project-config () {
    if [[ $# -eq 0 ]] ; then
        echo -e "\\n  Usage: auth-dump-project-config <project_name>\\n";
        return
    elif [[ $# -gt 0 ]] ; then
        "${ISOLATE_DATA_ROOT}/shared/auth-manager.py" "dump-project-config" --project "${@}";
    fi
}
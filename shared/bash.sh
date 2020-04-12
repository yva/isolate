# Main auth startup
# add to /etc/bashrc
# Example:
# if [ -f /opt/auth/shared/bash.sh ]; then
#     source /opt/auth/shared/bash.sh;
# fi

source /opt/auth/shared/env.sh;
source /opt/auth/shared/bootstrap.sh;

HISTTIMEFORMAT='[%F %T] '
HISTSIZE=10000
HISTFILESIZE=10000
shopt -s histappend # Append history instead of rewriting it
shopt -s cmdhist # Use one command per line

_set_access_group 'default'

_projects_bash()
{
    # Only projects completition for S
    local cur_word prev_word projects_list

    cur_word="${COMP_WORDS[COMP_CWORD]}"
    prev_word="${COMP_WORDS[COMP_CWORD-1]}"

    projects_list=$(redis-cli --no-auth-warning -a "${ISOLATE_REDIS_PASS}" get "projects_list" | tr '[:upper:]' '[:lower:]'  2>>/dev/null)

    if [ "${COMP_CWORD}" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${projects_list}" -- "${cur_word}") )
    fi

    return 0
}

complete -F _projects_bash s


_project_host_bash()
{
    # Only projects completition for G
    # Also hosts completition for second arg
    local cur_word prev_word projects_list

    cur_word="${COMP_WORDS[COMP_CWORD],,}"
    prev_word="${COMP_WORDS[COMP_CWORD-1],,}"

    projects_list=$(redis-cli --no-auth-warning -a "${ISOLATE_REDIS_PASS}" get "projects_list" | tr '[:upper:]' '[:lower:]'  2>>/dev/null)

    hosts_list=$(redis-cli --no-auth-warning -a "${ISOLATE_REDIS_PASS}" get "complete_hosts_${prev_word}" | tr '[:upper:]' '[:lower:]'  2>>/dev/null )

    if [ "${COMP_CWORD}" -eq 1 ]; then
        COMPREPLY=( $(compgen -W "${projects_list}" -- "${cur_word}") )
    elif [ "${COMP_CWORD}" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "${hosts_list}" -- "${cur_word}") )
    fi

    return 0
}

complete -F _project_host_bash g
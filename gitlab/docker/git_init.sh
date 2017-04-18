#!/usr/bin/env bash

# arguments:
# returns: git_hostname
git_hostname() {
    if [ -z "${GIT_HOSTNAME}" ]; then echo "local-git"; else echo "${GIT_HOSTNAME}"; fi
}

# arguments:
# returns: git_http_port
git_http_port() {
    if [ -z "${GIT_HTTP_PORT}" ]; then echo "no GIT_HTTP_PORT specified"; exit 1; else echo "${GIT_HTTP_PORT}"; fi
}

# arguments:
# returns: git_ssh_port
git_ssh_port() {
    if [ -z "${GIT_SSH_PORT}" ]; then echo "no GIT_SSH_PORT specified"; exit 1; else echo "${GIT_SSH_PORT}"; fi
}

# arguments:
# returns: git_workspace
git_workspace() {
    if [ -z "${GIT_WORKSPACE}" ]; then echo "no GIT_WORKSPACE specified"; exit 1; else echo "${GIT_WORKSPACE}"; fi
}

# arguments:
# returns: git_deploy_key
git_deploy_key() {
    if [ -z "${GIT_DEPLOY_KEY}" ]; then echo "no GIT_DEPLOY_KEY specified"; exit 1; else echo "${GIT_DEPLOY_KEY}"; fi
}

# arguments:
# returns: git_admin_key
git_admin_key() {
    if [ -z "${GIT_VOLUME}" ]; then echo "no GIT_VOLUME specified"; exit 1; else echo "${GIT_VOLUME}/$(git_hostname)"; fi
}

# arguments:
# returns: git_admin_user
git_admin_user() {
    if [ -z "${GIT_ADMIN_USERNAME}" ]; then echo "no GIT_ADMIN_USERNAME specified"; exit 1; else echo "${GIT_ADMIN_USERNAME}"; fi
}

# arguments:
# returns: git_admin_passwd
git_admin_passwd() {
    if [[ -z "${GITLAB_ROOT_PASSWORD}" ]]; then echo "$(git_admin_user)_pass"; else echo "${GITLAB_ROOT_PASSWORD}"; fi
}
# arguments:
# returns: git_admin_passwd
git_admin_passwd() {
    if [[ -z "${GITLAB_ROOT_PASSWORD}" ]]; then echo "$(git_admin_user)_pass"; else echo "${GITLAB_ROOT_PASSWORD}"; fi
}

git_root_email(){
    GITLAB_ROOT_EMAIL=${GIT_ADMIN_EMAIL}
    if [[ -z "${GIT_ADMIN_EMAIL}" ]]; then echo "$(git_admin_user)@xxx.com"; else echo "${GIT_ADMIN_EMAIL}"; fi
}
# arguments:
# returns: configserver_webhook_endpoint
configserver_webhook_endpoint() {
    if [[ -z "${CONFIGSERVER_WEBHOOK_ENDPOINT}" ]];then
        echo "no CONFIGSERVER_WEBHOOK_ENDPOINT specified, can not config HTTP endpoint for webhooks";
    else
        echo "${CONFIGSERVER_WEBHOOK_ENDPOINT}";
    fi
}

# arguments:
# returns:
init_git_admin_key() {
    local var_git_admin_key="$(git_admin_key)"

    if [ ! -f ${var_git_admin_key} ]; then
        ssh-keygen -t rsa -N "" -C "$(git_admin_user)" -f ${var_git_admin_key}
        chmod 600 ${var_git_admin_key}
        chmod 600 ${var_git_admin_key}.pub
    fi
}

print_info() {
    echo "--------------------------------------------------------------------------------"
    echo "git_admin_key public:"
    cat "$(git_admin_key)".pub
    echo "git_deploy_key:"
    cat "$(git_deploy_key)"

    local var_git_workspace="$(git_workspace)"
    echo "files in GIT_WORKSPACE ${var_git_workspace}:"
    ls -l ${var_git_workspace}
    echo "--------------------------------------------------------------------------------"
}

wait_git_service_up() {
    if [ ! -f /app/gitlab/wait-for-it.sh ]; then
        echo "init_git_async /app/gitlab/wait-for-it.sh not found, exit."
        exit 1
    else
        echo "init_git_async /app/gitlab/wait-for-it.sh found."
    fi

    local var_git_hostname="$(git_hostname)"
    local var_git_http_port="$(git_http_port)"
    local var_git_ssh_port="$(git_ssh_port)"

    echo "wait_git_service_up."
#    waitforit -full-connection=tcp://${var_git_hostname}:${var_git_http_port} -timeout=600
    /app/gitlab/wait-for-it.sh ${var_git_hostname}:${var_git_ssh_port} -t 600
    /app/gitlab/wait-for-it.sh ${var_git_hostname}:${var_git_http_port} -t 600
    sleep 10
    #waitforit -full-connection=tcp://${var_git_hostname}:${var_git_http_port} -timeout=600 -debug
    echo "wait_git_service_up end."
}

wait_http_ok(){
    echo "wait http response Ok(200)"
    local var_git_hostname="$(git_hostname)"
    local var_git_http_port="$(git_http_port)"
    local var_git_http_prefix="http://${var_git_hostname}:${var_git_http_port}"
    # 重试时间间隔
    local retry_interval=5
    # 重试次数
    local retry_times=100

    for i in $(seq 10); do
        local http_resp_status=$(curl -s -o /dev/null -I -w "%{http_code}\n" ${var_git_http_prefix}/help);
        echo "http response code :${http_resp_status}"
        if test ${http_resp_status} = "200"; then
            echo "gitlab service ok"
            break;
        fi
        echo "wait ${retry_interval} seconds"
        sleep ${retry_interval};
    done;
}

get_git_group_name(){
    local git_repo_dir=$1
    local var_git_group_name=$(cd ${git_repo_dir}; git remote -v | grep -E 'upstream.+(fetch)' | sed -E 's#.+[:|/]([^/]+)/[^/]+\.git.*#\1#');
    if [ -z ${var_git_group_name} ]; then
        var_git_group_name=$(cd ${git_repo_dir}; git remote -v | grep -E 'origin.+(fetch)' | sed -E 's#.+[:|/]([^/]+)/[^/]+\.git.*#\1#');
    fi
    echo ${var_git_group_name}
}

# arguments:
# returns:
init_git() {
    echo "init_git $@"
    . /app/gitlab/gitlab_utils.sh

    local var_git_hostname="$(git_hostname)"
    local var_git_http_port="$(git_http_port)"
    local var_git_http_prefix="http://${var_git_hostname}:${var_git_http_port}"
    local var_git_admin_key="$(git_admin_key)"
    local var_git_work_space="$(git_workspace)"

    local var_git_admin_user="$(git_admin_user)"
    local var_git_admin_passwd="$(git_admin_passwd)"
    local var_configserver_webhook_endpoint="$(configserver_webhook_endpoint)"

    init_git_admin_key
    print_info
    wait_git_service_up
    wait_http_ok

    git_service_install ${var_git_http_prefix} ${var_git_admin_user} ${var_git_admin_passwd}

    # setup ssh key into for git command-line access (push repositories)
    git_service_ssh_key ${var_git_http_prefix} ${var_git_admin_user} ${var_git_admin_passwd} ${var_git_admin_key}.pub
    # edit ~/.ssh/config
    local var_git_ssh_port="$(git_ssh_port)"
    git_service_ssh_config ${var_git_hostname} ${var_git_ssh_port} ${var_git_admin_key}

    # find all repositories that has a '-config' suffix
    local git_repos=($(find ${var_git_work_space} -mindepth 1 -maxdepth 1 -type d | awk -F "${var_git_work_space}/" '{print $2}'))
    #  | grep -E '.+-config.{0}'
    for git_repo in "${git_repos[@]}"; do
        local repo_dir="${var_git_work_space}/${git_repo}"
        if [ -d ${repo_dir}/.git ]; then
            # find remote git group
            local var_git_group_name=$(get_git_group_name ${repo_dir})
            echo "creating git_repo: ${var_git_group_name}/${git_repo}"
            git_service_create_repo ${var_git_http_prefix} ${var_git_admin_user} ${var_git_admin_passwd} ${var_git_group_name} ${git_repo}

            # git branches have been checkout
            #git_branches=($(cd ${repo_dir}; git for-each-ref --sort=-committerdate refs/heads/ --format='%(refname:short)'))
            # git branches of refs/remotes/origin/* except HEAD
            git_branches=($(cd ${repo_dir}; git for-each-ref --sort=-committerdate refs/remotes/origin/ --format='%(refname:short)' | sed 's#^origin/##' | grep -v HEAD))
            echo "git_branches: ${git_branches[@]}"
            for git_branch in "${git_branches[@]}"; do
                git_service_push_repo ${var_git_work_space} ${var_git_hostname} ${var_git_hostname} ${var_git_group_name} ${git_repo} refs/remotes/origin/${git_branch} refs/heads/${git_branch}
            done

            # configserver gourp need webhook
            if [ ${var_git_group_name} == "configserver" ] && [ ${var_configserver_webhook_endpoint} ];then
                git_web_hook ${var_git_http_prefix} ${var_git_admin_user} ${var_git_admin_passwd} ${var_git_group_name} ${git_repo} ${var_configserver_webhook_endpoint}
            fi

        fi
    done

    # setup deploy key for client read-only access
    #local var_deploy_key=$(git_deploy_key_file "$(git_deploy_key)")
    local var_deploy_key="$(git_deploy_key)"
    if [ ! -z ${var_deploy_key} ]; then
        for git_repo in "${git_repos[@]}"; do
            local repo_dir="${var_git_work_space}/${git_repo}"
            if [ -d ${repo_dir}/.git ]; then
                echo "set deploy key for git_repo: ${git_repo}"
                local var_git_group_name=$(get_git_group_name ${repo_dir})
                git_service_deploy_key ${var_git_http_prefix} ${var_git_admin_user} ${var_git_admin_passwd} ${var_git_group_name} ${git_repo} ${var_deploy_key}
            fi
        done
    else
        echo "git_deploy_key_file not found."
        exit 1
    fi
}

export_git_admin_key() {
    cat $(git_admin_key)
}

export_git_deploy_key() {
    cat $(git_deploy_key)
}

## arguments: jar/zip archive, file, target
## returns:
#extract_file_from_archive() {
#    local archive="$1"
#    local file="$2"
#    local target="$3"
#    if [[ ${file:0:1} == / ]]; then file=${file:1}; fi
#    echo "EXTRACT unzip -p ${archive} ${file} > ${target}" 1>&2
#    unzip -p ${archive} ${file} > ${target}
#    local result=$?
#    cat ${target} 1>&2
#    echo "EXTRACT return code ${result}" 1>&2
#}
#
## arguments: target
## returns: git_deploy_key_file
#git_deploy_key_file() {
#    local archive=$(ls | grep .jar | grep -v sources.jar | grep -v jar.original)
#    local target=$1
#    local result=""
#    if [ -z "${SPRING_CLOUD_CONFIG_SERVER_DEPLOYKEY}" ]; then
#        extract_file_from_archive ${archive} BOOT-INF/classes/deploy_key.pub ${target}
#        if [ -f ${target} ]; then
#            result=${target}
#        else
#            result=""
#        fi
#    elif [ ${SPRING_CLOUD_CONFIG_SERVER_DEPLOYKEY:0:10} == classpath: ]; then
#        extract_file_from_archive ${archive} BOOT-INF/classes/${SPRING_CLOUD_CONFIG_SERVER_DEPLOYKEY:10}.pub ${target}
#        if [ -f ${target} ]; then
#            result=${target}
#        else
#            result=""
#        fi
#    elif [ ${SPRING_CLOUD_CONFIG_SERVER_DEPLOYKEY:0:5} == file: ] && [ -f ${SPRING_CLOUD_CONFIG_SERVER_DEPLOYKEY:0:5} ]; then
#        result=${SPRING_CLOUD_CONFIG_SERVER_DEPLOYKEY:5}
#    elif [ -f ${SPRING_CLOUD_CONFIG_SERVER_DEPLOYKEY} ]; then
#        result=${SPRING_CLOUD_CONFIG_SERVER_DEPLOYKEY}
#    else
#        result="";
#    fi
#    if [ -f ${result} ]; then
#        chmod 600 ${result}
#    fi
#    echo ${result}
#}

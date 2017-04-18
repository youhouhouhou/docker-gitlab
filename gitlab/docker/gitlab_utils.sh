#!/usr/bin/env bash

# for gogs:0.9.97

# : is %3A
# / is %2F
# @ is %40



# arguments: git_http_prefix, git_user_name, git_user_passwd
# returns:   private_token
# https://docs.gitlab.com/ce/api/session.html
# jq:  https://stedolan.github.io/jq/tutorial/
git_service_login() {
   if [ -z ${PRIVATE_TOKEN} ]; then
        #  printf '%s \n' ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_login"
        PRIVATE_TOKEN=$(
        curl  -X POST \
        -d \
        '' \
        "${1}/api/v3/session?login=${2}&password=${3}" \
        | jq -r '.private_token')
   fi
}

# arguments: git_http_prefix, git_admin_user, git_admin_passwd
# returns:
git_service_install() {
    git_service_login $1 root $3
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_install ${2}:******@${1}"
    local var_git_app_url="http://${2}:${3}"

    local body='{
      "username": "'${2}'",
      "email": "'${2}'@xxx.com",
      "name": "'${2}'",
      "password":"'${3}'",
      "is_admin": true
    }'
    # https://docs.gitlab.com/ce/api/users.html#user-creation
    curl -i -X POST \
       -H "Content-Type:application/json" \
       -H "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
       -d "${body}"\
     "${1}/api/v3/users"
    # clear token
    unset PRIVATE_TOKEN
}

# arguments: git_http_prefix, git_user_name, git_user_passwd, git_group_name
# returns:
git_service_create_group() {
    git_service_login $1 $2 $3
#    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_create_group ${1} ${2} ${4}"

    local body='{
        "name": "'${4}'",
        "path": "'${4}'"
    }'
    # https://docs.gitlab.com/ce/api/groups.html#new-group
   curl -X POST \
   -H "Content-Type:application/json" \
   -H "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
   -d "${body}"\
    "$1/api/v3/groups"
}

# arguments: git_http_prefix, git_user_name, git_user_passwd, git_group_name
# returns:
git_service_find_group_id() {
    git_service_login $1 $2 $3;
    # printf '%s \n' ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_find_group_id ${1} ${2} ${4}"

    # https://docs.gitlab.com/ce/api/groups.html#search-for-group
    local var_group_id=$(
        curl -X GET \
        -H "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
        "${1}/api/v3/groups/${4}" \
        | jq -r '.id')
    echo ${var_group_id}
}


# arguments: git_http_prefix, git_user_name, git_user_passwd, git_group_name, git_project_name
# returns:
git_service_find_project_id() {
    git_service_login $1 $2 $3
#    printf '%s\n' ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_find_project_id ${1} ${2} ${4} ${5}"

    # https://docs.gitlab.com/ce/api/projects.html#get-single-project
    local project_id=$(
    curl -X GET \
    -H "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
    "${1}/api/v3/projects/${4}%2F${5}" \
    | jq -r '.id')
    echo ${project_id}
}

# arguments: git_http_prefix, git_user_name, git_user_passwd, git_group_name, repo_name
# returns:
git_service_create_repo() {
    git_service_login $1 $2 $3
    git_service_create_group $1 $2 $3 $4

    local group_id=$(git_service_find_group_id $1 $2 $3 $4)
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_create_repo ${1} ${2} ${4} ${5}"

    local body='{
      "name": "'${5}'",
      "namespace_id": '${group_id}'
    }'
    echo ${body}
    # https://docs.gitlab.com/ce/api/projects.html#create-project
    curl -i -X POST \
   -H "Content-Type:application/json" \
   -H "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
   -d "${body}" \
    "${1}/api/v3/projects"
}

# arguments: git_http_prefix, git_user_name, git_user_passwd, git_group_name, repo_name, public_key_file
# returns:
git_service_deploy_key() {
    git_service_login $1 $2 $3
    local project_id=$(git_service_find_project_id ${1} ${2} ${3} ${4} ${5})
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_deploy_key ${1} ${2} ${4} ${5} ${6}"
    local title="$(cat ${6} | cut -d' ' -f3)_$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)"
    local content="$(cat ${6} | cut -d' ' -f1) $(cat ${6} | cut -d' ' -f2)"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_deploy_key title: ${title}"
    # echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_deploy_key content: ${content}"

    # https://docs.gitlab.com/ce/api/deploy_keys.html#add-deploy-key
    local body='{
       "key" : "'${content}'",
       "id" : '${project_id}',
       "title" : "'${title}'",
       "can_push": true
    }'
    echo ${body}
    curl -i -X POST \
       -H "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
       -H "Content-Type:application/json" \
       -d "${body}"\
    "${1}/api/v3/projects/${project_id}/deploy_keys"

}

# arguments: git_http_prefix, git_user_name, git_user_passwd, public_key_file
# returns:
git_service_ssh_key() {
    git_service_login $1 $2 $3
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_ssh_key ${1} ${2} ${4}"
    local title="$(cat ${4} | cut -d' ' -f3)_$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)"
    local content="$(cat ${4} | cut -d' ' -f1) $(cat ${4} | cut -d' ' -f2)"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_ssh_key title: ${title}"
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_ssh_key content: ${content}"

    local body='{
      "title":"'${title}'",
      "key":"'${content}'"
     }'

    # https://docs.gitlab.com/ce/api/users.html#add-ssh-key
    curl -i -X POST \
    -H "Content-Type:application/json" \
    -H "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
    -d "${body}" \
    "${1}/api/v3/user/keys"
}

# arguments: git_hostname, git_ssh_port, private_key_file
# returns:
git_service_ssh_config() {
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_ssh_config ${1}:${2} ${3}"
    if [ ! -f ${3} ]; then
        echo "private_key_file ${3} not found"
        exit 1
    fi
    mkdir -p "${HOME}/.ssh"
    local sshconfig="${HOME}/.ssh/config"
    if [ ! -f ${sshconfig} ] || [ -z "$(cat ${sshconfig} | grep 'StrictHostKeyChecking no')" ]; then
        printf "\nHost *\n\tStrictHostKeyChecking no\n\tUserKnownHostsFile /dev/null\n" >> ${sshconfig}
    fi
    if [ -z "$(cat ${sshconfig} | grep Port | grep ${2})" ]; then
        printf "\nHost ${1}\n\tHostName ${1}\n\tPort ${2}\n\tUser git\n\tPreferredAuthentications publickey\n\tIdentityFile ${3}\n" >> ${sshconfig}
    fi
    chmod 644 ${sshconfig}
    cat ${sshconfig}
}

# arguments: repo_location, git_hostname, remote, git_group_name, repo_name, source_ref, target_ref
# returns:
git_service_push_repo() {
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_service_push_repo ${1}/${5} ${2} ${3} ${4}/${5} ${6} ${7}"
    local repo_dir="${1}/${5}"
    local remote="${3}"
    # git remote -v
    if [ -d ${repo_dir}/.git ]; then
        echo "git remote rm ${remote}; git remote add ${remote} git@${2}:${4}/${5}.git;"
        (cd ${repo_dir}; git remote rm ${remote}; git remote add ${remote} git@${2}:${4}/${5}.git;)
        echo "git push ${remote} ${6}:${7}"
        (cd ${repo_dir}; git push ${remote} ${6}:${7})
    else
        echo "git repo ${repo_dir}/.git not found"
    fi
}


# arguments: git_http_prefix, git_user_name, git_user_passwd, git_group_name, repo_name, webhook_url
# returns: http_status 201 created
git_web_hook() {
    git_service_login $1 $2 $3
    local project_id=$(git_service_find_project_id ${1} ${2} ${3} ${4} ${5})
    echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>> git_web_hook ${1} ${2} ${4} ${5} ${6}"

    local body='{
        "url": "'${6}'",
        "enable_ssl_verification":false
    }'
    echo ${project_id}  ${body}
    # https://docs.gitlab.com/ce/api/projects.html#add-project-hook
   curl -v -X POST \
   -H "PRIVATE-TOKEN:${PRIVATE_TOKEN}" \
   -H "Content-Type:application/json" \
   -d "${body}" \
    "${1}/api/v3/projects/${project_id}/hooks"
}

#!/usr/bin/env bash

set -euo pipefail

source ./outputs.sh "${1}"

ANSIBLE_INVENTORY="####
# Ansible Hosts File for HPE Container Platform Deployment
# created by Dirk Derichsweiler
# modified by Erdinc Kaya
#
# Important:
# use only ip addresses in this file
####
[controllers]
$(echo ${CTRL_PRV_IPS[@]} | sed 's/ /\n/g')
[gateway]
$(echo ${GATW_PRV_IPS[@]} | sed 's/ /\n/g')
[workers]
$(echo ${WRKR_PRV_IPS[@]} | sed 's/ /\n/g')
[gworkers]
$(echo ${GWRKR_PRV_IPS[@]} | sed 's/ /\n/g')
[ad_server]
${AD_PRV_IP}
[mapr]
$(echo ${MAPR_PRV_IPS[@]} | sed 's/ /\n/g')
[all:vars]
ansible_connection=ssh
ansible_user=centos
install_file=${EPIC_FILENAME}
download_url=${EPIC_DL_URL}
admin_password=${ADMIN_PASSWORD}
gateway_pub_dns=${GATW_PUB_DNS[0]}
ssh_prv_key=${SSH_PRV_KEY_PATH}
is_mlops=${IS_MLOPS}
is_mapr=${IS_MAPR}
is_runtime=${IS_RUNTIME}
is_stable=${IS_STABLE}
ad_realm=SAMDOM.EXAMPLE.COM
app_version=${APP_VERSION}
k8s_version=${K8S_VERSION}

"

echo "${ANSIBLE_INVENTORY}" > ./ansible/inventory.ini

SSH_OPTS="-i generated/controller.prv_key -o ServerAliveInterval=30 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ProxyCommand=\"ssh -i generated/controller.prv_key -o ServerAliveInterval=30 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -W %h:%p -q centos@${GATW_PUB_IPS[0]}\""
[[ -d ./ansible/group_vars/ ]] || mkdir ./ansible/group_vars
echo "ansible_ssh_common_args: ${SSH_OPTS}" > ./ansible/group_vars/all.yml

# echo "Gateway at: $GATW_PUB_DNS"
### TODO: Move to ansible task
SSH_CONFIG="
Host *
  StrictHostKeyChecking no
Host hpecp_gateway
  Hostname ${GATW_PUB_DNS[0]}
  IdentityFile generated/controller.prv_key
  ServerAliveInterval 30
  User centos
Host 10.1.0.*
    Hostname %h
    ConnectionAttempts 3
    IdentityFile generated/controller.prv_key
    ProxyJump hpecp_gateway

"

[[ -d ~/.ssh ]] || mkdir ~/.ssh && chmod 700 ~/.ssh
echo "${SSH_CONFIG}" > ~/.ssh/config ## TODO: move to ansible, delete on destroy

pushd ./generated/ > /dev/null
  rm -rf "${GATW_PUB_DNS}"
  if [[ $IS_RUNTIME == "true" ]]; then
    CTRL_DOMAINS="${CTRL_PRV_DNS},${CTRL_PRV_DNS%%.*}"
    CTRL_IPS="$(echo ${CTRL_PRV_IPS[@]} | sed 's/ /,/g')"
  else
    CTRL_DOMAINS=""
    CTRL_IPS=""
  fi
  ALL_DOMAINS="${GATW_PUB_DNS},${GATW_PRV_DNS},${GATW_PUB_DNS%%.*},${GATW_PRV_DNS%%.*},${CTRL_DOMAINS},localhost"
  ALL_IPS="${GATW_PUB_IPS},$(echo ${GATW_PRV_IPS[@]} | sed 's/ /,/g'),${CTRL_IPS},127.0.0.1"
  minica -domains "$(echo "$ALL_DOMAINS" | sed 's/,,/,/g')" -ip-addresses "$(echo "$ALL_IPS" | sed 's/,,/,/g')"
popd > /dev/null 

exit 0

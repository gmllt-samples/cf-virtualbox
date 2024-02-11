#!/bin/bash

account_name="${1}"
account_email="${2}"
if [ -z "${account_name}" ]; then
  echo "Usage: $0 <account_name> <account_email>"
  exit 1
fi
if [ -z "${account_email}" ]; then
  echo "Usage: $0 <account_name> <account_email>"
  exit 1
fi
echo -n "Enter password: "
read -s -r account_password
echo
if [ -z "${account_password}" ]; then
  echo "Usage: $0 <account_name> <account_email>"
  echo "Password cannot be empty"
  exit 1
fi

STEP() { echo ; echo ; echo "==\\" ; echo "===>" "$@" ; echo "==/" ; echo ; }

dir_name="$(dirname "${BASH_SOURCE[0]}")"
real_path="$(realpath "${dir_name}")"
paas_dir="$(cd "${real_path}/.." && pwd)"
deployments_dir="${paas_dir}/deployments"
cf_dir="${paas_dir}/cf"
cf_vars_dir="${cf_dir}/vars"


###
STEP "Create UAA user"
###
source "${deployments_dir}/.envrc"
system_domain="$(bosh int "${cf_vars_dir}/vars.yml" --path /system_domain)"
bosh_deployment_name="$(bosh int "${deployments_dir}/bosh.yml" --path /instance_groups/name=bosh/properties/director/name)"
api_domain="api.${system_domain}"
uaa_url="https://uaa.${system_domain}"
credhub api --server "${api_domain}" --skip-tls-validation
uaac target "${uaa_url}" --skip-ssl-validation
uaac token client get admin -s "$(credhub g -n "/${bosh_deployment_name}/cf/uaa_admin_client_secret" --output-json | jq .value -r)"
uaac user add "${account_name}" --emails "${account_email}" -p "${account_password}"
for scope in cloud_controller.admin clients.read clients.secret clients.write uaa.admin scim.write scim.read; do
  uaac member add "${scope}" "${account_name}"
done

echo Succeeded
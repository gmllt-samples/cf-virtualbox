#!/bin/bash

set -eu -o pipefail

dir_name="$(dirname "${BASH_SOURCE[0]}")"
real_path="$(realpath "${dir_name}")"
paas_dir="$(cd "${real_path}/.." && pwd)"
bosh_dir="${paas_dir}/bosh"
bosh_deployment_dir="${bosh_dir}/bosh-deployment"
deployments_dir="${paas_dir}/deployments"
cf_dir="${paas_dir}/cf"
cf_deployment_dir="${cf_dir}/cf-deployment"
cf_ops_dir="${cf_dir}/operations"
cf_vars_dir="${cf_dir}/vars"

STEP() { echo ; echo ; echo "==\\" ; echo "===>" "$@" ; echo "==/" ; echo ; }

source "${deployments_dir}/.envrc"

####
STEP "Creating CF manifest"
####
bosh int "${cf_deployment_dir}/cf-deployment.yml" \
  -o "${cf_deployment_dir}/operations/bosh-lite.yml" \
  -o "${cf_deployment_dir}/operations/use-compiled-releases.yml" \
  -o "${cf_ops_dir}/custom-diego-cells-number.yml" \
  -l "${cf_vars_dir}/vars.yml" \
  > "${deployments_dir}/cf.yml"

echo Succeeded

###
STEP "Update cloud-config"
###
bosh -ne vbox update-cloud-config "${cf_deployment_dir}/iaas-support/bosh-lite/cloud-config.yml"


###
STEP "Update dns config"
###
bosh -ne vbox update-runtime-config "${bosh_deployment_dir}/runtime-configs/dns.yml" \
  --name dns


###
STEP "Upload stemcell"
###
stemcell_version="$(bosh int "${deployments_dir}/cf.yml" --path /stemcells/alias=default/version)"
already_uploaded=false
while read -r line; do
  if [ "${line}" == "${stemcell_version}" ]; then
    already_uploaded=true
    break
  fi
done < <(bosh -e vbox stemcells --json | jq '.Tables[0].Rows[].version' -r | sed 's/\*//g')
if [ "${already_uploaded}" == "false" ]; then
  bosh -e vbox upload-stemcell  \
    "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-jammy-go_agent?v=${stemcell_version}"
fi

####
STEP "Creating CF deployment"
####
bosh -ne vbox -d cf deploy "${deployments_dir}/cf.yml" \
  --no-redact

echo Succeeded

####
STEP "Cleaning bosh"
####
bosh -ne vbox clean-up --all

####
STEP "Authenticate into Cloud Foundry"
####
system_domain="$(bosh int "${cf_vars_dir}/vars.yml" --path=/system_domain)"
cf api --skip-ssl-validation "https://api.${system_domain}"
credhub api --server api.bosh-lite.com --skip-tls-validation
cf login -u admin -p "$(credhub get -n /bosh-lite/cf/cf_admin_password -q)"

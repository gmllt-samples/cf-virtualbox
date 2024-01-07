#!/bin/bash

set -eu -o pipefail

dir_name="$(dirname "${BASH_SOURCE[0]}")"
real_path="$(realpath "${dir_name}")"
paas_dir="$(cd "${real_path}/.." && pwd)"
bosh_dir="${paas_dir}/bosh"
bosh_deployment_dir="${bosh_dir}/bosh-deployment"
bosh_deployment_sha="$(cd "${bosh_deployment_dir}" && git rev-parse --short HEAD)"
bosh_ops_dir="${bosh_dir}/operations"
deployments_dir="${paas_dir}/deployments"
cf_dir="${paas_dir}/cf"
cf_deployment_dir="${cf_dir}/cf-deployment"
cf_ops_dir="${cf_dir}/operations"
ip_prefix="192.168.56"
internal_ip="${ip_prefix}.6"
internal_gw="${ip_prefix}.1"
internal_cidr="${ip_prefix}.0/24"
network_prefix="10.244.0"
network_cidr="${network_prefix}.0/16"

STEP() { echo ; echo ; echo "==\\" ; echo "===>" "$@" ; echo "==/" ; echo ; }


####
STEP "Creating BOSH manifest"
####
bosh int "${bosh_deployment_dir}/bosh.yml" \
  -o "${bosh_deployment_dir}/virtualbox/cpi.yml" \
  -o "${bosh_deployment_dir}/virtualbox/outbound-network.yml" \
  -o "${bosh_deployment_dir}/bosh-lite.yml" \
  -o "${bosh_deployment_dir}/uaa.yml" \
  -o "${bosh_deployment_dir}/credhub.yml" \
  -o "${bosh_deployment_dir}/jumpbox-user.yml" \
  -o "${bosh_ops_dir}/custom-vms-resources.yml" \
  -o "${bosh_ops_dir}/custom-bosh-password.yml" \
  -o "${bosh_ops_dir}/bridge-outbound-network.yml" \
  --vars-store "${deployments_dir}/creds.yml" \
  -v director_name=bosh-lite \
  -v internal_ip="${internal_ip}" \
  -v internal_gw="${internal_gw}" \
  -v internal_cidr="${internal_cidr}" \
  -v outbound_network_name=NatNetwork \
  -v network_device=enp7s0 \
  > "${deployments_dir}/bosh.yml"

echo Succeeded

####
STEP "Creating BOSH Director"
####
bosh create-env "${deployments_dir}/bosh.yml" \
  --state "${deployments_dir}/state.json" \
  "$@"

####
STEP "Adding Network Routes (sudo is required)"
####
if [ "$(ip route show | grep "${network_cidr}")" != "" ]; then
  sudo ip route del "${network_cidr}"
fi
sudo ip route add "${network_cidr}" via "${internal_ip}"

echo Succeeded

####
STEP "Generating .envrc"
####

cat > "${deployments_dir}/.envrc" <<EOF
export BOSH_ENVIRONMENT=vbox
export BOSH_CA_CERT=\$( bosh interpolate ${deployments_dir}/creds.yml --path /director_ssl/ca )
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=\$( bosh interpolate ${deployments_dir}/creds.yml --path /admin_password )

export CREDHUB_SERVER=https://${internal_ip}:8844
export CREDHUB_CA_CERT="\$( bosh interpolate ${deployments_dir}/creds.yml --path=/credhub_tls/ca )
\$( bosh interpolate ${deployments_dir}/creds.yml --path=/uaa_ssl/ca )"
export CREDHUB_CLIENT=credhub-admin
export CREDHUB_SECRET=\$( bosh interpolate ${deployments_dir}/creds.yml --path=/credhub_admin_client_secret )

EOF
echo "export bosh_deployment_sha=${bosh_deployment_sha}" >> "${deployments_dir}/.envrc"


source "${deployments_dir}/.envrc"

echo Succeeded

####
STEP "Export jumpbox private key"
####

bosh int "${deployments_dir}/creds.yml" --path /jumpbox_ssh/private_key > "${deployments_dir}/jumpbox.key"
chmod 600 "${deployments_dir}/jumpbox.key"

echo Succeeded

####
STEP "Configuring Environment Alias"
####

bosh \
  --environment "${internal_ip}" \
  --ca-cert <( bosh interpolate "${deployments_dir}/creds.yml" --path /director_ssl/ca ) \
  alias-env vbox


####
STEP "Creating CF manifest"
####
bosh int "${cf_deployment_dir}/cf-deployment.yml" \
  -o "${cf_deployment_dir}/operations/bosh-lite.yml" \
  -o "${cf_deployment_dir}/operations/use-compiled-releases.yml" \
  -o "${cf_ops_dir}/custom-diego-cells-number.yml" \
  -v system_domain=bosh-lite.com \
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
bosh -e vbox upload-stemcell  \
  "https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-jammy-go_agent?v=${stemcell_version}"


####
STEP "Creating CF deployment"
####
bosh -ne "${internal_ip}" -d cf deploy "${deployments_dir}/cf.yml"

echo Succeeded

####
STEP "Authenticate into Cloud Foundry"
####
cf api --skip-ssl-validation https://api.bosh-lite.com
credhub api --server api.bosh-lite.com --skip-tls-validation
cf login -u admin -p "$(credhub get -n /bosh-lite/cf/cf_admin_password -q)"

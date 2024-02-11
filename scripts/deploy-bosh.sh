#!/bin/bash

set -eu -o pipefail

dir_name="$(dirname "${BASH_SOURCE[0]}")"
real_path="$(realpath "${dir_name}")"
paas_dir="$(cd "${real_path}/.." && pwd)"
bosh_dir="${paas_dir}/bosh"
bosh_deployment_dir="${bosh_dir}/bosh-deployment"
bosh_deployment_sha="$(cd "${bosh_deployment_dir}" && git rev-parse --short HEAD)"
bosh_ops_dir="${bosh_dir}/operations"
bosh_vars_dir="${bosh_dir}/vars"
deployments_dir="${paas_dir}/deployments"
network_cidr="10.244.0.0/16"

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
  -l "${bosh_vars_dir}/vars.yml" \
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
internal_ip="$(bosh int "${deployments_dir}/bosh.yml" --path=/instance_groups/name=bosh/networks/name=default/static_ips/0)"
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
#!/usr/bin/env bash

dir_name="$(dirname "${BASH_SOURCE[0]}")"
real_path="$(realpath "${dir_name}")"
paas_dir="$(cd "${real_path}/.." && pwd)"
deployments_dir="${paas_dir}/deployments"

STEP() { echo ; echo ; echo "==\\" ; echo "===>" "$@" ; echo "==/" ; echo ; }

if [ -f "${deployments_dir}/state.json" ]; then
  bosh_lite_vm_id=$(jq '.current_vm_cid' -r < "${deployments_dir}/state.json")
  current_stemcell_id=$(jq '.current_stemcell_id' -r < "${deployments_dir}/state.json")

  ####
  STEP "Removing Bosh_Lite VM with ID ${bosh_lite_vm_id}"
  ####
  VBoxManage unregistervm "${bosh_lite_vm_id}" --delete

  echo Succeeded

  ####
  STEP "Removing Stemcell with ID ${current_stemcell_id}"
  ####
  bosh delete-stemcell "sc-${current_stemcell_id}" --delete

  echo Succeeded

  ####
  STEP "Removing deployments directory"
  ####
  rm -rf "${deployments_dir}/*"
fi

"${real_path}/create-env.sh"
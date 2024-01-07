#!/usr/bin/env bash

dir_name="$(dirname "${BASH_SOURCE[0]}")"
real_path="$(realpath "${dir_name}")"
paas_dir="$(cd "${real_path}/.." && pwd)"
deployments_dir="${paas_dir}/deployments"
ip_prefix="192.168.56"
internal_ip="${ip_prefix}.6"
network_prefix="10.244.0"
network_cidr="${network_prefix}.0/16"
bosh_lite_vm_id=$(jq '.current_vm_cid' -r < "${deployments_dir}/state.json")

case $1 in
  ssh)
    ssh -i "${deployments_dir}/jumpbox.key" "jumpbox@${internal_ip}"
    ;;
  pause)
    echo "Pausing Bosh_Lite VM with ID ${bosh_lite_vm_id}..."
    VBoxManage controlvm "${bosh_lite_vm_id}" savestate
    echo "Pausing Bosh_Lite VM with ID ${bosh_lite_vm_id}... Done!."
    ;;
  resume)
    echo "Resuming Bosh_Lite VM with ID ${bosh_lite_vm_id}..."
    VBoxManage startvm "${bosh_lite_vm_id}" --type=headless
    echo "Resuming Bosh_Lite VM with ID ${bosh_lite_vm_id}... Done!"
    if [ "$(ip route show | grep "${network_cidr}")" != "" ]; then
      sudo ip route del "${network_cidr}"
    fi
    sudo ip route add "${network_cidr}" via "${internal_ip}"
    ;;
  *)
    echo "Usage: bosh_vm {ssh|pause|resume}" ;;
esac
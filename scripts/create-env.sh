#!/bin/bash

set -eu -o pipefail

dir_name="$(dirname "${BASH_SOURCE[0]}")"
real_path="$(realpath "${dir_name}")"

"${real_path}/deploy-bosh.sh"
"${real_path}/deploy-cf.sh"
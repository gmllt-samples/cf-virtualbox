# gmllt-samples/cf-virtualbox

## Description

This is a simple Bosh and Cloud Foundry deployment for Virtualbox 7.

## Requirements

### System

* Ubuntu 22.04
* 16GB RAM
* 8 CPUs

you can modify the RAM and CPU in the `bosh/operations/vms-resources.yml` file.

### Git

Make sure Git is installed on your system.

```bash
sudo apt-get install git
```

### jq

Make sure jq is isntalled on your system.

```bash
sudo apt-get install jq
```

### BOSH CLI

Download the latest [`bosh-cli` release](https://github.com/cloudfoundry/bosh-cli/releases) and move it to you `$PATH`.

```bash
sudo install ~/Downloads/ bosh-cli-x.x.x-linux-amd64 /usr/local/bin/bosh
```

### CF CLI

Install the latest [`cf-cli`](https://docs.cloudfoundry.org/cf-cli/install-go-cli.html).

```bash
wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list

sudo apt-get update

sudo apt-get install cf8-cli
```

### Credhub

Download the latest [`credhub` release](https://github.com/cloudfoundry/credhub-cli/releases), extract and move it to
your `$PATH`.

```bash
tar zxvf ~/Downalods/credhub-linux-amd64-2.9.24.tgz
sudo install ~/Downloads/credhub /usr/local/bin/credhub
``` 

### Virtualbox

Download the latest [`Virtualbox`](https://www.virtualbox.org/wiki/Linux_Downloads) and install it.
Don't forget to install the [extension pack](https://www.virtualbox.org/wiki/Downloads).

```bash
sudo apt install virtualbox virtualbox-dkms virtualbox-ext-pack
```

### Ruby

You can install ruby with [rbenv](https://github.com/rbenv/rbenv).

```bash
sudo apt install rbenv
rbenv init

rbenv install 3.1.6
```

### cf-uaac or uaa

In order to use `./scripts/add-cf-admin.sh`, you need to install [`cf-uaac`](https://github.com/cloudfoundry/cf-uaac)
or [`uaa-cli`](https://github.com/cloudfoundry/uaa-cli)

#### cf-uaac

```bash
sudo gem install cf-uaac
```

#### uaa-cli

Download the latest [`uaa-cli` release](https://github.com/cloudfoundry/uaa-cli/releases), extract and move it to your
`$PATH`.

```bash
sudo install ~/Downloads/uaa-linux-amd64-0.14.0 /usr/local/bin/uaa
```

## Create deployment

### Full deployment (BOSH and Cloud Foundry)

To create the BOSH and Cloud Foundry deployment, run the following command:

```bash
$ ./scripts/create-env.sh
```

This will :

- deploy BOSH on Virtualbox using bridged network as outbond network.
- deploy BOSH with custom password for vcap user `admin`.
- deploy Cloud Foundry on BOSH with the system domain `bosh-lite.com`.
- create a directory `deployments` containing:
    * `bosh.yml`: BOSH manifest
    * `cf.yml`: Cloud Foundry manifest
    * `creds.yml`: credentials for BOSH and Cloud Foundry
    * `jumpbox.key`: SSH private key for the jumpbox
    * `state.json`: BOSH state
    * `.envrc`: environment variables for bosh cli

By default, the script will create a `hostonly` network as followed:

- gateway: `192.168.56.1`
- cidr: `192.168.56.0/24`
- jumpbox ip: `192.168.56.6`

This can be changed in the `bosh/vars/vars.yml` file.

You can also change the vcap user's password in the `bosh/vars/vars.yml` file.

```bash
# use mkpasswd to generate a password hash
mkpasswd -s -m sha-512
Password: REDACTED
$6$p95sDVpIlrzGf0kl$1KP37eS4Jj9nWM/IsS.BcBaMVUO4Arf.Zl8JDRTnpFzqK88h9WSY6qT/dwmr4urjNNKB/2poiuCD6DM7H47WR0
```

### BOSH deployment only

To deploy bosh only, run the following command:

```bash
$ ./scripts/deploy-bosh.sh
```

This will :

- deploy BOSH on Virtualbox using bridged network as outbond network.
- deploy BOSH with custom password for vcap user `admin`.
- create a directory `deployments` containing:
    * `bosh.yml`: BOSH manifest
    * `creds.yml`: credentials for BOSH
    * `jumpbox.key`: SSH private key for the jumpbox
    * `state.json`: BOSH state
    * `.envrc`: environment variables for bosh cli

By default, the script will create a `hostonly` network as followed:

- gateway: `192.168.56.1`
- cidr: `192.168.56.0/24`
- jumpbox ip: `192.168.56.6`

This can be changed in the `bosh/vars/vars.yml` file.

You can also change the vcap user's password in the `bosh/vars/vars.yml` file.

```bash
# use mkpasswd to generate a password hash
mkpasswd -s -m sha-512
Password: REDACTED
$6$p95sDVpIlrzGf0kl$1KP37eS4Jj9nWM/IsS.BcBaMVUO4Arf.Zl8JDRTnpFzqK88h9WSY6qT/dwmr4urjNNKB/2poiuCD6DM7H47WR0
```

### Cloud Foundry deployment only

To deploy Cloud Foundry on an existing BOSH, run the following command:

```bash
$ ./scripts/deploy-cf.sh
```

This will :

- deploy Cloud Foundry on BOSH with the system domain `bosh-lite.com`.

## Stop and resume deployment

* To stop the deployment, run the following command:
    ```bash
    ./scripts/bosh-vm.sh pause
    ```
  This wil save the state of the bosh vm and stop it.

* To resume the deployment, run the following command:
    ```bash
    ./scripts/bosh-vm.sh resume
    ```

## Create an admin account

### Using [`cf-uaac`](https://github.com/cloudfoundry/cf-uaac)

#### `cf-uaac` client installation

```bash
sudo gem install cf-uaac
```

#### Add an account

```bash
source "./deployments/.envrc"
credhub api --server api.bosh-lite.com --skip-tls-validation
uaac target https://uaa.bosh-lite.com --skip-ssl-validation
uaac token client get admin -s "$(credhub g -n "/${bosh_deployment_name}/cf/uaa_admin_client_secret" --output-json | jq .value -r)"
uaac user add "${ACCOUNT_NAME}" -p "${ACCOUNT_PASSWORD}" --emails "${ACCOUNT_EMAIL}"
for group in cloud_controller.admin clients.read clients.secret clients.write uaa.admin scim.write scim.read; do
  uaac member add "${group}" "${ACCOUNT_NAME}"
done
```

You can use the `./scripts/add-cf-admin.sh <account_name> <account_email>` script to add an account.

### Using [`uaa-cli`](https://github.com/cloudfoundry/uaa-cli)

#### `uaa-cli` client installation

Download the latest [`uaa-cli` release](https://github.com/cloudfoundry/uaa-cli/releases), extract and move it to your
`$PATH`.

```bash
sudo install ~/Downloads/uaa-linux-amd64-0.14.0 /usr/local/bin/uaa
```

#### Add an account

```bash
source "./deployments/.envrc"
credhub api --server api.bosh-lite.com --skip-tls-validation
uaac target https://uaa.bosh-lite.com --skip-ssl-validation
uaa get-client-credentials-token admin -s "$(credhub g -n "/${bosh_deployment_name}/cf/uaa_admin_client_secret" --output-json | jq .value -r)"
uaa create-user "${ACCOUNT_NAME}" --email "${ACCOUNT_EMAIL}" --password "${ACCOUNT_PASSWORD}"
for group in cloud_controller.admin clients.read clients.secret clients.write uaa.admin scim.write scim.read; do
  uaa add-member "${group}" "${ACCOUNT_NAME}"
done
```

You can use the `./scripts/add-cf-admin.sh <account_name> <account_email>` script to add an account.

# Demo applications

The `applications` directory includes a few demo applications.

## PHP

This is a simple PHP application using `php_buildpack`.

```bash
# deploy
cd applications/demo-php

# connect to cloud foundry api
cf login -a api.bosh-lite.com --skip-ssl-validation -u $ACCOUNT_NAME -p $ACCOUNT_PASSWORD
cf target -o system
# create space if not exists
cf create-space demo
cf target -s demo

# push the application
cf push

# access through the route
curl -k https://demo-php.bosh-lite.com/
```

## Binary

This is a simple binary application using `binary_builpack`.

```bash
# deploy
cd applications/demo-binary

# connect to cloud foundry api
cf login -a api.bosh-lite.com --skip-ssl-validation -u admin -p REDACTED
cf target -o system
# create space if not exists
cf create-space demo
cf target -s demo

# push the application
cf push

# access through the route
curl -k https://demo-binary.bosh-lite.com/
```
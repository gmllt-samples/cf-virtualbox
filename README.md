# gmllt/paas

## Description

This is a simple Bosh and Cloud Foundry deployment for Virtualbox 7.

## Requirements

### Git

Make sure Git is installed on your system.

```bash
sudo apt-get install git
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

Download the latest [`credhub` release](https://github.com/cloudfoundry/credhub-cli/releases), extract and move it to your `$PATH`.

```bash
tar zxvf ~/Downalods/credhub-linux-amd64-2.9.24.tgz
sudo install ~/Downloads/credhub /usr/local/bin/credhub
``` 

### Virtualbox

Download the latest [`Virtualbox`](https://www.virtualbox.org/wiki/Linux_Downloads) and install it.
Don't forget to install the [extension pack](https://www.virtualbox.org/wiki/Downloads).

```bash
sudo apt-get install ~/Downloads/virtualbox-7.0_7.0.12-159484~Ubuntu~jammy_amd64.deb
```

## Create deployment

To create the BOSH and Cloud Foundry deployment, run the following command:

```bash
./scripts/create-env.sh
```

This will :
- deploy BOSH on Virtualbox using bridged network as outbond network.
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
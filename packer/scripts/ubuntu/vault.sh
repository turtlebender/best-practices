#!/bin/bash
set -e

cd /tmp

CONFIGDIR=/ops/$1
SCRIPTSDIR=/ops/$2
VAULTDOWNLOAD=https://releases.hashicorp.com/vault/0.3.1/vault_0.3.1_linux_amd64.zip
VAULTCONFIGDIR=/etc/vault.d
VAULTDIR=/opt/vault
VAULTPOLICIES=$VAULTDIR/policies

echo Fetching Vault...
curl -L $VAULTDOWNLOAD > vault.zip

echo Installing Vault...
unzip vault.zip -d /usr/local/bin
chmod 0755 /usr/local/bin/vault
chown root:root /usr/local/bin/vault

echo Creating Vault configuration...
mkdir -p $VAULTCONFIGDIR
chmod 755 $VAULTCONFIGDIR
mkdir -p $VAULTPOLICIES
chmod 755 $VAULTPOLICIES

# Consul config
cp $CONFIGDIR/consul/vault.json /etc/consul.d/vault.json

# Vault config
cp $CONFIGDIR/vault/vault.hcl $VAULTCONFIGDIR/vault.hcl

# Vault Setup & Policy
cp $SCRIPTSDIR/vault_setup.sh $VAULTDIR/setup.sh
cp $SCRIPTSDIR/vault_policy.sh $VAULTDIR/policy.sh
cp $CONFIGDIR/vault/policies/nodejs.hcl $VAULTPOLICIES/nodejs.hcl

# Upstart config
cp $SCRIPTSDIR/upstart/vault.conf /etc/init/vault.conf

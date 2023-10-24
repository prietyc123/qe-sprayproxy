# Sprayproxy Deployment

This doc is to guide you how to use the scripts to deploy Spray Proxy on a permanent QE cluster, which is used to distribute requests sent from GH App to targeted test clusters

## Prerequisites

* Make sure you have permissions to manage [RHTAP QE Github App](https://github.com/organizations/redhat-appstudio-qe/settings/apps/rhtap-qe-app)

* Make sure you have write permissions for https://vault.ci.openshift.org/ui/vault/secrets/kv/show/selfservice/redhat-appstudio-qe/ci-secrets

* Installing [vault](https://developer.hashicorp.com/vault/docs/install) cli

## Login to vault server 

You first need to login to vault server by performing the following commands before you execute `main.sh` script

```
$ export VAULT_ADDR=https://vault.ci.openshift.org
$ vault login -method=oidc
```

## Deploy Sprayproxy on OCP cluster

```
$ ./main.sh deploy
```

## Update Webhook URL in Github App and secrets in Vault

```
$ ./main.sh setup
```
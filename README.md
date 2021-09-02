# tfc-vault-aci
Host Hashicorp Vault on Azure Container Instances using Terraform Cloud

## Login and select subscription
az login<br/>
az account list<br/>
az account set --subscription="SUBSCRIPTION_ID"<br/>
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID"<br/>

## Set Terraform env variables
ARM_SUBSCRIPTION_ID = "SUBSCRIPTION_ID"<br/>
ARM_CLIENT_ID = "appId"<br/>
ARM_CLIENT_SECRET = "password"<br/>
ARM_TENANT_ID = "tenant"<br/>

## Launch the container using the Terraform output

## Set the environment variables using the Terraform output

## Verify Vault connectivity
vault status<br/>

## If this is the first launch, initialize the Vault
vault operator init -recovery-shares=1 -recovery-threshold=1<br/>
Recovery Key 1: <br/>

Initial Root Token: <br/>
vault operator unseal <br/>

## Make note of the Recovery Key and Root Token

vault login<br/>

vault secrets enable kv<br/>

vault kv put kv-v2/tacos meat=chicken<br/>

vault kv get kv-v2/tacos<br/>

## Delete the container using the Terraform output when you're done
# tfc-vault-aci
Host Hashicorp Vault on Azure Container Instances using Terraform Cloud

## Login and select subscription
az login<br/>
az account set -s<br/>

## Deploy Terraform stuff
terraform init<br/>
terraform apply -auto-approve<br/>

## Update the storage account name from the Terraform output
sa_name=STORAGE_ACCOUNT_NAME<br>

az storage file upload --account-name sa_name --share-name vault-data --source vault-config.hcl<br/>
az storage file upload --account-name sa_name --share-name vault-data --source vault-cert.crt --path certs<br/>
az storage file upload --account-name sa_name --share-name vault-data --source vault-cert.key --path certs<br/>

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

## Delete the files in the cert directory if you plan to delete everything
az storage file delete --account-name $sa_name --share-name vault-data --path certs/vault-cert.crt<br/>
az storage file delete --account-name $sa_name --share-name vault-data --path certs/vault-cert.key<br/>

## Destroy the terraform resources
terraform destroy -auto-approve<br/>
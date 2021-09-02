terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.0"
    }
  }
}

##########################################################################
# VARIABLES
##########################################################################

variable "prefix" {
  type    = string
  default = "manoj"
}

variable "location" {
  type    = string
  default = "southcentralus"
}

##########################################################################
# PROVIDER
##########################################################################

provider "azurerm" {
  features {}
}

##########################################################################
# DATA SOURCES and LOCALs
##########################################################################

locals {
  vault_name           = "dev${var.prefix}vault"
  resource_group_name  = "${var.prefix}HashicorpRG"
  storage_account_name = "dev${var.prefix}sa"
  key_vault_name       = "dev${var.prefix}keyvault"
  user_identity_name   = "dev${var.prefix}vaultidentity"
}

data "azurerm_client_config" "current" {}

##########################################################################
# RESOURCES
##########################################################################

# Create a self-signed cert

resource "tls_private_key" "private" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "cert" {
  key_algorithm   = tls_private_key.private.algorithm
  private_key_pem = tls_private_key.private.private_key_pem

  validity_period_hours = 87600

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["${local.vault_name}.${var.location}.azurecontainer.io"]

  subject {
    common_name  = "${local.vault_name}.${var.location}.azurecontainer.io"
    organization = "Manoj, Inc"
  }
}

resource "local_file" "key" {
  content  = tls_private_key.private.private_key_pem
  filename = "${path.module}/vault-cert.key"
}

resource "local_file" "cert" {
  content  = tls_self_signed_cert.cert.cert_pem
  filename = "${path.module}/vault-cert.crt"
}

# Resource group

resource "azurerm_resource_group" "vault" {
  name     = local.resource_group_name
  location = var.location
}

# Storage account for persistence

resource "azurerm_storage_account" "vault" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.vault.name
  location                 = azurerm_resource_group.vault.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

# Storage account share

resource "azurerm_storage_share" "vault" {
  name                 = "vault-data"
  storage_account_name = azurerm_storage_account.vault.name
  quota                = 50

}

# Storage account directory

resource "azurerm_storage_share_directory" "vault" {
  name                 = "certs"
  share_name           = azurerm_storage_share.vault.name
  storage_account_name = azurerm_storage_account.vault.name
}

# Upload files
resource "azurerm_storage_share_file" "vault_config_file" {
  name             = "vault-config.hcl"
  storage_share_id = azurerm_storage_share.vault.id
  source           = "vault-config.hcl"
}

resource "azurerm_storage_share_file" "vault_cert_crt" {
  name             = "vault-cert.crt"
  storage_share_id = azurerm_storage_share.vault.id
  source           = "vault-cert.crt"
  path             = azurerm_storage_share_directory.vault.name
}

resource "azurerm_storage_share_file" "vault_cert_key" {
  name             = "vault-cert.key"
  storage_share_id = azurerm_storage_share.vault.id
  source           = "vault-cert.key"
  path             = azurerm_storage_share_directory.vault.name
}
# User Identity

resource "azurerm_user_assigned_identity" "vault" {
  resource_group_name = azurerm_resource_group.vault.name
  location            = azurerm_resource_group.vault.location

  name = local.user_identity_name
}

# Key Vault

resource "azurerm_key_vault" "vault" {
  name                       = local.key_vault_name
  location                   = azurerm_resource_group.vault.location
  resource_group_name        = azurerm_resource_group.vault.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.vault.principal_id

    key_permissions = [
      "get", "list", "create", "delete", "update", "wrapKey", "unwrapKey", "purge"
    ]

  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "get", "list", "create", "delete", "update", "wrapKey", "unwrapKey", "purge"
    ]

  }

}

resource "azurerm_key_vault_key" "vault-key" {
  name         = "vault-key"
  key_vault_id = azurerm_key_vault.vault.id
  key_type     = "RSA"
  key_size     = 4096

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

##########################################################################
# OUTPUTS
##########################################################################

# Command to create container instance

output "container_create" {
  value = <<EOF
az container create \
  --name manojvaultaci1 --image vault:1.5.3 \
  --command-line 'vault server -config /vault/vault-config.hcl' \
  --dns-name-label manojvaultaci1 --ports 8200 \
  --azure-file-volume-account-name manojsa11 \
  --azure-file-volume-share-name vault-data \
  --azure-file-volume-mount-path /vault \
  --environment-variables AZURE_TENANT_ID=${data.azurerm_client_config.current.tenant_id} \
  VAULT_AZUREKEYVAULT_VAULT_NAME=manojkeyvault1 \
  VAULT_AZUREKEYVAULT_KEY_NAME=vault-key 
EOF
}

output "user_assigned_identity" {
  value = <<EOF
  --assign-identity ${azurerm_user_assigned_identity.vault.id} \
EOF
}

# Environment variables to set
output "environment_variables" {
  value = <<EOF
export VAULT_ADDR="https://${local.vault_name}.${var.location}.azurecontainer.io:8200"
export VAULT_SKIP_VERIFY=true
EOF
}

output "storage_accountName" {
  value = local.storage_account_name
}

output "container_delete" {
  value = "az container delete --resource-group ${azurerm_resource_group.vault.name} --name ${local.vault_name}"
}
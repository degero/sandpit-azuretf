variable "name" {
  description = "Name of the storage account."
  type        = string

}

variable "parent_id" {
  description = "Name of the resource group."
  type        = string
}


variable "tenant_id" {
  description = "Name of the tenant."
  type        = string
}

variable "location" {
  description = "Azure region for the storage account."
  type        = string
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}

terraform {
  required_providers {
    azapi   = { source = "Azure/azapi" }
    modtm   = { source = "Azure/modtm" }
    azurerm = { source = "hashicorp/azurerm" }
  }
}

module "this" {
  # version "0.13.1"
  source = "github.com/Azure/terraform-azurerm-avm-res-keyvault-vault?ref=eaad6bb43678dc74edf03c1dad5c60246760aa45"

  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  tenant_id = var.tenant_id

  tags = var.tags
}

output "resource_id" {
  description = "Resource ID of the storage account."
  value       = module.this.resource_id
}

output "name" {
  description = "Name of the storage account."
  value       = module.this.name
}

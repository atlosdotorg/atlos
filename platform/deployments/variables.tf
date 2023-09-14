variable "region" {
  description = "Azure infrastructure region"
  type    = string
  default = "East US 2"
}

variable "app" {
  description = "Application name"
  type    = string
  default = "platform"
}

variable "env" {
  description = "Application env"
  type    = string
  default = "staging"
}

variable "location" {
  description = "Location short name"
  type    = string
  default = "eastus2"
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type = string # The Azure Tenant ID
}

variable "region" {
  description = "Azure infrastructure region"
  type        = string
  default     = "East US 2"
}

variable "app" {
  description = "Application name"
  type        = string
  default     = "platform"
}

variable "env" {
  description = "Application env"
  type        = string
  default     = "staging"
}

variable "location" {
  description = "Location short name"
  type        = string
  default     = "eastus2"
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string # The Azure Tenant ID
}

variable "appsignal_push_api_key" {
  description = "AppSignal Push API Key"
  type        = string
}

variable "hcaptcha_site_key" {
  description = "hCaptcha Site Key"
  type        = string
}

variable "hcaptcha_secret" {
  description = "hCaptcha Secret"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
}

variable "spn_archive_api_key" {
  description = "Save Page Now Archive API Key"
  type        = string
}

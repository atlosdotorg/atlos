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
  sensitive = true
}

variable "appsignal_push_api_key" {
  description = "AppSignal Push API Key"
  type        = string
  sensitive   = true
}

variable "hcaptcha_site_key" {
  description = "hCaptcha Site Key"
  type        = string
  sensitive   = true
}

variable "hcaptcha_secret" {
  description = "hCaptcha Secret"
  type        = string
  sensitive   = true
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "spn_archive_api_key" {
  description = "Save Page Now Archive API Key"
  type        = string
  sensitive   = true
}

variable "database_sku" {
  description = "Database SKU"
  type        = string
  default     = "GP_Standard_D2ads_v5"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
}

variable "s3_bucket" {
  description = "S3 Bucket"
  type        = string
}

variable "instance_name" {
  description = "Instance name"
  type        = string
  default     = "staging"
}

variable "onboarding_project_id" {
  description = "Onboarding project ID"
  type        = string
  default     = "deb6c474-34f1-47ab-a3b5-3928548178c3"
}

variable "host" {
  description = "Host"
  type        = string
  default     = "staging-v2.atlos.org"
}

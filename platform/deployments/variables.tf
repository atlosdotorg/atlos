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
  sensitive   = true
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

variable "platform_aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "platform_aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "spn_archive_api_key" {
  description = "Save Page Now Archive API Key"
  type        = string
  sensitive   = true
}

variable "highlight_code" {
  description = "Highlight API code"
  type        = string
  default     = ""
}

variable "database_sku" {
  description = "Database SKU"
  type        = string
  default     = "GP_Standard_D2ads_v5"
}

variable "platform_aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-2"
}

variable "platform_content_s3_bucket" {
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

variable "backup_age_recipients" {
  description = "AGE recipients for encrypted database backups; comma separated"
  type        = string
  default     = ""
}

variable "backup_object_prefix" {
  description = "Object prefix for encrypted database backups"
  type        = string
  default     = "atlos-backup"
}

variable "backup_cron_schedule" {
  description = "Cron schedule for encrypted database backups"
  type        = string
  default     = "0 */6 * * *" // every 6 hours
}

variable "backup_s3_bucket" {
  description = "S3 bucket for encrypted database backups"
  type        = string
}

variable "backup_healthcheck_endpoint" {
  description = "Healthcheck endpoint for encrypted database backups"
  type        = string
}

variable "backup_generator_aws_access_key_id" {
  description = "AWS Access Key ID for backup generator"
  type        = string
  sensitive   = true
}

variable "backup_generator_aws_secret_access_key" {
  description = "AWS Secret Access Key for backup generator"
  type        = string
  sensitive   = true
}

variable "backup_skip_databases" {
  description = "Databases to skip for encrypted database backups; comma separated"
  type        = string
  default     = "postgres,azure_sys,azure_maintenance"
}

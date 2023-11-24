resource "azurerm_subnet" "backup_generator_subnet" {
  name                 = "bg-subnet-${local.stack}"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.136.0/23"]
}

resource "azurerm_container_app_environment" "backup_generator" {
  name                       = "backup-generator-environment-${local.stack}"
  location                   = azurerm_resource_group.platform.location
  resource_group_name        = azurerm_resource_group.platform.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id
  infrastructure_subnet_id   = azurerm_subnet.backup_generator_subnet.id

  tags = local.default_tags
}

resource "azurerm_container_app" "backup_generator" {
  name = "bg-${local.stack}"

  container_app_environment_id = azurerm_container_app_environment.platform.id
  resource_group_name          = azurerm_resource_group.platform.name
  revision_mode                = "Single"

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name  = "postback"
      image = "ghcr.io/milesmcc/postback:v0.0.9"

      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "AWS_ACCESS_KEY_ID"
        secret_name = "aws-access-key-id"
      }

      env {
        name        = "AWS_SECRET_ACCESS_KEY"
        secret_name = "aws-secret-access-key"
      }

      env {
        name        = "PG_URL"
        secret_name = "database-url"
      }

      env {
        name  = "S3_BUCKET"
        value = var.backup_s3_bucket
      }

      env {
        name = "AGE_RECIPIENTS"
        value = var.backup_age_recipients
      }

      env {
        name = "OBJECT_PREFIX"
        value = var.backup_object_prefix
      }

      env {
        name = "CRON_SCHEDULE"
        value = var.backup_cron_schedule
      }

      env {
        name = "HEALTHCHECK_ENDPOINT"
        value = var.backup_healthcheck_endpoint
      }

      env {
        name = "SKIP_DATABASES"
        value = var.backup_skip_databases
      }
    }
  }

  secret {
    name  = "aws-access-key-id"
    value = var.backup_generator_aws_access_key_id
  }

  secret {
    name  = "aws-secret-access-key"
    value = var.backup_generator_aws_secret_access_key
  }

  secret {
    name  = "database-url"
    value = "postgresql://platform:${random_password.postgres_admin_password.result}@${azurerm_postgresql_flexible_server.platform_database.fqdn}/${azurerm_postgresql_flexible_server_database.platform_database.name}"
  }

  tags = local.default_tags
}

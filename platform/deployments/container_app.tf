resource "random_password" "cookie_signing_salt" {
  length  = 64
  special = true
}

resource "random_password" "cluster_secret" {
  length  = 64
  special = true
}

resource "random_password" "secret_key_base" {
  length  = 64
  special = true
}

resource "azurerm_subnet" "container_app_subnet" {
  name                 = "ca-subnet-${local.stack}"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.128.0/21"]
}

resource "azurerm_container_app_environment_certificate" "origin_certificate" {
  name                         = "origin-certificate-${local.stack}"
  container_app_environment_id = azurerm_container_app_environment.platform.id
  certificate_blob_base64      = base64encode(var.origin_certificate)
  certificate_password         = ""
}

resource "azurerm_container_app_environment" "platform" {
  name                       = "ca-environment-main-${local.stack}"
  location                   = azurerm_resource_group.platform.location
  resource_group_name        = azurerm_resource_group.platform.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id
  infrastructure_subnet_id   = azurerm_subnet.container_app_subnet.id

  tags = local.default_tags
}

resource "azurerm_container_app" "platform" {
  name = "ca-main-${local.stack}"

  container_app_environment_id = azurerm_container_app_environment.platform.id
  resource_group_name          = azurerm_resource_group.platform.name
  revision_mode                = "Single"

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 4000
    transport                  = "http"

    custom_domain {
      name           = var.host
      certificate_id = azurerm_container_app_environment_certificate.origin_certificate.id
    }

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  timeouts {
    create = "2h"
    update = "2h"
    delete = "2h"
  }

  template {
    min_replicas = 1
    max_replicas = 5

    container {
      name  = "platform"
      image = "ghcr.io/atlosdotorg/atlos:main"

      cpu    = 1.0
      memory = "2Gi"

      liveness_probe {
        path      = "/health_check/exp"
        port      = 4000
        transport = "HTTP"

        initial_delay           = 30
        interval_seconds        = 10
        failure_count_threshold = 3
      }

      readiness_probe {
        path      = "/health_check"
        port      = 4000
        transport = "HTTP"

        interval_seconds        = 10
        failure_count_threshold = 3
      }

      env {
        name        = "AZURE_POSTGRESQL_HOST"
        secret_name = "azure-postgresql-host"
      }

      env {
        name  = "AZURE_POSTGRESQL_SSL"
        value = "true"
      }

      env {
        name  = "ENVIRONMENT"
        value = var.env
      }

      env {
        name  = "INSTANCE_NAME"
        value = var.instance_name
      }

      env {
        name  = "LANG"
        value = "en_US.UTF-8"
      }

      env {
        name  = "MIX_ENV"
        value = "prod"
      }

      env {
        name  = "ONBOARDING_PROJECT_ID"
        value = var.onboarding_project_id
      }

      env {
        name  = "PHX_HOST"
        value = var.host
      }

      env {
        name  = "ENABLE_CAPTCHAS"
        value = "true"
      }

      env {
        name        = "APPSIGNAL_PUSH_API_KEY"
        secret_name = "appsignal-push-api-key"
      }

      env {
        name        = "HCAPTCHA_SITE_KEY"
        secret_name = "hcaptcha-site-key"
      }

      env {
        name        = "COOKIE_SIGNING_SALT"
        secret_name = "cookie-signing-salt"
      }

      env {
        name        = "HCAPTCHA_SECRET"
        secret_name = "hcaptcha-secret"
      }

      env {
        name        = "AWS_ACCESS_KEY_ID"
        secret_name = "aws-access-key-id"
      }

      env {
        name        = "AWS_SECRET_ACCESS_KEY"
        secret_name = "aws-secret-access-key"
      }

      env {
        name        = "CLUSTER_SECRET"
        secret_name = "cluster-secret"
      }

      env {
        name  = "APPSIGNAL_APP_ENV"
        value = var.env
      }

      env {
        name        = "SECRET_KEY_BASE"
        secret_name = "secret-key-base"
      }

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }

      env {
        name  = "S3_BUCKET"
        value = var.platform_content_s3_bucket
      }

      env {
        name  = "AWS_REGION"
        value = var.platform_aws_region
      }

      env {
        name  = "PHX_HOST"
        value = var.host
      }

      env {
        name        = "SPN_ARCHIVE_API_KEY"
        secret_name = "spn-archive-api-key"
      }

      env {
        name  = "HIGHLIGHT_CODE"
        value = var.highlight_code
      }
    }
  }

  secret {
    name  = "azure-postgresql-host"
    value = azurerm_postgresql_flexible_server.platform_database.fqdn
  }

  secret {
    name  = "appsignal-push-api-key"
    value = var.appsignal_push_api_key
  }

  secret {
    name  = "hcaptcha-site-key"
    value = var.hcaptcha_site_key
  }

  secret {
    name  = "cookie-signing-salt"
    value = random_password.cookie_signing_salt.result
  }

  secret {
    name  = "hcaptcha-secret"
    value = var.hcaptcha_secret
  }

  secret {
    name  = "aws-access-key-id"
    value = var.platform_aws_access_key_id
  }

  secret {
    name  = "aws-secret-access-key"
    value = var.platform_aws_secret_access_key
  }

  secret {
    name  = "cluster-secret"
    value = random_password.cluster_secret.result
  }

  secret {
    name  = "spn-archive-api-key"
    value = var.spn_archive_api_key
  }

  secret {
    name  = "secret-key-base"
    value = random_password.secret_key_base.result
  }

  secret {
    name  = "database-url"
    value = "postgresql://platform:${random_password.postgres_admin_password.result}@${azurerm_postgresql_flexible_server.platform_database.fqdn}/${azurerm_postgresql_flexible_server_database.platform_database.name}"
  }

  tags = local.default_tags
}

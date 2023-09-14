resource "random_string" "cookie_signing_salt" {
  length  = 64
  special = true
}

resource "random_string" "cluster_secret" {
  length  = 64
  special = true
}

resource "random_string" "secret_key_base" {
  length  = 64
  special = true
}

resource "azurerm_app_service_connection" "platform_db_connector" {
  name               = "platform-db-connector-${local.stack}"
  app_service_id     = azurerm_container_app.platform.id
  target_resource_id = azurerm_postgresql_database.platform_database.id

  authentication {
    type = "systemAssignedIdentity"
  }
}

resource "azurerm_container_app_environment" "platform" {
  name                       = "container-app-environment-${local.stack}"
  location                   = azurerm_resource_group.platform.location
  resource_group_name        = azurerm_resource_group.platform.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  tags = local.default_tags
}

resource "azurerm_container_app" "platform" {
  name = "container-app-platform-${local.stack}"

  container_app_environment_id = azurerm_container_app_environment.platform.id
  resource_group_name          = azurerm_resource_group.platform.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  registry {
    server = "ghcr.io"
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 4000
    session_affinity_enabled   = true
    transport                  = "http"

    traffic_weight {
      percentage = 100
    }
  }

  template {
    container {
      name   = "platform"
      image  = "ghcr.io/atlosdotorg/atlos:main"
      cpu    = 1
      memory = "2Gi"

      liveness_probe {
        http_get {
          path = "/health_check/exp"
          port = 4000
        }

        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        success_threshold     = 1
        failure_threshold     = 3
      }

      readiness_probe {
        http_get {
          path = "/health_check"
          port = 4000
        }

        initial_delay_seconds = 30
        period_seconds        = 10
        timeout_seconds       = 5
        success_threshold     = 1
        failure_threshold     = 3
      }

      env {
        name        = "AZURE_POSTGRESQL_HOST"
        secret_name = "azure-postgresql-host"
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
        name  = "AZURE_POSTGRESQL_DATABASE"
        value = azurerm_postgresql_database.platform_database.name
      }
    }
  }

  secret {
    name  = "azure-postgresql-host"
    value = azurerm_postgresql_flexible_server.platform_database.fully_qualified_domain_name
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
    value = random_string.cookie_signing_salt.result
  }

  secret {
    name  = "hcaptcha-secret"
    value = var.hcaptcha_secret
  }

  secret {
    name  = "aws-access-key-id"
    value = var.aws_access_key_id
  }

  secret {
    name  = "aws-secret-access-key"
    value = var.aws_secret_access_key
  }

  secret {
    name  = "cluster-secret"
    value = random_string.cluster_secret.result
  }

  secret {
    name  = "spn-archive-api-key"
    value = var.spn_archive_api_key
  }

  secret {
    name  = "secret-key-base"
    value = random_string.secret_key_base.result
  }

  tags = local.default_tags
}
resource "azurerm_user_assigned_identity" "container_app" {
  location            = azurerm_resource_group.rg.location
  name                = "container-app-uai-${local.stack}"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "container_app_registry" {
  scope                = azurerm_container_app_environment.platform.id
  role_definition_name = "acrpull"
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
  depends_on = [
    azurerm_user_assigned_identity.container_app
  ]
}

resource "azurerm_role_assignment" "container_app_database" {
  scope                = azurerm_postgresql_flexible_server.platform_database.id
  principal_id         = azurerm_user_assigned_identity.container_app.principal_id
  depends_on = [
    azurerm_user_assigned_identity.container_app
  ]
}

resource "azurerm_container_app_environment" "platform" {
  name                      = "container-app-environment-${local.stack}"
  location                   = azurerm_resource_group.platform.location
  resource_group_name        = azurerm_resource_group.platform.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  tags = local.default_tags
}

resource "azurerm_container_app" "platform" {
  name                         = "container-app-platform-${local.stack}"

  container_app_environment_id = azurerm_container_app_environment.platform.id
  resource_group_name          = azurerm_resource_group.platform.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_app.id]
  }

  registry {
    server               = azurerm_container_registry.acr.login_server
    identity = azurerm_user_assigned_identity.container_app.id
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 4000
    session_affinity_enabled   = true
    transport = "http"

    traffic_weight {
      percentage = 100
    }
  }

  template {
    container {
      name   = azurerm_container_registry.acr.name
      image  = "platform/platform"
      cpu    = 0.25
      memory = "0.5Gi"
    }
  }
  
  tags = local.default_tags
}
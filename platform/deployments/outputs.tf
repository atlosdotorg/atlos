output "azurerm_container_app_url" {
  value = azurerm_container_app.platform.latest_revision_fqdn
}

output "azurerm_container_registry_name" {
  value = azurerm_container_registry.acr.name
}

output "azurerm_container_registry_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "azurerm_container_registry_admin_username" {
  value = azurerm_container_registry.acr.admin_username
}

output "azurerm_container_registry_admin_password" {
  value = azurerm_container_registry.acr.admin_password
}

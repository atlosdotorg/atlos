output "azurerm_container_app_url" {
  value = azurerm_container_app.platform.latest_revision_fqdn
}

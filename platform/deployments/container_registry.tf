resource "azurerm_container_registry" "acr" {
  name                = "container-registry-${var.app}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  sku                 = "Standard"
  admin_enabled       = true

  retention_policy {
    enabled = true
    days    = 7
  }
}
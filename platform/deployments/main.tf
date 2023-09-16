locals {
  stack = "${var.app}-${var.env}-${var.location}"

  default_tags = {
    environment = var.env
    app         = var.app
  }
}

# Resource group
resource "azurerm_resource_group" "platform" {
  name     = "rg-${local.stack}"
  location = "East US 2"
}

resource "azurerm_resource_group" "core" {
  name     = "core"
  location = "East US 2"
}

# Log analytics with 90 day retention
resource "azurerm_log_analytics_workspace" "platform" {
  name                = "log-${local.stack}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.default_tags
}

# Internal network (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "platform-vnet-${local.stack}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.default_tags
}

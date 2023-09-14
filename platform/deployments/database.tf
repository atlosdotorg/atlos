resource "azurerm_subnet" "postgres_storage_subnet" {
  name                 = "storage-${local.stack}"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  tags = local.default_tags

  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_private_dns_zone" "database_zone" {
  name                = "${local.stack}-platform-database.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.default_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "database_zone_link" {
  name                  = "database-zone-link-${local.stack}"
  private_dns_zone_name = azurerm_private_dns_zone.database_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.platform.name
  tags                  = local.default_tags
}

resource "azurerm_postgresql_flexible_server" "platform_database" {
  name                         = "platform-psqlflexibleserver-${local.stack}"
  resource_group_name          = azurerm_resource_group.platform.name
  location                     = azurerm_resource_group.platform.location
  version                      = "15"
  delegated_subnet_id          = azurerm_subnet.postgres_storage_subnet.id
  private_dns_zone_id          = azurerm_private_dns_zone.database_zone.id
  storage_mb                   = 32768
  auto_grow_enabled            = true
  backup_retention_days        = 35
  geo_redundant_backup_enabled = true
  sku_name                     = "GP_Standard_D2ds_v4"
  depends_on                   = [azurerm_private_dns_zone_virtual_network_link.database_zone_link]

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = var.tenant_id
  }

  tags = local.default_tags
}

resource "azurerm_postgresql_database" "platform_database" {
  name                = "platform-${var.env}"
  resource_group_name = azurerm_resource_group.platform.name
  server_name         = azurerm_postgresql_flexible_server.platform_database.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
  depends_on          = [azurerm_postgresql_flexible_server.platform_database]
}

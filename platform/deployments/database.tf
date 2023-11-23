resource "azurerm_subnet" "postgres_storage_subnet" {
  name                 = "pg-subnet-${local.stack}"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

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

resource "random_password" "postgres_admin_password" {
  length  = 64
  special = false
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
  zone                         = 2
  storage_mb                   = 32768
  auto_grow_enabled            = true
  backup_retention_days        = 35
  geo_redundant_backup_enabled = true
  sku_name                     = var.database_sku
  depends_on                   = [azurerm_private_dns_zone_virtual_network_link.database_zone_link]

  authentication {
    active_directory_auth_enabled = false
    password_auth_enabled         = true
  }

  administrator_login    = "platform"
  administrator_password = random_password.postgres_admin_password.result

  tags = local.default_tags
}

resource "azurerm_postgresql_flexible_server_configuration" "platform_database_extension_config" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.platform_database.id
  value     = "CITEXT,POSTGIS"
}

resource "azurerm_postgresql_flexible_server_database" "platform_database" {
  name       = "platform-${var.env}"
  server_id  = azurerm_postgresql_flexible_server.platform_database.id
  charset    = "utf8"
  collation  = "en_US.utf8"
  depends_on = [azurerm_postgresql_flexible_server.platform_database]
}

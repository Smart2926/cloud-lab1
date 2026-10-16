resource "azurerm_private_dns_zone" "postgres" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                 = "postgres-vnet-link"
  private_dns_zone_id  = azurerm_private_dns_zone.postgres.id
  virtual_network_id   = azurerm_virtual_network.lab.id
  registration_enabled = false
}


resource "azurerm_postgresql_flexible_server" "music" {
  name                = var.postgres_server_name
  resource_group_name = azurerm_resource_group.lab.name

  location = azurerm_virtual_network.lab.location

  version = "17"

  administrator_login    = var.db_admin_user
  administrator_password = var.db_admin_password

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  auto_grow_enabled             = false
  backup_retention_days         = 7
  public_network_access_enabled = false

  delegated_subnet_id = azurerm_subnet.postgres.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres
  ]

  tags = {
    project = "cloud-lab1"
  }

  lifecycle {
    ignore_changes = [
      zone
    ]
  }

}

resource "azurerm_postgresql_flexible_server_database" "music" {
  name      = "musicdb"
  server_id = azurerm_postgresql_flexible_server.music.id

  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "postgres_host" {
  value = azurerm_postgresql_flexible_server.music.fqdn
}

output "postgres_database" {
  value = azurerm_postgresql_flexible_server_database.music.name
}

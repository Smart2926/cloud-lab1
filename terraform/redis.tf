resource "azurerm_managed_redis" "music" {
  name                = "redis-musiclab2926-no"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_virtual_network.lab.location

  sku_name                  = "Balanced_B0"
  high_availability_enabled = false

  public_network_access = "Disabled"

  default_database {
    client_protocol                    = "Encrypted"
    clustering_policy                  = "EnterpriseCluster"
    access_keys_authentication_enabled = true
    eviction_policy                    = "AllKeysLRU"
  }

  tags = {
    project = "cloud-lab2"
    task    = "caching"
  }
}


resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.azure.net"
  resource_group_name = azurerm_resource_group.lab.name
}


resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                 = "link-music-redis"
  private_dns_zone_id  = azurerm_private_dns_zone.redis.id
  virtual_network_id   = azurerm_virtual_network.lab.id
  registration_enabled = false
}


resource "azurerm_private_endpoint" "redis" {
  name                = "pe-music-redis"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name                           = "psc-music-redis"
    private_connection_resource_id = azurerm_managed_redis.music.id
    subresource_names              = ["redisEnterprise"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis-dns-zone"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }
}


output "redis_host" {
  description = "Azure Managed Redis hostname"
  value       = azurerm_managed_redis.music.hostname
}

output "redis_port" {
  description = "Azure Managed Redis TLS port"
  value       = 10000
}
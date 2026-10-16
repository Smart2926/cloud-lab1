resource "azurerm_subnet" "private_endpoint" {
  name                 = "subnet-private-endpoint"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name

  address_prefixes = ["10.40.3.0/27"]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_subnet" "appgateway" {
  name                 = "subnet-appgateway"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name

  address_prefixes = ["10.40.4.0/24"]
}


resource "azurerm_private_endpoint" "containerapps" {
  name                = "pe-music-containerapps"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  subnet_id = azurerm_subnet.private_endpoint.id

  private_service_connection {
    name = "psc-music-containerapps"

    private_connection_resource_id = (
      azurerm_container_app_environment.music.id
    )

    subresource_names    = ["managedEnvironments"]
    is_manual_connection = false
  }
}


resource "azurerm_private_dns_zone" "containerapps" {
  name = "privatelink.polandcentral.azurecontainerapps.io"

  resource_group_name = azurerm_resource_group.lab.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "containerapps" {
  name                = "containerapps-vnet-link"
  private_dns_zone_id = azurerm_private_dns_zone.containerapps.id
  virtual_network_id  = azurerm_virtual_network.lab.id

  registration_enabled = false
}

resource "azurerm_private_dns_a_record" "containerapps" {
  name = split(
    ".",
    azurerm_container_app_environment.music.default_domain
  )[0]

  private_dns_zone_id = azurerm_private_dns_zone.containerapps.id

  ttl = 300

  records = [
    azurerm_private_endpoint.containerapps.private_service_connection[0].private_ip_address
  ]
}

resource "azurerm_public_ip" "appgateway" {
  name                = "pip-music-appgateway"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  allocation_method = "Static"
  sku               = "Standard"
}


resource "azurerm_application_gateway" "music" {
  name                = "agw-music-lab1"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.appgateway.id
  }

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.appgateway.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  backend_address_pool {
    name = "music-api-backend"

    fqdns = [
      azurerm_container_app.music.ingress[0].fqdn
    ]
  }

  backend_http_settings {
    name                  = "music-api-https"
    cookie_based_affinity = "Disabled"

    port     = 443
    protocol = "Https"

    host_name = azurerm_container_app.music.ingress[0].fqdn

    request_timeout = 60
    probe_name      = "music-health-probe"
  }

  probe {
    name     = "music-health-probe"
    protocol = "Https"
    path     = "/health"

    host = azurerm_container_app.music.ingress[0].fqdn

    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    match {
      status_code = ["200"]
    }
  }

  http_listener {
    name                           = "music-http-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "music-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "music-http-listener"
    backend_address_pool_name  = "music-api-backend"
    backend_http_settings_name = "music-api-https"

    priority = 100
  }

  depends_on = [
    azurerm_private_dns_a_record.containerapps,
    azurerm_private_dns_zone_virtual_network_link.containerapps
  ]
}

output "gateway_public_ip" {
  value = azurerm_public_ip.appgateway.ip_address
}

output "gateway_url" {
  value = "http://${azurerm_public_ip.appgateway.ip_address}"
}

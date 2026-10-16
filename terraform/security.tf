resource "azurerm_network_security_group" "postgres" {
  name                = "nsg-postgres-lab1"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "Allow-ContainerApps-Postgres"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = azurerm_subnet.containers.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.postgres.address_prefixes[0]
  }

  security_rule {
    name                       = "Allow-Postgres-Internal"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = azurerm_subnet.postgres.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.postgres.address_prefixes[0]
  }

  security_rule {
    name                       = "Deny-Other-Postgres"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = azurerm_subnet.postgres.address_prefixes[0]
  }

  tags = {
    project = "cloud-lab1"
  }
}

resource "azurerm_subnet_network_security_group_association" "postgres" {
  subnet_id = azurerm_subnet.postgres.id

  network_security_group_id = azurerm_network_security_group.postgres.id
}

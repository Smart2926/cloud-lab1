resource "azurerm_virtual_network" "lab" {
  name                = "vnet-cloud-lab1"
  location            = azurerm_container_registry.music.location
  resource_group_name = azurerm_resource_group.lab.name

  address_space = ["10.40.0.0/16"]

  tags = {
    project = "cloud-lab1"
  }
}

resource "azurerm_subnet" "postgres" {
  name                 = "subnet-postgres"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name

  address_prefixes = ["10.40.1.0/27"]

  delegation {
    name = "postgresql-delegation"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

resource "azurerm_subnet" "containers" {
  name                 = "subnet-containerapps"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name

  address_prefixes = ["10.40.2.0/27"]

  delegation {
    name = "containerapps-delegation"

    service_delegation {
      name = "Microsoft.App/environments"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

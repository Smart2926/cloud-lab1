resource "azurerm_container_registry" "music" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.lab.name
  location            = var.acr_location

  sku           = "Basic"
  admin_enabled = false

  azuread_authentication_as_arm_policy_enabled = true

  tags = {
    project = "cloud-lab1"
  }
}

output "acr_login_server" {
  value = azurerm_container_registry.music.login_server
}

output "acr_name" {
  value = azurerm_container_registry.music.name
}

resource "azurerm_user_assigned_identity" "github" {
  name                = "id-github-music-deploy"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  tags = {
    project = "cloud-lab1"
  }
}

resource "azurerm_federated_identity_credential" "github" {
  name = "github-main-oidc"

  user_assigned_identity_id = azurerm_user_assigned_identity.github.id

  issuer  = "https://token.actions.githubusercontent.com"
  subject = "repo:${var.github_repository}:ref:refs/heads/main"

  audience = [
    "api://AzureADTokenExchange"
  ]
}

resource "azurerm_role_assignment" "github_acr_push" {
  scope = azurerm_container_registry.music.id

  role_definition_name = "AcrPush"

  principal_id = azurerm_user_assigned_identity.github.principal_id

  principal_type = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_acr_reader" {
  scope = azurerm_container_registry.music.id

  role_definition_name = "Reader"

  principal_id = azurerm_user_assigned_identity.github.principal_id

  principal_type = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "github_container_deploy" {
  scope = azurerm_container_app.music.id

  role_definition_name = "Container Apps Contributor"

  principal_id = azurerm_user_assigned_identity.github.principal_id

  principal_type = "ServicePrincipal"

  skip_service_principal_aad_check = true
}

data "azurerm_client_config" "current" {}

output "github_azure_client_id" {
  value = azurerm_user_assigned_identity.github.client_id
}

output "github_azure_tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "github_azure_subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

resource "azurerm_log_analytics_workspace" "music" {
  name                = "log-music-lab1"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  sku               = "PerGB2018"
  retention_in_days = 30
}


resource "azurerm_container_app_environment" "music" {
  name                = "cae-music-lab1"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  logs_destination = "log-analytics"

  log_analytics_workspace_id = azurerm_log_analytics_workspace.music.id

  infrastructure_subnet_id = azurerm_subnet.containers.id

  internal_load_balancer_enabled = true
  zone_redundancy_enabled        = false


  public_network_access = "Disabled"


  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}



resource "azurerm_user_assigned_identity" "music" {
  name                = "id-music-api"
  location            = azurerm_container_registry.music.location
  resource_group_name = azurerm_resource_group.lab.name
}


resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.music.id
  role_definition_name = var.acr_pull_role
  principal_id         = azurerm_user_assigned_identity.music.principal_id
  principal_type       = "ServicePrincipal"

  skip_service_principal_aad_check = true
}


resource "azurerm_container_app" "music" {
  name                         = "ca-music-api"
  resource_group_name          = azurerm_resource_group.lab.name
  container_app_environment_id = azurerm_container_app_environment.music.id

  revision_mode         = "Single"
  workload_profile_name = "Consumption"

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.music.id
    ]
  }

  registry {
    server   = azurerm_container_registry.music.login_server
    identity = azurerm_user_assigned_identity.music.id
  }

  secret {
    name  = "db-password"
    value = var.db_admin_password
  }

  secret {
    name  = "jwt-secret"
    value = var.jwt_secret_key
  }

  secret {
    name  = "registration-code"
    value = var.registration_code
  }

  secret {
    name  = "redis-password"
    value = azurerm_managed_redis.music.default_database[0].primary_access_key
  }

  secret {
    name  = "servicebus-send"
    value = azurerm_servicebus_queue_authorization_rule.api_sender.primary_connection_string
  }

  template {
    min_replicas               = 1
    max_replicas               = 3
    cooldown_period_in_seconds = 300

    http_scale_rule {
      name                = "http-autoscaling"
      concurrent_requests = "10"
    }

    custom_scale_rule {
      name             = "daytime-schedule"
      custom_rule_type = "cron"

      metadata = {
        timezone        = "Europe/Kyiv"
        start           = "0 8 * * *"
        end             = "0 22 * * *"
        desiredReplicas = "2"
      }
    }

    container {
      name = "music-api"

      image = "${azurerm_container_registry.music.login_server}/music-api:${var.image_tag}"

      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.music.fqdn
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_SSLMODE"
        value = "require"
      }

      env {
        name  = "DB_USER"
        value = var.db_admin_user
      }

      env {
        name        = "DB_PASSWORD"
        secret_name = "db-password"
      }

      env {
        name  = "DB_NAME"
        value = azurerm_postgresql_flexible_server_database.music.name
      }

      env {
        name        = "JWT_SECRET_KEY"
        secret_name = "jwt-secret"
      }

      env {
        name        = "REGISTRATION_CODE"
        secret_name = "registration-code"
      }

      env {
        name  = "REDIS_HOST"
        value = azurerm_managed_redis.music.hostname
      }

      env {
        name  = "REDIS_PORT"
        value = "10000"
      }

      env {
        name        = "REDIS_PASSWORD"
        secret_name = "redis-password"
      }

      env {
        name  = "CACHE_TTL"
        value = "60"
      }

      env {
        name  = "CACHE_ENABLED"
        value = tostring(var.cache_enabled)
      }

      env {
        name        = "SERVICEBUS_SEND_CONNECTION_STRING"
        secret_name = "servicebus-send"
      }

      env {
        name  = "SERVICEBUS_QUEUE_NAME"
        value = azurerm_servicebus_queue.music_tasks.name
      }

    }
  }

  ingress {
    external_enabled           = true
    target_port                = 8000
    allow_insecure_connections = false

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_postgresql_flexible_server_database.music
  ]

  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
  }

}


output "api_url" {
  description = "Public HTTPS address of Music Library API"
  value       = "https://${azurerm_container_app.music.ingress[0].fqdn}"
}

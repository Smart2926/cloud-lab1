resource "azurerm_container_app" "worker" {
  name                         = "ca-music-worker"
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
    name  = "servicebus-worker"
    value = azurerm_servicebus_queue_authorization_rule.worker.primary_connection_string
  }

  secret {
    name  = "redis-password"
    value = azurerm_managed_redis.music.default_database[0].primary_access_key
  }

  template {
    min_replicas               = 0
    max_replicas               = 3
    cooldown_period_in_seconds = 300

    custom_scale_rule {
      name             = "servicebus-autoscaling"
      custom_rule_type = "azure-servicebus"

      metadata = {
        queueName    = azurerm_servicebus_queue.music_tasks.name
        namespace    = azurerm_servicebus_namespace.music.name
        messageCount = "5"
      }

      authentication {
        secret_name       = "servicebus-worker"
        trigger_parameter = "connection"
      }
    }

    container {
      name = "music-worker"

      image = "${azurerm_container_registry.music.login_server}/music-api:${var.image_tag}"

      command = ["python"]
      args    = ["-m", "app.worker"]

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
        name        = "SERVICEBUS_WORKER_CONNECTION_STRING"
        secret_name = "servicebus-worker"
      }

      env {
        name  = "SERVICEBUS_QUEUE_NAME"
        value = azurerm_servicebus_queue.music_tasks.name
      }

      env {
        name  = "WORKER_DELAY_SECONDS"
        value = "2"
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
        name  = "CACHE_ENABLED"
        value = "true"
      }
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

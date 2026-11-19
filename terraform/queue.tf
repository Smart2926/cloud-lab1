resource "azurerm_servicebus_namespace" "music" {
  name                = "sb-musiclab2926-no"
  location            = azurerm_virtual_network.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  sku                 = "Basic"
  minimum_tls_version = "1.2"
}


resource "azurerm_servicebus_queue" "music_tasks" {
  name         = "music-tasks"
  namespace_id = azurerm_servicebus_namespace.music.id

  max_delivery_count  = 5
  lock_duration       = "PT1M"
  default_message_ttl = "P1D"
}


output "servicebus_namespace" {
  description = "Azure Service Bus namespace"
  value       = azurerm_servicebus_namespace.music.name
}


output "servicebus_queue_name" {
  description = "Queue name for asynchronous tasks"
  value       = azurerm_servicebus_queue.music_tasks.name
}

resource "azurerm_servicebus_queue_authorization_rule" "api_sender" {
  name     = "music-api-sender"
  queue_id = azurerm_servicebus_queue.music_tasks.id

  listen = false
  send   = true
  manage = false
}

resource "azurerm_servicebus_queue_authorization_rule" "worker" {
  name     = "music-worker"
  queue_id = azurerm_servicebus_queue.music_tasks.id

  listen = true
  send   = true
  manage = true
}
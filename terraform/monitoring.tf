resource "azurerm_monitor_diagnostic_setting" "gateway" {
  name                       = "diag-music-gateway"
  target_resource_id         = azurerm_application_gateway.music.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.music.id

  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }
}


resource "azurerm_monitor_diagnostic_setting" "app_metrics" {
  name                       = "diag-music-app-metrics"
  target_resource_id         = azurerm_container_app.music.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.music.id

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_action_group" "music" {
  name                = "ag-music-monitoring"
  resource_group_name = azurerm_resource_group.lab.name
  short_name          = "MusicAlert"

  email_receiver {
    name                    = "student-email"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}


resource "azurerm_monitor_metric_alert" "gateway_errors" {
  name                = "alert-music-gateway-errors"
  resource_group_name = azurerm_resource_group.lab.name

  scopes = [
    azurerm_application_gateway.music.id
  ]

  description = "Alert when Application Gateway detects failed requests"

  severity    = 2
  enabled     = true
  frequency   = "PT5M"
  window_size = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "FailedRequests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  action {
    action_group_id = azurerm_monitor_action_group.music.id
  }
}



locals {
  music_monitor_panels = [

    # 1. HTTP Requests

    {
      title = "1. HTTP Requests"

      query = <<-KQL
        AGWAccessLogs
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_application_gateway.music.id}"
        | summarize Requests=count()
            by bin(TimeGenerated, 5m)
        | order by TimeGenerated asc
      KQL
    },

    {
      title = "2. HTTP 5xx Errors"

      query = <<-KQL
        AGWAccessLogs
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_application_gateway.music.id}"
        | summarize Errors5xx=countif(
            toint(HttpStatus) between (500 .. 599)
          ) by bin(TimeGenerated, 5m)
        | order by TimeGenerated asc
      KQL
    },


    {
      title = "3. Average Latency (ms)"

      query = <<-KQL
        AGWAccessLogs
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_application_gateway.music.id}"
        | summarize Latency_ms=round(
            avg(TimeTaken) * 1000.0, 2
          ) by bin(TimeGenerated, 5m)
        | order by TimeGenerated asc
      KQL
    },


    {
      title = "4. Container App CPU (cores)"

      query = <<-KQL
        AzureMetrics
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_container_app.music.id}"
        | where MetricName in~ (
            "UsageNanoCores",
            "CPU Usage Nanocores",
            "CPU Usage"
          )
        | summarize CPU_cores=avg(Average)/1000000000.0
            by bin(TimeGenerated, 5m)
        | order by TimeGenerated asc
      KQL
    },

    # 5. Container App memory

    {
      title = "5. Container App Memory (MiB)"

      query = <<-KQL
        AzureMetrics
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_container_app.music.id}"
        | where MetricName in~ (
            "WorkingSetBytes",
            "Memory Working Set Bytes",
            "Memory Working Set"
          )
        | summarize Memory_MiB=avg(Average)/1048576.0
            by bin(TimeGenerated, 5m)
        | order by TimeGenerated asc
      KQL
    }
  ]
}

resource "azurerm_application_insights_workbook" "music" {
  name                = "b472a875-0b2c-49c7-9b12-4b21f2c9d707"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_virtual_network.lab.location

  display_name = "Music API - Monitoring Dashboard"

  description = "Music API monitoring: requests, 5xx errors, latency, CPU and memory"

  data_json = jsonencode({
    version = "Notebook/1.0"

    items = concat(
      [
        {
          type = 1
          name = "introduction"

          content = {
            json = <<-MD
              # Music Library API Monitoring

              Monitoring dashboard created with Terraform.

              **Application:** ca-music-api

              **Gateway:** agw-music-lab1

              **Log Analytics:** log-music-lab1

              The dashboard displays:
              - HTTP request count
              - HTTP 5xx errors
              - Average HTTP latency
              - Container App CPU
              - Container App memory

              **Time range:** Last 24 hours.
            MD
          }
        }
      ],

      [
        for i, panel in local.music_monitor_panels : {
          type = 3
          name = "metric-${i}"

          content = {
            version = "KqlItem/1.0"
            title   = panel.title
            query   = panel.query

            size          = 0
            queryType     = 0
            resourceType  = "microsoft.operationalinsights/workspaces"
            visualization = "linechart"

            crossComponentResources = [
              azurerm_log_analytics_workspace.music.id
            ]

            timeContext = {
              durationMs = 86400000
            }
          }
        }
      ]
    )

    isLocked = false

    fallbackResourceIds = [
      azurerm_log_analytics_workspace.music.id
    ]
  })

  tags = {
    project = "cloud-lab1"
    task    = "monitoring"
  }
}

output "monitoring_workbook_id" {
  description = "Azure Monitor Workbook resource ID"
  value       = azurerm_application_insights_workbook.music.id
}

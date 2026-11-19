locals {
  music_lab2_dashboard_panels = [

    {
      title  = "1. Replicas"
      series = ["ActualReplicas", "ConfiguredMin", "ConfiguredMax"]

      query = <<-KQL
        AzureMetrics
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_container_app.music.id}"
        | where MetricName in~ ("Replicas", "Replica Count")
        | summarize ActualReplicas = max(coalesce(Average, Maximum))
            by bin(TimeGenerated, 1m)
        | extend ConfiguredMin = 1.0, ConfiguredMax = 3.0
        | order by TimeGenerated asc
      KQL
    },

    {
      title  = "2. CPU Usage (cores)"
      series = ["CpuCores"]

      query = <<-KQL
        AzureMetrics
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_container_app.music.id}"
        | where MetricName in~ ("UsageNanoCores", "CPU Usage")
        | summarize CpuCores = round(avg(Average) / 1000000000.0, 3)
            by bin(TimeGenerated, 1m)
        | order by TimeGenerated asc
      KQL
    },

    {
      title  = "3. HTTP Requests per Minute"
      series = ["RequestsPerMinute"]

      query = <<-KQL
        AGWAccessLogs
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_application_gateway.music.id}"
        | summarize RequestsPerMinute = toreal(count())
            by bin(TimeGenerated, 1m)
        | order by TimeGenerated asc
      KQL
    },

    {
      title  = "4. Response Time p95 (ms)"
      series = ["P95ms"]

      query = <<-KQL
        AGWAccessLogs
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_application_gateway.music.id}"
        | summarize P95ms = round(percentile(TimeTaken * 1000.0, 95), 2)
            by bin(TimeGenerated, 1m)
        | order by TimeGenerated asc
      KQL
    },

    {
      title  = "5. HTTP 5xx Errors"
      series = ["Errors5xx"]

      query = <<-KQL
        AGWAccessLogs
        | where TimeGenerated > ago(24h)
        | where _ResourceId =~ "${azurerm_application_gateway.music.id}"
        | summarize Errors5xx = toreal(
            countif(toint(HttpStatus) between (500 .. 599))
          ) by bin(TimeGenerated, 1m)
        | order by TimeGenerated asc
      KQL
    }
  ]
}


resource "azurerm_portal_dashboard" "music_lab2" {
  name                = "dash-music-lab2"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_virtual_network.lab.location

  tags = {
    "hidden-title" = "Music API - Lab 2 Monitoring"
    project        = "cloud-lab2"
  }

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0

        parts = {
          for i, panel in local.music_lab2_dashboard_panels :
          tostring(i) => {

            position = {
              x       = (i % 2) * 6
              y       = floor(i / 2) * 4
              colSpan = 6
              rowSpan = 4
            }

            metadata = {
              type = "Extension/Microsoft_OperationsManagementSuite_Workspace/PartType/LogsDashboardPart"

              inputs = [
                {
                  name       = "resourceTypeMode"
                  isOptional = true
                },
                {
                  name       = "ComponentId"
                  isOptional = true
                },
                {
                  name = "Scope"

                  value = {
                    resourceIds = [
                      azurerm_log_analytics_workspace.music.id
                    ]
                  }

                  isOptional = true
                },
                {
                  name       = "PartId"
                  value      = uuidv5("dns", "music-lab2-panel-${i}")
                  isOptional = true
                },
                {
                  name       = "Version"
                  value      = "2.0"
                  isOptional = true
                },
                {
                  name       = "TimeRange"
                  value      = "P1D"
                  isOptional = true
                },
                {
                  name       = "Query"
                  value      = panel.query
                  isOptional = true
                },
                {
                  name       = "ControlType"
                  value      = "FrameControlChart"
                  isOptional = true
                },
                {
                  name       = "SpecificChart"
                  value      = "Line"
                  isOptional = true
                },
                {
                  name       = "PartTitle"
                  value      = panel.title
                  isOptional = true
                },
                {
                  name       = "PartSubTitle"
                  value      = "Last 24 hours"
                  isOptional = true
                },
                {
                  name = "Dimensions"

                  value = {
                    xAxis = {
                      name = "TimeGenerated"
                      type = "datetime"
                    }

                    yAxis = [
                      for series_name in panel.series : {
                        name = series_name
                        type = "real"
                      }
                    ]

                    splitBy     = []
                    aggregation = "Average"
                  }

                  isOptional = true
                },
                {
                  name = "LegendOptions"

                  value = {
                    isEnabled = true
                    position  = "Bottom"
                  }

                  isOptional = true
                },
                {
                  name       = "IsQueryContainTimeRange"
                  value      = false
                  isOptional = true
                }
              ]

              settings = {
                content = {
                  Query = panel.query
                }
              }
            }
          }
        }
      }
    }

    metadata = {
      model = {}
    }
  })
}


output "monitoring_dashboard_id" {
  description = "Azure Portal Dashboard ID"
  value       = azurerm_portal_dashboard.music_lab2.id
}
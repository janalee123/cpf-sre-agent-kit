# Fires when a container in the namespace restarts repeatedly. The response plan in
# ../agent-config/response-plans matches this rule by name and starts the investigator.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "oom_restarts" {
  name                    = var.alert_name
  resource_group_name     = var.resource_group_name
  location                = var.location
  description             = "Detects repeated OOMKilled restarts of ${var.container_name} in ${var.namespace}."
  severity                = var.severity
  scopes                  = [var.log_analytics_workspace_id]
  evaluation_frequency    = "PT1M"
  window_duration         = "PT5M"
  auto_mitigation_enabled = false

  criteria {
    query                   = <<-KQL
      KubePodInventory
      | where TimeGenerated > ago(5m)
      | where Namespace == "${var.namespace}"
      | where ContainerName endswith "/${var.container_name}" or ContainerName == "${var.container_name}"
      | summarize RestartCount = max(ContainerRestartCount) by ClusterName, Namespace, Name, ContainerName
      | where RestartCount >= ${var.restart_threshold}
    KQL
    time_aggregation_method = "Count"
    operator                = "GreaterThanOrEqual"
    threshold               = 1

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  dynamic "action" {
    for_each = length(var.action_group_ids) > 0 ? [1] : []
    content {
      action_groups = var.action_group_ids
    }
  }
}

output "alert_rule_id" {
  value = azurerm_monitor_scheduled_query_rules_alert_v2.oom_restarts.id
}

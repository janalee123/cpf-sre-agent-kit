variable "subscription_id" {
  type        = string
  description = "Subscription that holds the Log Analytics workspace and the alert rule."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the alert rule."
}

variable "location" {
  type        = string
  description = "Region for the alert rule. Use the workspace region."
}

variable "alert_name" {
  type        = string
  description = "Alert rule name. Put the same value in AKS_OOM_ALERT_NAME so the response plan matches it."
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Resource ID of the Log Analytics workspace that receives Container insights data from the cluster."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the workload to watch."
}

variable "container_name" {
  type        = string
  description = "Container to watch for OOMKilled restarts."
}

variable "restart_threshold" {
  type        = number
  default     = 2
  description = "Restarts within the 5-minute window that count as repeated."
}

variable "severity" {
  type        = number
  default     = 2
  description = "Alert severity. The response plan picks up Sev0 to Sev2 (P1 and P2)."
}

variable "action_group_ids" {
  type        = list(string)
  default     = []
  description = "Optional action groups to notify. The SRE Agent does not need one; it reads alerts from Azure Monitor."
}

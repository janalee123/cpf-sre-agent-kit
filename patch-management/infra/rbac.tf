# Read-only access (default): Reader-style roles only. The agent can see, rank and explain, but cannot change anything.

resource "azurerm_role_assignment" "vm_scope_reader" {
  for_each             = toset(var.vm_scope_ids)
  scope                = each.value
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
}

resource "azurerm_role_assignment" "aks_reader" {
  for_each             = toset(var.aks_cluster_ids)
  scope                = each.value
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
}

# Lets the agent read deprecated APIs and pod disruption budgets inside the cluster. Without it those checks report Unknown.
resource "azurerm_role_assignment" "aks_rbac_reader" {
  for_each             = toset(var.aks_cluster_ids)
  scope                = each.value
  role_definition_name = "Azure Kubernetes Service RBAC Reader"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
}

resource "azurerm_role_assignment" "log_analytics_reader" {
  for_each             = toset(concat([azurerm_log_analytics_workspace.agent.id], var.log_analytics_workspace_ids))
  scope                = each.value
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
}

resource "azurerm_role_assignment" "app_insights_reader" {
  scope                = azurerm_application_insights.agent.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
}

resource "azurerm_role_assignment" "security_reader" {
  count                = var.grant_security_reader ? 1 : 0
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Security Reader"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
}

# Optional gated write access: only when enable_patch_write = true. Scope this to a single pilot resource group.
resource "azurerm_role_assignment" "patch_write" {
  for_each             = var.enable_patch_write ? toset(var.patch_write_scope_ids) : toset([])
  scope                = each.value
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
}

# People who chat with the agent.
resource "azurerm_role_assignment" "agent_users" {
  for_each             = toset(var.agent_user_principal_ids)
  scope                = azapi_resource.agent.id
  role_definition_name = var.agent_user_role_name
  principal_id         = each.value
}

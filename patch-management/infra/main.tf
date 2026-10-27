resource "azurerm_resource_group" "agent" {
  name     = var.agent_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_user_assigned_identity" "agent" {
  name                = "id-${var.agent_name}"
  location            = azurerm_resource_group.agent.location
  resource_group_name = azurerm_resource_group.agent.name
  tags                = var.tags
}

resource "azurerm_log_analytics_workspace" "agent" {
  name                = "law-${var.agent_name}"
  location            = azurerm_resource_group.agent.location
  resource_group_name = azurerm_resource_group.agent.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "agent" {
  name                = "appi-${var.agent_name}"
  location            = azurerm_resource_group.agent.location
  resource_group_name = azurerm_resource_group.agent.name
  workspace_id        = azurerm_log_analytics_workspace.agent.id
  application_type    = "other"
  tags                = var.tags
}

resource "azapi_resource" "agent" {
  type                      = "Microsoft.App/agents@${var.agent_api_version}"
  name                      = var.agent_name
  parent_id                 = azurerm_resource_group.agent.id
  location                  = var.location
  schema_validation_enabled = false
  response_export_values    = ["properties.agentEndpoint"]
  tags                      = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agent.id]
  }

  body = {
    properties = {
      actionConfiguration = {
        mode        = var.action_mode
        accessLevel = "Low"
        identity    = azurerm_user_assigned_identity.agent.id
      }
      defaultModel = {
        provider = "Anthropic"
        name     = "Automatic"
      }
      logConfiguration = {
        applicationInsightsConfiguration = {
          appId            = azurerm_application_insights.agent.app_id
          connectionString = azurerm_application_insights.agent.connection_string
        }
      }
      knowledgeGraphConfiguration = {
        identity         = azurerm_user_assigned_identity.agent.id
        managedResources = concat(var.vm_scope_ids, var.aks_cluster_ids)
      }
      upgradeChannel = "Stable"
    }
  }

  depends_on = [
    azurerm_role_assignment.vm_scope_reader,
    azurerm_role_assignment.aks_reader,
  ]
}

resource "terraform_data" "agent_config" {
  count = var.apply_agent_config ? 1 : 0

  triggers_replace = [
    azapi_resource.agent.id,
    sha1(join("", [for f in sort(fileset("${path.module}/../agent-config", "**")) : filesha1("${path.module}/../agent-config/${f}")])),
  ]

  provisioner "local-exec" {
    interpreter = ["pwsh", "-NoProfile", "-Command"]
    command     = "& '${path.module}/../scripts/Deploy-AgentConfig.ps1' -SubscriptionId '${var.subscription_id}' -ResourceGroup '${azurerm_resource_group.agent.name}' -AgentName '${var.agent_name}' -ParametersFile '${var.agent_config_parameters_file}'"
  }
}

output "agent_id" {
  description = "Resource ID of the SRE Agent."
  value       = azapi_resource.agent.id
}

output "agent_endpoint" {
  description = "Data-plane endpoint used by scripts/Deploy-AgentConfig.ps1."
  value       = azapi_resource.agent.output.properties.agentEndpoint
}

output "agent_identity_principal_id" {
  description = "Object ID of the agent's managed identity. Use it for any extra role assignments."
  value       = azurerm_user_assigned_identity.agent.principal_id
}

output "portal_url" {
  description = "Open the agent in the SRE Agent portal."
  value       = "https://sre.azure.com/agents${azapi_resource.agent.id}"
}

output "demo_vm_id" {
  description = "Resource ID of the optional demo VM."
  value       = var.deploy_demo_vm ? azurerm_windows_virtual_machine.demo[0].id : null
}

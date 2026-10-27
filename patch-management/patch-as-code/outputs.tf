output "recurring_maintenance_configuration_ids" {
  value = { for k, v in azurerm_maintenance_configuration.recurring : k => v.id }
}

output "emergency_maintenance_configuration_ids" {
  value = { for k, v in azurerm_maintenance_configuration.emergency : k => v.id }
}

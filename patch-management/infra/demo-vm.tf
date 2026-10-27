# Optional sandbox VM. It uses manual patching and can be pinned to an older image so that the
# agent has real missing Critical and Security updates to triage. It has no public IP.

resource "azurerm_resource_group" "demo" {
  count    = var.deploy_demo_vm ? 1 : 0
  name     = var.demo_vm_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "demo" {
  count               = var.deploy_demo_vm ? 1 : 0
  name                = "vnet-${var.demo_vm_name}"
  location            = azurerm_resource_group.demo[0].location
  resource_group_name = azurerm_resource_group.demo[0].name
  address_space       = ["10.42.0.0/24"]
  tags                = var.tags
}

resource "azurerm_subnet" "demo" {
  count                = var.deploy_demo_vm ? 1 : 0
  name                 = "snet-vms"
  resource_group_name  = azurerm_resource_group.demo[0].name
  virtual_network_name = azurerm_virtual_network.demo[0].name
  address_prefixes     = ["10.42.0.0/26"]
}

resource "azurerm_network_interface" "demo" {
  count               = var.deploy_demo_vm ? 1 : 0
  name                = "nic-${var.demo_vm_name}"
  location            = azurerm_resource_group.demo[0].location
  resource_group_name = azurerm_resource_group.demo[0].name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.demo[0].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "random_password" "demo_vm" {
  count            = var.deploy_demo_vm ? 1 : 0
  length           = 24
  special          = true
  override_special = "!@#%*-_=+"
}

resource "azurerm_windows_virtual_machine" "demo" {
  count                     = var.deploy_demo_vm ? 1 : 0
  name                      = var.demo_vm_name
  location                  = azurerm_resource_group.demo[0].location
  resource_group_name       = azurerm_resource_group.demo[0].name
  size                      = var.demo_vm_size
  admin_username            = "azureadmin"
  admin_password            = random_password.demo_vm[0].result
  network_interface_ids     = [azurerm_network_interface.demo[0].id]
  patch_mode                = "Manual"
  automatic_updates_enabled = false
  patch_assessment_mode     = "AutomaticByPlatform"
  provision_vm_agent        = true

  tags = merge(var.tags, {
    environment = "production"
    patch-group = "pilot"
  })

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = var.demo_vm_image_version
  }
}

resource "azurerm_role_assignment" "demo_vm_reader" {
  count                = var.deploy_demo_vm ? 1 : 0
  scope                = azurerm_resource_group.demo[0].id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.agent.principal_id
}

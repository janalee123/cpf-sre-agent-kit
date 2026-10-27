# Patching as code. Update Manager still installs the updates; Terraform only defines when, what and on
# which machines. Every change to the plan goes through a pull request and an approved pipeline run.
#
# Machines must use patch orchestration "AutomaticByPlatform" with "bypass platform safety checks on user
# schedule" enabled (customer-managed schedules), and carry the tag patch-group = <group key>.

resource "azurerm_maintenance_configuration" "recurring" {
  for_each = var.patch_groups

  name                     = "mc-patch-${each.key}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  scope                    = "InGuestPatch"
  in_guest_user_patch_mode = "User"

  window {
    start_date_time = each.value.start_date_time
    duration        = each.value.duration
    time_zone       = var.time_zone
    recur_every     = each.value.recur_every
  }

  install_patches {
    reboot = each.value.reboot

    dynamic "windows" {
      for_each = contains(each.value.os_types, "Windows") ? [1] : []
      content {
        classifications_to_include = each.value.classifications
        kb_numbers_to_exclude      = each.value.kb_exclude
      }
    }

    dynamic "linux" {
      for_each = contains(each.value.os_types, "Linux") ? [1] : []
      content {
        classifications_to_include = [for c in each.value.classifications : c if contains(["Critical", "Security", "Other"], c)]
      }
    }
  }

  tags = { managed-by = "terraform", patch-group = each.key }
}

resource "azurerm_maintenance_assignment_dynamic_scope" "recurring" {
  for_each = var.patch_groups

  name                         = "as-patch-${each.key}"
  maintenance_configuration_id = azurerm_maintenance_configuration.recurring[each.key].id

  filter {
    os_types        = each.value.os_types
    resource_groups = each.value.resource_groups
    resource_types  = ["Microsoft.Compute/virtualMachines", "Microsoft.HybridCompute/machines"]
    tag_filter      = "Any"
    tags {
      tag    = "patch-group"
      values = [each.key]
    }
  }
}

# One-off emergency windows: a daily recurrence that expires the day after it starts, so it runs once.
resource "azurerm_maintenance_configuration" "emergency" {
  for_each = var.emergency_windows

  name                     = "mc-emergency-${each.key}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  scope                    = "InGuestPatch"
  in_guest_user_patch_mode = "User"

  window {
    start_date_time      = each.value.start_date_time
    expiration_date_time = formatdate("YYYY-MM-DD hh:mm", timeadd("${replace(each.value.start_date_time, " ", "T")}:00Z", "23h"))
    duration             = each.value.duration
    time_zone            = var.time_zone
    recur_every          = "1Day"
  }

  install_patches {
    reboot = each.value.reboot
    windows {
      kb_numbers_to_include = each.value.kb_include
    }
  }

  tags = {
    managed-by  = "terraform"
    patch-group = each.value.patch_group
    change-ref  = each.value.change_ref
    reason      = each.value.reason
  }
}

resource "azurerm_maintenance_assignment_dynamic_scope" "emergency" {
  for_each = var.emergency_windows

  name                         = "as-emergency-${each.key}"
  maintenance_configuration_id = azurerm_maintenance_configuration.emergency[each.key].id

  filter {
    os_types       = ["Windows"]
    resource_types = ["Microsoft.Compute/virtualMachines", "Microsoft.HybridCompute/machines"]
    tag_filter     = "Any"
    tags {
      tag    = "patch-group"
      values = [each.value.patch_group]
    }
  }
}

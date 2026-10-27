variable "subscription_id" {
  type        = string
  description = "Subscription that holds the maintenance configurations."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group for the maintenance configurations."
}

variable "location" {
  type        = string
  description = "Region for the maintenance configurations."
}

variable "time_zone" {
  type        = string
  default     = "Singapore Standard Time"
  description = "Time zone for every patch window."
}

variable "patch_groups" {
  description = <<-EOT
    Recurring patch windows, one per group of machines. Machines join a group through the tag
    patch-group = <key>. The agent proposes edits to this map; people approve them in a pull request.
  EOT
  type = map(object({
    start_date_time = string       # "YYYY-MM-DD hh:mm" of the first window
    duration        = string       # "hh:mm", between 01:30 and 03:55
    recur_every     = string       # for example "1Month Second Tuesday Offset2" or "1Week Saturday"
    reboot          = string       # IfRequired, Never or Always
    classifications = list(string) # Windows: Critical, Security, UpdateRollup, ... Linux: Critical, Security, Other
    kb_exclude      = optional(list(string), [])
    os_types        = optional(list(string), ["Windows"])
    resource_groups = optional(list(string), [])
  }))
}

variable "emergency_windows" {
  description = <<-EOT
    One-off windows for urgent fixes, such as a CISA known-exploited CVE that cannot wait for the next
    recurring window. Each entry installs only the listed KBs on the listed machines' patch group, then
    expires. Remove the entry after the change is closed.
  EOT
  type = map(object({
    patch_group     = string       # tag value of patch-group to target
    start_date_time = string       # "YYYY-MM-DD hh:mm"
    duration        = string       # "hh:mm", between 01:30 and 03:55
    kb_include      = list(string) # KB numbers without the "KB" prefix
    reboot          = string
    change_ref      = string # change record or work item that approved it
    reason          = string # for example "CVE-2026-12345 in CISA KEV"
  }))
  default = {}
}

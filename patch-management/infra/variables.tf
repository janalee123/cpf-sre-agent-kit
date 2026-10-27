variable "subscription_id" {
  description = "Subscription that hosts the SRE Agent."
  type        = string
}

variable "location" {
  description = "Azure region for the agent and its supporting resources. Must be a region where Azure SRE Agent is available."
  type        = string
  default     = "southeastasia"
}

variable "agent_resource_group_name" {
  description = "Resource group created for the agent, its identity and its telemetry."
  type        = string
  default     = "rg-sre-agent-patch"
}

variable "agent_name" {
  description = "SRE Agent name."
  type        = string
  default     = "sre-agent-patch"
}

variable "agent_api_version" {
  description = "API version for the Microsoft.App/agents resource."
  type        = string
  default     = "2026-01-01"
}

variable "action_mode" {
  description = "Agent action mode. Keep 'Review' so a human approves every write action."
  type        = string
  default     = "Review"

  validation {
    condition     = contains(["Review", "Automatic", "Disabled"], var.action_mode)
    error_message = "action_mode must be Review, Automatic or Disabled."
  }
}

variable "vm_scope_ids" {
  description = "Resource group (or subscription) IDs that contain the Azure VMs and Azure Arc-enabled servers in scope. The agent gets Reader on each."
  type        = list(string)
}

variable "aks_cluster_ids" {
  description = "AKS cluster resource IDs in scope. The agent gets Reader and 'Azure Kubernetes Service RBAC Reader' on each."
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_ids" {
  description = "Existing Log Analytics workspaces that hold Update Manager, Change Tracking or Defender data. The agent gets Log Analytics Reader on each."
  type        = list(string)
  default     = []
}

variable "grant_security_reader" {
  description = "Grant Security Reader at subscription scope so the agent can read Defender for Cloud vulnerability findings."
  type        = bool
  default     = true
}

variable "enable_patch_write" {
  description = "Optional. Grants Virtual Machine Contributor on patch_write_scope_ids so the gated patch-remediation skill can call install-patches. Leave false for read-only use."
  type        = bool
  default     = false
}

variable "patch_write_scope_ids" {
  description = "Only used when enable_patch_write = true. Narrow scopes (ideally a single pilot resource group) for write access."
  type        = list(string)
  default     = []
}

variable "agent_user_principal_ids" {
  description = "Entra object IDs of people who use the agent. They get the role in agent_user_role_name on the agent."
  type        = list(string)
  default     = []
}

variable "agent_user_role_name" {
  description = "Role granted to agent users."
  type        = string
  default     = "SRE Agent Standard User"
}

variable "deploy_demo_vm" {
  description = "Create a Windows Server VM with manual patching so there are missing updates to triage. Optional; useful for a sandbox."
  type        = bool
  default     = false
}

variable "demo_vm_resource_group_name" {
  description = "Resource group for the optional demo VM."
  type        = string
  default     = "rg-patch-demo"
}

variable "demo_vm_name" {
  description = "Name of the optional demo VM (15 characters or fewer)."
  type        = string
  default     = "patch-demo-01"
}

variable "demo_vm_size" {
  description = "Size of the optional demo VM."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "demo_vm_image_version" {
  description = "Windows Server 2022 image version. Pin an older version (for example from a few months ago) so updates are missing on day one."
  type        = string
  default     = "latest"
}

variable "apply_agent_config" {
  description = "Run scripts/Deploy-AgentConfig.ps1 after the agent is created to load skills, knowledge, prompts and scheduled tasks. Needs PowerShell 7 and Azure CLI on the machine running Terraform."
  type        = bool
  default     = false
}

variable "agent_config_parameters_file" {
  description = "Parameters file passed to Deploy-AgentConfig.ps1 when apply_agent_config is true."
  type        = string
  default     = "../agent-config/parameters.json"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    workload = "sre-agent-patch-management"
  }
}

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  # Use a remote backend (for example azurerm) so the pipeline and people share state.
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

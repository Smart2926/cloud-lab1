
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_subscription" "current" {}

resource "azurerm_consumption_budget_subscription" "lab_budget" {
  name            = "lab1-budget"
  subscription_id = data.azurerm_subscription.current.id

  amount     = 10
  time_grain = "Monthly"

  time_period {
    start_date = "2026-10-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThanOrEqualTo"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThanOrEqualTo"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    contact_emails = [var.alert_email]
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-cloud-lab1"
  location = "westeurope"

  tags = {
    project = "cloud-lab1"
    owner   = "student"
  }
}

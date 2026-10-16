variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "alert_email" {
  description = "Email for budget notifications"
  type        = string
}

variable "acr_name" {
  description = "Unique Azure Container Registry name"
  type        = string
}

variable "acr_location" {
  description = "Azure region for Container Registry"
  type        = string
}

variable "postgres_server_name" {
  description = "Unique PostgreSQL server name"
  type        = string
}

variable "db_admin_user" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "musicadmin"
}

variable "db_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "v1"
}

variable "acr_pull_role" {
  description = "ACR image pull role"
  type        = string
  default     = "AcrPull"
}


variable "github_repository" {
  description = "GitHub repository in OWNER/REPO format"
  type        = string
}


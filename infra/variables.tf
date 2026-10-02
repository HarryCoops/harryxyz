variable "account_id" {
  description = "Cloudflare account that owns the Pages project and D1 databases."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{32}$", var.account_id))
    error_message = "account_id must be a 32-character Cloudflare account ID."
  }
}

variable "zone_id" {
  description = "Cloudflare zone ID for the custom domain serving the Pages site."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{32}$", var.zone_id))
    error_message = "zone_id must be a 32-character Cloudflare zone ID."
  }
}

variable "custom_domain" {
  description = "Custom domain hostname for the Pages site, without scheme or path."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", var.custom_domain))
    error_message = "custom_domain must be a hostname such as invite.example.com, without https:// or a path."
  }
}

variable "project_name" {
  description = "Existing or new direct-upload Pages project name."
  type        = string
  default     = "harryxyz"
}

variable "production_branch" {
  description = "Branch whose Pages uploads become production deployments."
  type        = string
  default     = "main"
}

variable "database_name" {
  description = "Production RSVP database name."
  type        = string
  default     = "harryxyz-rsvps"
}

variable "enable_preview_database" {
  description = "Create an isolated database and RSVP_DB binding for preview deployments."
  type        = bool
  default     = false
}

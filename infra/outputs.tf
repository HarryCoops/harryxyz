output "database_id" {
  description = "Production D1 database UUID."
  value       = cloudflare_d1_database.rsvps.id
}

output "preview_database_id" {
  description = "Preview D1 database UUID, when enabled."
  value       = try(cloudflare_d1_database.preview[0].id, null)
}

output "pages_url" {
  description = "Pages URL; content is uploaded separately by Wrangler."
  value       = "https://${cloudflare_pages_project.site.subdomain}"
}

# Export to infra/wrangler-migrations.json. This is exclusively a migration
# config: do not use it for Pages deploys, whose bindings Terraform manages.
output "migration_config" {
  description = "Wrangler JSON configuration for applying SQL migrations."
  value = jsonencode({
    name               = "${var.project_name}-migrations"
    account_id         = var.account_id
    compatibility_date = "2026-10-01"
    d1_databases = concat([
      {
        binding        = "RSVP_DB"
        database_name  = cloudflare_d1_database.rsvps.name
        database_id    = cloudflare_d1_database.rsvps.id
        migrations_dir = "../migrations"
      }
      ], var.enable_preview_database ? [
      {
        binding        = "RSVP_PREVIEW_DB"
        database_name  = cloudflare_d1_database.preview[0].name
        database_id    = cloudflare_d1_database.preview[0].id
        migrations_dir = "../migrations"
      }
    ] : [])
  })
}

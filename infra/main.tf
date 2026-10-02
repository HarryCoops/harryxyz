resource "cloudflare_d1_database" "rsvps" {
  account_id       = var.account_id
  name             = var.database_name
  read_replication = { mode = "disabled" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_d1_database" "preview" {
  count            = var.enable_preview_database ? 1 : 0
  account_id       = var.account_id
  name             = "${var.database_name}-preview"
  read_replication = { mode = "disabled" }
}

resource "cloudflare_pages_project" "site" {
  account_id        = var.account_id
  name              = var.project_name
  production_branch = var.production_branch

  deployment_configs = {
    production = {
      d1_databases = {
        RSVP_DB = { id = cloudflare_d1_database.rsvps.id }
      }
    }
    preview = {
      d1_databases = var.enable_preview_database ? {
        RSVP_DB = { id = cloudflare_d1_database.preview[0].id }
      } : {}
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Keep direct requests to the public RSVP endpoint from reaching Pages too
# quickly. The path-only expression keeps this compatible with Free plans.
resource "cloudflare_ruleset" "rsvp_rate_limit" {
  zone_id     = var.zone_id
  name        = "RSVP API rate limit"
  description = "Limit requests to the public RSVP endpoint."
  kind        = "zone"
  phase       = "http_ratelimit"

  rules = [{
    ref         = "limit_rsvp_api"
    description = "Allow at most five requests per IP every ten seconds."
    expression  = "http.request.uri.path eq \"/api/rsvp\""
    action      = "block"
    ratelimit = {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 10
      requests_per_period = 5
      mitigation_timeout  = 10
    }
  }]
}

# Pages deployments remain reachable on *.pages.dev unless that hostname is
# redirected. This account-level Bulk Redirect preserves endpoint paths and
# query strings, so the zone-level RSVP rate limit still handles submissions.
resource "cloudflare_list" "pages_domain_redirects" {
  account_id  = var.account_id
  name        = "${replace(var.project_name, "-", "_")}_pages_redirects"
  description = "Redirect the Pages hostname to the custom domain."
  kind        = "redirect"
}

resource "cloudflare_list_item" "pages_domain_redirect" {
  account_id = var.account_id
  list_id    = cloudflare_list.pages_domain_redirects.id
  comment    = "Redirect ${cloudflare_pages_project.site.subdomain} to ${var.custom_domain}."

  redirect = {
    source_url            = "https://${cloudflare_pages_project.site.subdomain}/"
    target_url            = "https://${var.custom_domain}/"
    status_code           = 301
    subpath_matching      = true
    preserve_path_suffix  = true
    preserve_query_string = true
  }
}

resource "cloudflare_ruleset" "pages_domain_redirect" {
  account_id  = var.account_id
  name        = "Pages hostname redirect"
  description = "Redirect the Pages hostname to the custom domain."
  kind        = "root"
  phase       = "http_request_redirect"

  rules = [{
    ref         = "redirect_pages_hostname"
    description = "Redirect the production Pages URL to the custom domain."
    expression  = format("http.request.full_uri in $%s", cloudflare_list.pages_domain_redirects.name)
    action      = "redirect"
    action_parameters = {
      from_list = {
        name = cloudflare_list.pages_domain_redirects.name
        key  = "http.request.full_uri"
      }
    }
  }]

  depends_on = [cloudflare_list_item.pages_domain_redirect]
}

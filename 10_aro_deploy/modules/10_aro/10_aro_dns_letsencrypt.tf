
# Per https://cloud.redhat.com/experts/aro/cert-manager/

resource "azurerm_dns_caa_record" "letsencrypt" {
  name                = "@"
  zone_name           = var.azure_dns_zone["domain_name"]
  resource_group_name = var.azure_dns_zone["resource_group_name"]
  ttl                 = var.azure_dns_zone["ttl"]

  record {
    flags = 0
    tag   = "issuewild"
    value = "letsencrypt.org"
  }
}
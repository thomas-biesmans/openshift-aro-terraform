
resource "azurerm_dns_a_record" "api_server" {
  count               = var.openshift["cluster_name"] ? "" : 0
  name                = "api.${var.openshift["cluster_name"]}"
  zone_name           = var.azure_dns_zone["name"]
  resource_group_name = var.azure_dns_zone["rg"]
  ttl                 = 300
  records             = [jsondecode(data.azapi_resource.aro_details.output).properties.apiserverProfile.ip]

  provider = azurerm.secondary
}

resource "azurerm_dns_a_record" "apps_wildcard" {
  count               = var.openshift["cluster_name"] ? "" : 0
  name                = "*.apps.${var.openshift["cluster_name"]}"
  zone_name           = var.azure_dns_zone["name"]
  resource_group_name = var.azure_dns_zone["rg"]
  ttl                 = 300
  records             = [jsondecode(data.azapi_resource.aro_details.output).properties.ingressProfiles[0].ip]

  provider = azurerm.secondary
}
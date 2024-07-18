output "storageaccount" {
  value = azurerm_storage_account.sa.name

}
output "storageaccount_ak" {
  value     = azurerm_storage_account.sa.secondary_access_key
  sensitive = true
}
output "storagecontainer" {
  value = azurerm_storage_container.sacontainer.name
}

#output "k10token" {
#  value     = kubernetes_token_request_v1.k10token.token
#  sensitive = true
#}

output "k10_route_hostname" {
    value = data.kubernetes_resources.k10_route.objects[*].status.ingress[0].host
}

output "k8object" {
    value = "biep" # data.kubernetes_resources.k10_route.objects[*].status.ingress[0].host
}

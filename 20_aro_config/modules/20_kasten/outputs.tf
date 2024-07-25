output "storageaccount" {
  value = azurerm_storage_account.kasten_sa.name

}

output "storageaccount_ak" {
  value     = azurerm_storage_account.kasten_sa.secondary_access_key
  sensitive = true
}

output "storagecontainer" {
  value = azurerm_storage_container.kasten_sa_container.name
}

# output "k8object" {
#   value = "biep" # data.kubernetes_resources.k10_route.objects[*].status.ingress[0].host
# }

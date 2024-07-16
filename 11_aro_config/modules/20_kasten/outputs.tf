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

output "k8object" {
    value = kubernetes_manifest.k10_operator_subscription.object
}

# output "k8object2" {
#     value = data.kubernetes_resources.k10_operator_installplan
# }
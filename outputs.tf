output "storageaccount" {
  value = azurerm_storage_account.sa.name
  
}
output "storageaccount_ak" {
  value = azurerm_storage_account.sa.secondary_access_key 
  sensitive = true
}
output "storagecontainer" {
  value = azurerm_storage_container.sacontainer.name
}

output "aro_kubeconfig_out" {
  value = base64decode(jsondecode(data.azapi_resource_action.aro_kubeconfig.output).kubeconfig)
  sensitive=true
}

output "aro_admin_pass" {
  value = jsondecode(data.azapi_resource_action.aro_adminlogin.output).kubeadminPassword
  sensitive=true
}
output "aro_admin_login" {
  value = jsondecode(data.azapi_resource_action.aro_adminlogin.output).kubeadminUsername
}

output "console_url" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.console_url
}

output "aro_name" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.name
}

output "aro_id" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.id
}

output "aro_rg_name" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.resource_group_name
}


data "azurerm_subscription" "current" {
}


output "subscription" {
  value = data.azurerm_subscription.current.subscription_id
}

output "tenant" {
  value = data.azurerm_subscription.current.tenant_id
}

output "display" {
  value = data.azurerm_subscription.current.display_name
}

output "location" {
  value = azurerm_resource_group.aro_rg.location
}

output "rg" {
  value = azurerm_resource_group.aro_rg.name
}

output "mrgid" {
  value = azurerm_redhat_openshift_cluster.aro_cluster.cluster_profile[0].resource_group_id
}


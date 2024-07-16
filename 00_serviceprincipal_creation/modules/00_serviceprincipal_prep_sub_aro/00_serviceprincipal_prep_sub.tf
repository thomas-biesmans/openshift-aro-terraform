
# Configuring the Azure provider

data "azuread_client_config" "current" {

}

data "azurerm_client_config" "current" {

}

resource "azuread_application" "app_aro" {
  display_name = "${local.projectname}-aro"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "sp_aro" {
  client_id = azuread_application.app_aro.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azurerm_role_assignment" "sp_aro_contributor" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.sp_aro.object_id
}

resource "azuread_service_principal_password" "sp_pw_aro" {
  service_principal_id = azuread_service_principal.sp_aro.object_id
}

resource "local_file" "serviceprincipal_details" {
  depends_on = [
    null_resource.reg_aro,
    azurerm_role_assignment.role_network_own_svp,
    azurerm_role_assignment.role_network_external_redhat_svp
  ]

  filename = "${path.module}/${var.secret_location_dir_relative_to_module}/svp_sub1.cred"
  content = jsonencode({
    tenant_id       = data.azuread_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    client_id       = azuread_application.app_aro.client_id
    client_secret   = azuread_service_principal_password.sp_pw_aro.value
    role            = azurerm_role_assignment.sp_aro_contributor.role_definition_id
  })
  file_permission = "0600"
}


# Registering the Resource Provider for Azure Red Hat OpenShift

# Alternatively, but having this managed by Terraform will screw with destroys if you have multiple clusters: 
# resource "azurerm_resource_provider_registration" "reg-aro" {
#   name = "Microsoft.RedHatOpenShift"
# }

resource "null_resource" "reg_aro" {

  provisioner "local-exec" {
    command = <<EOT
    %{for resource_provider in var.az_resource_providers}
      az provider register --namespace ${resource_provider}
    %{endfor}
    EOT
  }
}

# Reading the Resource Provider for ARO, CLI equivalent:
# az ad sp list --display-name 'Azure Red Hat OpenShift RP' --output json | jq '.[0]["servicePrincipalNames"]'

data "azuread_service_principal" "redhatopenshift" {
  # This is the Azure Red Hat OpenShift RP service principal id managed by Red Hat, do NOT delete it
  client_id  = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
  depends_on = [null_resource.reg_aro]
}


# Ideally the below permissions are set on the vnet you'll be using, but in our Service Principal approach the Service Principal does not have
# the proper permissions to create this role when the ARO cluster is deployed, unless you create the Resource Groups (and possibly the vnets) in
# this module as well.
# In the meantime we'll just grant Network Contributor to the subscription.

resource "azurerm_role_assignment" "role_network_own_svp" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}" # /resourcegroups/${local.projectname}-aro-rg" # azurerm_virtual_network.aro_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_service_principal.sp_aro.object_id
}

resource "azurerm_role_assignment" "role_network_external_redhat_svp" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}" #/resourcegroups/${local.projectname}-aro-rg" # azurerm_virtual_network.aro_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azuread_service_principal.redhatopenshift.object_id
}

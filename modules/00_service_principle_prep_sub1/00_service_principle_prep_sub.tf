
# Configuring the Azure provider

data "azuread_client_config" "current" {

}

data "azurerm_client_config" "current" {

}

resource "azuread_application" "app_aro" {
  display_name = "${local.projectname}-aro-with-owner"
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

resource "local_file" "service_principle_details" {
  filename = "${var.secret_location_dir}/svp_sub1.cred"
  content = jsonencode({
    tenant_id       = data.azuread_client_config.current.tenant_id
    subscription_id = data.azurerm_client_config.current.subscription_id
    client_id       = azuread_application.app_aro.client_id
    client_secret   = azuread_service_principal_password.sp_pw_aro.value
    role            = azurerm_role_assignment.sp_aro_contributor.role_definition_id 
  })
  file_permission = "0600"
}
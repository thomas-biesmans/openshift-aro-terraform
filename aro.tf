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

resource "azuread_service_principal_password" "sp_pw_aro" {
  service_principal_id = azuread_service_principal.sp_aro.object_id
}

//also here :
//https://learn.microsoft.com/en-us/azure/openshift/quickstart-openshift-arm-bicep-template?pivots=aro-arm
//https://cloud.redhat.com/experts/aro/terraform-install/
//https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/redhat_openshift_cluster
//az ad sp list --display-name 'Azure Red Hat OpenShift RP' --output json | jq '.[0]["servicePrincipalNames"]'

data "azuread_service_principal" "redhatopenshift" {
  // This is the Azure Red Hat OpenShift RP service principal id, do NOT delete it
  client_id = "f1dd0a37-89c6-4e07-bcd1-ffd3d43d8875"
}

resource "azurerm_role_assignment" "role_network1" {
  scope                = azurerm_virtual_network.aro_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_service_principal.sp_aro.object_id
}

resource "azurerm_role_assignment" "role_network2" {
  scope                = azurerm_virtual_network.aro_vnet.id
  role_definition_name = "Network Contributor"
  principal_id         = data.azuread_service_principal.redhatopenshift.object_id
}

resource "azurerm_resource_group" "aro_rg" {
  name     = "${local.projectname}-aro-rg"
  tags     = local.tags
  location = var.azlocation
}

resource "azurerm_virtual_network" "aro_vnet" {
  name                = "${local.projectname}-aro-vnet"
  address_space       = ["10.15.12.0/22"]
  location            = azurerm_resource_group.aro_rg.location
  resource_group_name = azurerm_resource_group.aro_rg.name
  tags                = local.tags
}

resource "azurerm_subnet" "main_subnet" {
  name                 = "${local.projectname}-aro-main-subnet"
  resource_group_name  = azurerm_resource_group.aro_rg.name
  virtual_network_name = azurerm_virtual_network.aro_vnet.name
  address_prefixes     = ["10.15.12.0/23"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]

}

resource "azurerm_subnet" "worker_subnet" {
  name                 = "${local.projectname}-aro-worker-subnet"
  resource_group_name  = azurerm_resource_group.aro_rg.name
  virtual_network_name = azurerm_virtual_network.aro_vnet.name
  address_prefixes     = ["10.15.14.0/23"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.ContainerRegistry"]

}

resource "azurerm_redhat_openshift_cluster" "aro_cluster" {
  name                = "${local.projectname}-aro-cluster"
  location            = azurerm_resource_group.aro_rg.location
  resource_group_name = azurerm_resource_group.aro_rg.name
  tags                = local.tags

  cluster_profile {
    domain  = local.domain
    version = "4.14.16"
    # required to get the operator to worker
    # which is import for the kasten operator
    # https://console.redhat.com/openshift/install/azure/aro-provisioned
    pull_secret = data.local_file.pull_secret.content
  }

  network_profile {
    pod_cidr     = "10.128.0.0/14"
    service_cidr = "172.30.0.0/16"
  }

  main_profile {
    vm_size   = "Standard_D8s_v3"
    subnet_id = azurerm_subnet.main_subnet.id
  }

  api_server_profile {
    visibility = "Public"
  }

  ingress_profile {
    visibility = "Public"
  }

  worker_profile {
    vm_size      = "Standard_D4s_v3"
    disk_size_gb = 128
    node_count   = 3
    subnet_id    = azurerm_subnet.worker_subnet.id
  }

  service_principal {
    client_id     = azuread_application.app_aro.client_id
    client_secret = azuread_service_principal_password.sp_pw_aro.value
  }

  depends_on = [
    azurerm_role_assignment.role_network1,
    azurerm_role_assignment.role_network2,
  ]


}

# az aro get-admin-kubeconfig --name MyCluster --resource-group MyResourceGroup --debug
# the date might change if there is an update in the api
data "azapi_resource_action" "aro_kubeconfig" {
  type                   = "Microsoft.RedHatOpenShift/openShiftClusters@2023-09-04"
  resource_id            = azurerm_redhat_openshift_cluster.aro_cluster.id
  action                 = "listAdminCredentials"
  response_export_values = ["*"]

  depends_on = [
    azurerm_redhat_openshift_cluster.aro_cluster
  ]
}

# az aro list-credentials  --name cluster  --resource-group aro-rg --debug
# the date might change if there is an update in the api
data "azapi_resource_action" "aro_adminlogin" {
  type                   = "Microsoft.RedHatOpenShift/openShiftClusters@2023-09-04"
  resource_id            = azurerm_redhat_openshift_cluster.aro_cluster.id
  action                 = "listCredentials"
  response_export_values = ["*"]

  depends_on = [
    azurerm_redhat_openshift_cluster.aro_cluster
  ]
}

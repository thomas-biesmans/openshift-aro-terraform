# Pre-requisites
## Azure Red Hat OpenShift - ARO - supported locations
### Log into Azure with the az CLI
```
az login
```
Use : ```--use-device-code ``` if you're using a remote session.

Select the subscription you want to deploy in.

### Figure out supported locations
The following commands will check:
- The locations your subscription has access to.
- The VM SKUs in western Europe.
- The standard Standard_D8s_v3 SKUs accross all locations in case there are zone limitations (all three zones are needed).
- ARO support in a location.

```
az account list-locations | jq '.[] | .name,.displayName'
az vm list-skus --location westeurope --size Standard_D --all --output table
az vm list-skus --size Standard_D8s_v3 --output table 
az aro get-versions --location westeurope
```

## OpenShift pull secret
Make sure to get an OpenShift pull secret. This is required for deploying OpenShift.
Browse to: https://console.redhat.com/openshift/install/azure/aro-provisioned

Store the secret, the default path is "./input-files/OpenShift-pull-secret/pull-secret.txt"


# Terraform
## Azure Service Principal creation

We'll need service principals. In this example we have to use two different subscriptions:
- One subscription for ARO.
- One subscription that hosts our DNS.

The following roles are needed:
- Contributor

The service principal information is stored as a JSON file:
```
{"client_id":"","client_secret":"","role":"/subscriptions/<subscription ID>/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c","subscription_id":"","tenant_id":""}
```

The default path is "./input-files/azurerm-creds/svp_sub[1-2].cred"

Either get the Service Principal's details & password and store them as a file, or use Terraform to create them:

Init & apply:
```bash
terraform -chdir=00_serviceprincipal_creation init
# if needed for the ARO subscription
terraform -chdir=00_serviceprincipal_creation apply \
  -target=module.azure_serviceprincipal_prep_sub_aro.local_file.serviceprincipal_details \
  -target=module.azure_serviceprincipal_prep_sub_aro.azurerm_role_assignment.role_network_own_svp \
  -target=module.azure_serviceprincipal_prep_sub_aro.azurerm_role_assignment.role_network_external_redhat_svp
# if needed for the DNS subscription, login to the other subscription if needed
az login
terraform -chdir=00_serviceprincipal_creation apply \
  -target=module.azure_serviceprincipal_prep_sub_dns.local_file.serviceprincipal_details
```

Note: Use '--auto-approve' as an option at the end of the apply command to skip confirmation.
-chdir=00_aro_deploy


## Azure Red Hat OpenShift - ARO - deployment

Init & apply:
```bash
terraform -chdir=10_aro_deploy init
terraform -chdir=10_aro_deploy apply
```

Get Kubeconfig:
```bash
terraform -chdir=10_aro_deploy output -raw aro_kubeconfig_out > ~/.kube/config
```

Get login:
```bash
terraform -chdir=10_aro_deploy output -raw console_url
terraform -chdir=10_aro_deploy output -raw aro_admin_login
#terraform output -raw aro_admin_pass 
```

On MAC you can copy the password to your clipboard with pbcopy:
```zsh
open $(terraform output -raw console_url)
terraform output -raw aro_admin_pass | pbcopy
```

## Azure Red Hat OpenShift - ARO - configuration

This includes:
- Kasten deployment

Because Terraform needs a CRD (Custom Resource Definition) to install a CR (Custom Resource), we first have to apply the CRDs / operators using '-target'
Init & apply:
```bash
terraform -chdir=20_aro_config init
# Operator & Kanister first
terraform -chdir=20_aro_config apply -target=module.kasten_crds.data.kubernetes_resources.kasten_operator_completed_installplan
# K10 instance deployment second for remaining CRDs
terraform -chdir=20_aro_config apply -target=module.kasten_instance.kubernetes_manifest.k10_instance
# Full deployment third
terraform -chdir=20_aro_config apply
```

# WIP

Get Storage Account
```bash
terraform output -raw storageaccount
#terraform output -raw storageaccount_ak 
terraform output -raw storagecontainer
```

```zsh
terraform output -raw storageaccount_ak  | pbcopy
```

# If you installed Kasten K10
You can get a token if you used token authentication
```zsh
kubectl create token -n kasten-io k10-k10 --duration=10h
```
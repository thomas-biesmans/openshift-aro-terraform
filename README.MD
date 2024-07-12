# Log into Azure
```
az login 
```
Use : ```--use-device-code ``` if you're using a remote session.

Select the subscription you want to deploy in.


# Figure out support locations
```
az account list-locations | jq '.[] | .name,.displayName'
az aro get-versions --location "eastus"
```

# required to get the operator to worker
Make sure to get a pull secret

Which is import for installing operators for installing Kasten K10
https://console.redhat.com/openshift/install/azure/aro-provisioned

default path is "../pull-secret.txt"

Init
```bash
terraform init
```


terraform apply -target=module.azure_svp_sub1_creation[0].local_file.service_principle_details -var="azure_svp_creation=true"
terraform apply -target=module.azure_svp_sub2_creation[0].local_file.service_principle_details -var="azure_svp_creation=true"

Prefix with 'noglob' if you are using ```zsh``` on Linux.
--auto-approve 







Apply
```bash
terraform apply -var="ownerref=jdoe" -var="owneremail=jdoe@acmecompany.com"
```

Get Kubeconfig
```bash
terraform output -raw  aro_kubeconfig_out > ~/.kube/config
```

Get login
```bash
terraform output -raw console_url
terraform output -raw aro_admin_login
#terraform output -raw aro_admin_pass 
```

On MAC you can copy the password to your clipboard with pbcopy
```zsh
open $(terraform output -raw console_url)
terraform output -raw aro_admin_pass | pbcopy
```

# Storage Account for Kasten K10
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
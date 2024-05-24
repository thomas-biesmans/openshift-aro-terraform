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

Apply
```bash
tofu apply -var="ownerref=jdoe" -var="owneremail=jdoe@acmecompany.com"
```

Get Kubeconfig
```bash
tofu output -raw  aro_kubeconfig_out > ~/.kube/config
```

Get login
```bash
tofu output -raw console_url
tofu output -raw aro_admin_login
#tofu output -raw aro_admin_pass 
```

On MAC you can copy the password to your clipboard with pbcopy
```zsh
open $(tofu output -raw console_url)
tofu output -raw aro_admin_pass | pbcopy
```

# Storage Account for Kasten K10
Get Storage Account

```bash
tofu output -raw storageaccount
#tofu output -raw storageaccount_ak 
tofu output -raw storagecontainer
```

```zsh
tofu output -raw storageaccount_ak  | pbcopy
```

# If you installed Kasten K10
You can get a token if you used token authentication
```zsh
kubectl create token -n kasten-io k10-k10 --duration=10h
```

# OpenShift

resource "kubernetes_namespace" "certmanager" {
  metadata {
    name = var.certmanager["namespace"]
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["openshift.io/sa.scc.mcs"],
      metadata[0].annotations["openshift.io/sa.scc.supplemental-groups"],
      metadata[0].annotations["openshift.io/sa.scc.uid-range"],
      metadata[0].labels
    ]
  }
}

resource "kubernetes_secret" "azuredns_config" {
  metadata {
    name      = "azuredns-config"
    namespace = "cert-manager" # Default for OpenShift when deploying a ClusterIssuer
  }

  data = {
    client-secret = var.svp_sub2_client_secret
  }

  type = "Opaque"
}

resource "kubernetes_manifest" "certmanager_instance" {
  manifest = {

    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "ClusterIssuer"
    "metadata" = {
      "name" = "letsencrypt-prod"
    }
    "spec" = {
      "acme" = {
        "server" = "https://acme-v02.api.letsencrypt.org/directory"
        "email"  = var.certmanager["letsencryptemail"]
        # This key doesn't exist, cert-manager creates it
        "privateKeySecretRef" = {
          "name" = "prod-letsencrypt-issuer-account-key"
        }
        "solvers" = [{
          "dns01" = {
            "azureDNS" = {
              "clientID" = var.svp_sub2_client_id
              "clientSecretSecretRef" = {
                "name" = kubernetes_secret.azuredns_config.metadata[0].name
                "key"  = "client-secret"
              }
              "subscriptionID"    = var.svp_sub2_subscription_id
              "tenantID"          = var.svp_sub2_tenant_id
              "resourceGroupName" = var.azure_dns_zone["resource_group_name"]
              "hostedZoneName"    = var.azure_dns_zone["domain_name"]
              "environment"       = "AzurePublicCloud"
            }
          }
        }]
      }
    }
  }
}

resource "null_resource" "wait_for_issuer_to_become_ready" {
  depends_on = [kubernetes_manifest.certmanager_instance]

  lifecycle {
    replace_triggered_by = [kubernetes_manifest.certmanager_instance]
  }
  
  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      result=$(oc get clusterissuer letsencrypt-prod -n ${var.certmanager["namespace"]} -o json)
      if echo $result | jq -r ".items[].status.conditions[].Status" | grep -qE "^$"; then
        echo "Waiting for clusterissuer to be created..."
        sleep 5
      elif echo $result | jq -r ".items[].status.conditions[].Status" | grep -qv "True"; then
        echo "Waiting for clusterissuer become Ready..."
        sleep 5
      else
        condition=true
        echo "clusterissuer is Ready"
      fi
    EOT
  }
}

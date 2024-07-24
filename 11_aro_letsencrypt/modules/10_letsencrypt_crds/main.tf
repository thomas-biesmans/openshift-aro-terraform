
# OpenShift

resource "kubernetes_namespace" "certmanager_operator" {
  metadata {
    name = var.certmanager_operator["namespace"]
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

resource "kubernetes_manifest" "certmanager_operator_operatorgroup" {
  depends_on = [kubernetes_namespace.certmanager_operator]

  manifest = {
    "apiVersion" = "operators.coreos.com/v1"
    "kind"       = "OperatorGroup"
    "metadata" = {
      "name"      = var.certmanager_operator["name"]
      "namespace" = var.certmanager_operator["namespace"]
    }
    "spec" = {
      "targetNamespaces" : [
        var.certmanager_operator["namespace"]
      ]
      "upgradeStrategy" = "Default"
    }
  }
}

resource "kubernetes_manifest" "certmanager_operator_subscription" {
  depends_on = [kubernetes_manifest.certmanager_operator_operatorgroup]

  manifest = {
    "apiVersion" = "operators.coreos.com/v1alpha1"
    "kind"       = "Subscription"
    "metadata" = {
      "name"      = var.certmanager_operator["name"]
      "namespace" = var.certmanager_operator["namespace"]
    }
    "spec" = {
      "channel"             = var.certmanager_operator["channel"]
      "installPlanApproval" = var.certmanager_operator["installPlanApproval"]
      "name"                = var.certmanager_operator["name"]
      "source"              = var.certmanager_operator["source"]
      "sourceNamespace"     = var.certmanager_operator["sourceNamespace"]
      "startingCSV"         = var.certmanager_operator["startingCSV"] != "" ? var.certmanager_operator["startingCSV"] : ""
    }
  }

  wait {
    condition {
      type   = "CatalogSourcesUnhealthy"
      status = "False"
    }
  }
}

resource "null_resource" "wait_for_certmanager_installplans_to_become_available" {
  depends_on = [kubernetes_manifest.certmanager_operator_subscription]

  lifecycle {
    replace_triggered_by = [kubernetes_manifest.certmanager_operator_subscription]
  }

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      condition=false
      until $condition; do
        result=$(oc get installplan -n ${var.certmanager_operator["namespace"]} -o json | jq -r ".items[].status.phase")
        if echo $result | grep -qE "^$"; then
          echo "Waiting for installplans to be created..."
          sleep 5
        elif echo $result | grep -qv "Complete"; then
          echo "Waiting for installplans' phases to become Complete..."
          sleep 5
        else
          condition=true
          echo "Installplans' phases are Complete"
        fi
      done
    EOT
  }
}

data "kubernetes_resources" "certmanager_operator_completed_installplan" {
  depends_on = [null_resource.wait_for_certmanager_installplans_to_become_available]

  api_version = "operators.coreos.com/v1alpha1"
  kind        = "InstallPlan"
  namespace   = var.certmanager_operator["namespace"]
}

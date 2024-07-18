
# OpenShift

resource "kubernetes_namespace" "k10_operator" {
  metadata {
    name = var.k10_operator["namespace"]
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

resource "kubernetes_manifest" "k10_operator_operatorgroup" {
  depends_on = [kubernetes_namespace.k10_operator]

  manifest = {
    "apiVersion" = "operators.coreos.com/v1"
    "kind"       = "OperatorGroup"
    "metadata" = {
      "name"      = var.k10_operator["name"]
      "namespace" = var.k10_operator["namespace"]
    }
    "spec" = {
      "targetNamespaces" : [
        var.k10_operator["namespace"]
      ]
      "upgradeStrategy" = "Default"
    }
  }
}

resource "kubernetes_manifest" "k10_operator_subscription" {
  depends_on = [kubernetes_manifest.k10_operator_operatorgroup]

  manifest = {
    "apiVersion" = "operators.coreos.com/v1alpha1"
    "kind"       = "Subscription"
    "metadata" = {
      "name"      = var.k10_operator["name"]
      "namespace" = var.k10_operator["namespace"]
    }
    "spec" = {
      "channel"             = var.k10_operator["channel"]
      "installPlanApproval" = var.k10_operator["installPlanApproval"]
      "name"                = var.k10_operator["name"]
      "source"              = var.k10_operator["source"]
      "sourceNamespace"     = var.k10_operator["sourceNamespace"]
      "startingCSV"         = var.k10_operator["startingCSV"]
    }
  }

  wait {
    condition {
      type   = "CatalogSourcesUnhealthy"
      status = "False"
    }
  }
  # wait {
  #   fields = {
  #     "status.installplan.name" = "^installplan-" # Status is not included...
  #   }
  # }
}

# data "kubernetes_manifest" "k10_operator_csv" {
#   depends_on = [kubernetes_manifest.k10_operator_subscription]
# 
#   manifest = {
#     "apiVersion" = "operators.coreos.com/v1alpha1"
#     "kind"       = "ClusterServiceVersion"
#     "metadata" = {
#       "name"      = var.k10_operator["startingCSV"]
#       "namespace" = var.k10_operator["namespace"]
#     }
#     "spec" = {
#       "displayName" = 
#     }
#   }
# 
#   wait {
#     fields = {
#       "status.phase" = "Succeeded"
#     }
#   }
# }

resource "null_resource" "wait_for_installplans_to_become_available" {
  depends_on = [kubernetes_manifest.k10_operator_subscription]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      condition=false
      until $condition; do
        result=$(oc get installplan -n ${var.k10_operator["namespace"]} -o json | jq -r ".items[].status.phase")
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

data "kubernetes_resources" "wait_for_operators_installplans_to_become_complete" {
  depends_on = [null_resource.wait_for_installplans_to_become_available]

  api_version = "operators.coreos.com/v1alpha1"
  kind        = "InstallPlan"
  namespace   = "${var.k10_operator["namespace"]}"
}

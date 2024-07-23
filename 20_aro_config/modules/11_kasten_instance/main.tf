
# OpenShift

resource "kubernetes_manifest" "k10_instance" {
  manifest = {
    "apiVersion" = "apik10.kasten.io/v1alpha1"
    "kind"       = "K10"
    "metadata" = {
      "annotations" = {
        "helm.sdk.operatorframework.io/rollback-force" = false
      }
      "name" = var.k10["name"]
      "labels" = {
        "prodlevel" = "backup"
      }
      "namespace" = var.k10["namespace"]
    }
    "spec" = {
      "auth" = {
        "basicAuth" = {
          "enabled"    = false
          "htpasswd"   = ""
          "secretName" = ""
        }
        "tokenAuth" = {
          "enabled" = true
        }
      }
      "global" = {
        "persistence" = {
          "catalog" = {
            "size" = "20Gi"
          }
          "storageClass" = ""
        }
      }
      "metering" = {
        "mode" = ""
      }
      "route" = {
        "enabled" = true
        "host"    = ""
        "tls" = {
          "enabled" = true
        }
      }
    }
  }
}

resource "null_resource" "wait_for_route_to_become_available" {
  depends_on = [kubernetes_manifest.k10_instance]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      until oc get route k10-route -n ${var.k10["namespace"]} -o jsonpath='{.status.ingress[*].host}' | grep -qe '.*'; do
        echo 'Waiting for route hostname to become available...'
        sleep 2
      done
      echo 'Route hostname is available'
    EOT
  }
}

data "kubernetes_resource" "k10_route" {
  depends_on = [null_resource.wait_for_route_to_become_available]

  api_version = "route.openshift.io/v1"
  kind        = "Route"

  metadata {
    name      = "k10-route"
    namespace = var.k10["namespace"]
  }
  # namespace   = var.k10["namespace"]

}

# Helm alternative
# resource "helm_release" "k10" {
#   depends_on = [kubernetes_namespace.stock]
# 
#   name             = "k10"
#   namespace        = var.k10["namespace"]
#   create_namespace = false
# 
#   repository = "kasten/k10"
#   chart      = "k10"
# 
#   set {
#     name  = "secrets.awsAccessKeyId"
#     value = "root"
#   }
# 
#   set {
#     name  = "secrets+.awsSecretAccessKey"
#     value = "notsecure"
#   }
# 
# }

resource "null_resource" "wait_for_serviceaccount_to_become_available" {
  depends_on = [kubernetes_manifest.k10_instance]

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      until oc get serviceaccount k10-k10 -o json | jq -r ".metadata.name" | grep -qe ".*"; do
        echo "Waiting for service account to become available..."
        sleep 2
      done
      echo "Service account is available"
    EOT
  }
}

resource "kubernetes_token_request_v1" "k10token" {
  depends_on = [null_resource.wait_for_serviceaccount_to_become_available]

  metadata {
    name      = "k10-k10"
    namespace = var.k10["namespace"]
  }
  spec {
    expiration_seconds = 36 * 3600
  }
}

resource "kubernetes_config_map_v1" "k10-eula-info" {
  metadata {
    name      = "k10-eula-info"
    namespace = var.k10["namespace"]
  }

  data = {
    accepted = "true"
    company  = split("@", var.owneremail)[1]
    email    = var.owneremail
  }
}


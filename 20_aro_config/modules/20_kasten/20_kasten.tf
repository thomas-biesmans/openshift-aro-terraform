# Azure

resource "random_string" "randomsa" {
  length  = 6
  special = false
  upper   = false
  numeric = true
  lower   = true
}

data "azurerm_resource_group" "aro_rg" {
  name = "${local.projectname}-aro-rg"
}

resource "azurerm_storage_account" "sa" {
  name                            = format("%s%s", var.ownerref, random_string.randomsa.result)
  resource_group_name             = data.azurerm_resource_group.aro_rg.name
  location                        = data.azurerm_resource_group.aro_rg.location
  account_tier                    = var.azure_storage_account["tier"]
  account_replication_type        = var.azure_storage_account["replication_type"]
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false
  tags                            = data.azurerm_resource_group.aro_rg.tags
}

resource "azurerm_storage_container" "sacontainer" {
  name                  = "k10"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}


# OpenShift

resource "kubernetes_manifest" "k10_instance" {
  manifest = {
    "apiVersion" = "apik10.kasten.io/v1alpha1"
    "kind" = "K10"
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
          "enabled" = false
          "htpasswd" = ""
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
        "host" = ""
        "tls" = {
          "enabled" = false
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

data "kubernetes_resources" "k10_route" {
  depends_on = [null_resource.wait_for_route_to_become_available]

  api_version = "route.openshift.io/v1"
  kind        = "Route"
  namespace   = var.k10["namespace"]

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

resource "kubernetes_manifest" "bppostgres" {
  depends_on = [kubernetes_manifest.k10_instance]

  manifest = {
    apiVersion = "cr.kanister.io/v1alpha1"
    kind       = "Blueprint"

    metadata = {
      name = "postgresql-hooks"
      namespace = var.k10["namespace"]
    }

    actions = {
       backupPrehook = {
            name = ""
            kind = ""
            phases = [
                {
                    func = "KubeExec"
                    name = "makePGCheckPoint"
                    args = {
                        command = [
                            "bash","-o","errexit","-o","pipefail","-c","PGPASSWORD=$${POSTGRES_POSTGRES_PASSWORD} psql -d $${POSTGRES_DATABASE} -U postgres -c \"CHECKPOINT;\""
                        ]
                        container = "postgresql"
                        namespace = "{{ .StatefulSet.Namespace }}"
                        pod= "{{ index .StatefulSet.Pods 0 }}"
                    }
                }
            ]
       } 
    }
  }
}

resource "kubernetes_manifest" "transformreplica" {
  depends_on = [kubernetes_manifest.k10_instance]

  manifest = {
      kind = "TransformSet"
      apiVersion = "config.kio.kasten.io/v1alpha1"

      metadata = {
        name = "stockupdate"
        namespace = var.k10["namespace"]
      }
      spec = {
        transforms = [
          {
           subject = {
            group= "apps"
            resource= "deployments"
           }
           name= "replicaupdate"
           json = [
            {
              op= "replace"
              path= "/spec/replicas"
              value= 0
            }
           ]
          },
        ]
      }
  }
}

resource "kubernetes_manifest" "bpbinding" {
  depends_on = [kubernetes_manifest.bppostgres]

  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "BlueprintBinding"

    metadata = {
      name = "postgres-blueprint-binding"
      namespace = var.k10["namespace"]
    }

    spec = {
        blueprintRef = {
            name = "postgresql-hooks"
            namespace = var.k10["namespace"]
        }
        resources = {
            matchAll = [
                {
                    type = {
                        operator = "In"
                        values = [
                            {
                                group = "apps"
                                resource = "statefulsets"
                            }
                        ]
                    }
                },
                {
                    annotations = {
                        key = "kanister.kasten.io/blueprint"
                        operator = "DoesNotExist"
                    }
                },
                {
                    "labels"= {
                        key= "app.kubernetes.io/name"
                        operator= "In"
                        values= ["postgresql"]
                    }
                }
            ]
        }
    }
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


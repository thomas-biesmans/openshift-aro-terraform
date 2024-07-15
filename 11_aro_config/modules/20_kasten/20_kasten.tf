# Azure

resource "random_string" "randomsa" {
  length  = 6
  special = false
  upper   = false
  numeric = true
  lower   = true
}

data "azurerm_resource_group" "aro_rg" {
  name = var.azurerm_resource_group.name
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

resource "kubernetes_namespace" "kasten-io" {
  metadata {
    name = var.k10_namespace

    labels = {
      prodlevel = "backup"
    }
  }

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["openshift.io/sa.scc.mcs"],
      metadata[0].annotations["openshift.io/sa.scc.supplemental-groups"],
      metadata[0].annotations["openshift.io/sa.scc.uid-range"]
    ]
  }
}


resource "kubernetes_namespace" "k10_operator" {
  metadata {
    name = var.k10_operator["namespace"]
  }
}

resource "kubernetes_manifest" "k10_operator_operatorgroup" {
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

resource "kubernetes_manifest" "k10_operator_csv" {
  depends_on = [kubernetes_manifest.k10_operator_subscription]

  manifest = {
    "apiVersion" = "operators.coreos.com/v1alpha1"
    "kind"       = "ClusterServiceVersion"
    "metadata" = {
      "name"      = var.k10_operator["startingCSV"]
      "namespace" = var.k10_operator["namespace"]
    }
  }

  wait {
    fields = {
      "status.phase" = "Succeeded"
    }
  }
}

data "kubernetes_resources" "k10_operator_installplan" {
  depends_on = [kubernetes_manifest.k10_operator_subscription]

  api_version = "operators.coreos.com/v1alpha1"
  kind        = "InstallPlan"
  field_selector = "metadata.namespace==${var.k10_operator["namespace"]}"

  #wait {
  #  fields = {
  #    "status.phase" = "Complete"
  #  }
  #}
}

# data "kubernetes_resource" "k10_operator_installplan" {
#   depends_on = [kubernetes_manifest.k10_operator_subscription]
# 
#   api_version = "operators.coreos.com/v1alpha1"
#   kind        = "InstallPlan"
#   metadata {
#     name      = kubernetes_manifest.k10_operator_subscription.object.status.installplan.name
#     namespace = var.k10_operator["namespace"]
#   }
# 
#   #wait {
#   #  fields = {
#   #    "status.phase" = "Complete"
#   #  }
#   #}
# }

# resource "helm_release" "k10" {
#   depends_on = [kubernetes_namespace.stock]
# 
#   name             = "k10"
#   namespace        = var.k10_namespace
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

# resource "kubernetes_token_request_v1" "k10token" {
#   depends_on = [data.kubernetes_resource.k10_operator_installplan]
#   metadata {
#     name      = "k10-k10"
#     namespace = var.k10_namespace
#   }
#   spec {
#     expiration_seconds = 36 * 3600
#   }
# }

# resource "kubernetes_manifest" "bppostgres" {
#   depends_on = [helm_release.k10]
#   manifest = {
#     apiVersion = "cr.kanister.io/v1alpha1"
#     kind       = "Blueprint"
# 
#     metadata = {
#       name = "postgresql-hooks"
#       namespace = var.k10_namespace
#     }
# 
#     actions = {
#        backupPrehook = {
#             name = ""
#             kind = ""
#             phases = [
#                 {
#                     func = "KubeExec"
#                     name = "makePGCheckPoint"
#                     args = {
#                         command = [
#                             "bash","-o","errexit","-o","pipefail","-c","PGPASSWORD=$${POSTGRES_POSTGRES_PASSWORD} psql -d $${POSTGRES_DATABASE} -U postgres -c \"CHECKPOINT;\""
#                         ]
#                         container = "postgresql"
#                         namespace = "{{ .StatefulSet.Namespace }}"
#                         pod= "{{ index .StatefulSet.Pods 0 }}"
#                     }
#                 }
#             ]
#        } 
#     }
#   }
# }
# 
# resource "kubernetes_manifest" "transformreplica" {
#   depends_on = [helm_release.k10]
#   manifest = {
#       kind = "TransformSet"
#       apiVersion = "config.kio.kasten.io/v1alpha1"
# 
#       metadata = {
#         name = "stockupdate"
#         namespace = var.k10_namespace
#       }
#       spec = {
#         transforms = [
#           {
#            subject = {
#             group= "apps"
#             resource= "deployments"
#            }
#            name= "replicaupdate"
#            json = [
#             {
#               op= "replace"
#               path= "/spec/replicas"
#               value= 0
#             }
#            ]
#           },
#         ]
#       }
#   }
# }
# 
# resource "kubernetes_manifest" "bpbinding" {
#   depends_on = [
#     kubernetes_manifest.bppostgres
#   ]
# 
#   manifest = {
#     apiVersion = "config.kio.kasten.io/v1alpha1"
#     kind       = "BlueprintBinding"
# 
#     metadata = {
#       name = "postgres-blueprint-binding"
#       namespace = var.k10_namespace
#     }
# 
#     spec = {
#         blueprintRef = {
#             name = "postgresql-hooks"
#             namespace = var.k10_namespace
#         }
#         resources = {
#             matchAll = [
#                 {
#                     type = {
#                         operator = "In"
#                         values = [
#                             {
#                                 group = "apps"
#                                 resource = "statefulsets"
#                             }
#                         ]
#                     }
#                 },
#                 {
#                     annotations = {
#                         key = "kanister.kasten.io/blueprint"
#                         operator = "DoesNotExist"
#                     }
#                 },
#                 {
#                     "labels"= {
#                         key= "app.kubernetes.io/name"
#                         operator= "In"
#                         values= ["postgresql"]
#                     }
#                 }
#             ]
#         }
#     }
#   }
# }

resource "kubernetes_config_map_v1" "k10-eula-info" {
  metadata {
    name      = "k10-eula-info"
    namespace = var.k10_namespace
  }

  data = {
    accepted = "true"
    company  = split("@", var.owneremail)[1]
    email    = var.owneremail
  }
}


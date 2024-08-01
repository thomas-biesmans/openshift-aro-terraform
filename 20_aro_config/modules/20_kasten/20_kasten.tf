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

resource "azurerm_storage_account" "kasten_sa" {
  name                            = format("%s%s", var.ownerref, random_string.randomsa.result)
  resource_group_name             = data.azurerm_resource_group.aro_rg.name
  location                        = var.azlocation
  account_tier                    = var.azure_storage_account["tier"]
  account_replication_type        = var.azure_storage_account["replication_type"]
  shared_access_key_enabled       = true
  allow_nested_items_to_be_public = false
  tags                            = data.azurerm_resource_group.aro_rg.tags
}

resource "azurerm_storage_container" "kasten_sa_container" {
  name                  = "k10-demoapp"
  storage_account_name  = azurerm_storage_account.kasten_sa.name
  container_access_type = "private"
}

# data "azurerm_storage_account_sas" "kasten_sa_container" {
#   connection_string = azurerm_storage_account.kasten_sa.primary_connection_string
#   https_only        = true
# 
#   resource_types {
#     service   = true
#     container = false
#     object    = false
#   }
# 
#   services {
#     blob  = true
#     queue = false
#     table = false
#     file  = false
#   }
# 
#   start  = "2024-01-01"
#   expiry = "2025-12-31"
# 
#   permissions {
#     read    = true
#     write   = true
#     delete  = true
#     list    = true
#     add     = true
#     create  = true
#     update  = true
#     process = true
#     tag     = false
#     filter  = false
#   }
# }

# OpenShift

# resource "kubernetes_manifest" "blueprint_progress" {
#   manifest = {
#     apiVersion = "cr.kanister.io/v1alpha1"
#     kind       = "Blueprint"
# 
#     metadata = {
#       name      = "postgresql-hooks"
#       namespace = var.k10["namespace"]
#     }
# 
#     actions = {
#       backupPrehook = {
#         name = ""
#         kind = ""
#         phases = [
#           {
#             func = "KubeExec"
#             name = "makePGCheckPoint"
#             args = {
#               command = [
#                 "bash", "-o", "errexit", "-o", "pipefail", "-c", "PGPASSWORD=$${POSTGRES_POSTGRES_PASSWORD} psql -d $${POSTGRES_DATABASE} -U postgres -c \"CHECKPOINT;\""
#               ]
#               container = "postgresql"
#               namespace = "{{ .StatefulSet.Namespace }}"
#               pod       = "{{ index .StatefulSet.Pods 0 }}"
#             }
#           }
#         ]
#       }
#     }
#   }
# }


resource "kubernetes_manifest" "blueprint_progress" {
  manifest = {
    apiVersion = "cr.kanister.io/v1alpha1"
    kind       = "Blueprint"

    metadata = {
      name      = "postgresql-hooks"
      namespace = var.k10["namespace"]
    }

    actions = {
      backupPrehook = {
        phases = [
          {
            func = "KubeExec"
            name = "makePGCheckPoint"
            args = {
              namespace = "{{ .StatefulSet.Namespace }}"
              pod       = "{{ index .StatefulSet.Pods 0 }}"
              container = "postgresql"
              command = [
                "bash", "-o", "errexit", "-o", "pipefail", "-c", "PGPASSWORD=$${POSTGRES_POSTGRES_PASSWORD} psql -d $${POSTGRES_DATABASE} -U postgres -c \"select pg_backup_start('app_cons', fast:=true);\"" # pg_start_backup pre PostgreSQL 15
              ]
            }
          }
        ]
      }
      # Per https://pgpedia.info/c/checkpoint.html the posthook is not needed. The prehook creates a checkpoint and the backup is then aborted when the connection is closed.
      # backupPosthook = {
      #   phases = [
      #     {
      #       func = "KubeExec"
      #       name = "afterPGBackup"
      #       args = {
      #         namespace = "{{ .StatefulSet.Namespace }}"
      #         pod       = "{{ index .StatefulSet.Pods 0 }}"
      #         container = "postgresql"
      #         command = [
      #           "bash", "-o", "errexit", "-o", "pipefail", "-c", "PGPASSWORD=$${POSTGRES_POSTGRES_PASSWORD} psql -d $${POSTGRES_DATABASE} -U postgres -c \"select pg_backup_stop();\"" # pg_stop_backup pre PostgreSQL 15
      #         ]
      #       }
      #     }
      #   ]
      # }
    }
  }
}

resource "kubernetes_manifest" "transformreplica" {
  manifest = {
    kind       = "TransformSet"
    apiVersion = "config.kio.kasten.io/v1alpha1"

    metadata = {
      name      = "stockupdate"
      namespace = var.k10["namespace"]
    }
    spec = {
      transforms = [
        {
          subject = {
            group    = "apps"
            resource = "deployments"
          }
          name = "replicaupdate"
          json = [
            {
              op    = "replace"
              path  = "/spec/replicas"
              value = 0
            }
          ]
        },
      ]
    }
  }
}

resource "kubernetes_manifest" "blueprint_binding_progress" {
  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "BlueprintBinding"

    metadata = {
      name      = "postgres-hooks"
      namespace = var.k10["namespace"]
    }

    spec = {
      blueprintRef = {
        name      = "postgresql-hooks"
        namespace = var.k10["namespace"]
      }
      resources = {
        matchAll = [
          {
            type = {
              operator = "In"
              values   = [
                {
                  group    = "apps"
                  version  = "v1"
                  resource = "statefulsets"
                }
              ]
            }
          },
          {
            annotations = {
              key      = "kanister.kasten.io/blueprint"
              operator = "DoesNotExist"
            }
          },
          {
            "labels" = {
              key      = "app.kubernetes.io/name"
              operator = "In"
              values   = ["postgresql"]
            }
          }
        ]
      }
    }
  }
}

resource "kubernetes_secret" "azure_storageaccount" {
  metadata {
    name      = "kasten-sas-token-secret"
    namespace = var.k10["namespace"]
  }

  data = {
    azure_storage_account_id  = azurerm_storage_account.kasten_sa.name
    azure_storage_environment = "AzurePublicCloud"
    azure_storage_key         = azurerm_storage_account.kasten_sa.primary_access_key
    # data.azurerm_storage_account_sas.kasten_sa_container.sas
  }

  type = "Opaque"
}

resource "kubernetes_manifest" "kasten_location" {
  # Per: https://docs.kasten.io/latest/api/profiles.html#create-an-object-store-location-profile, which doesn't seem to match properly with 7.0.4

  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "Profile"
    metadata = {
      name      = "azure-blob-storage-profile"
      namespace = var.k10["namespace"]
    }
    spec = {
      type = "Location"
      locationSpec = {
        credential = {
          secretType = "AzStorageAccount"
          secret = {
            apiVersion = "v1"
            kind       = "secret"
            name       = kubernetes_secret.azure_storageaccount.metadata[0].name
            namespace  = var.k10["namespace"]
          }
        }
        type = "ObjectStore"
        objectStore = {
          objectStoreType = "AZ" # Not Azure
          name            = azurerm_storage_container.kasten_sa_container.name
        }
        infraPortable = "False"
      }
    }
  }
}

resource "kubernetes_manifest" "volume_snapshot_class_azure_disk_csi" {
  manifest = {
    apiVersion = "snapshot.storage.k8s.io/v1"
    kind       = "VolumeSnapshotClass"
    metadata = {
      name = "csi-azuredisk-vsc-kasten"
      annotations = {
        "k10.kasten.io/is-snapshot-class" = "true"
      }
    }
    driver         = "disk.csi.azure.com"
    deletionPolicy = "Delete"
  }
}

resource "kubernetes_manifest" "backup_policy" {
  depends_on = [kubernetes_manifest.volume_snapshot_class_azure_disk_csi]

  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "Policy"

    metadata = {
      name      = "demoapp-backup-policy"
      namespace = var.k10["namespace"]
    }

    spec = {
      comment   = "Backup policy for the demoapp"
      frequency = "@hourly"
      retention = {
        hourly = 24
        daily  = 7
      }
      actions = [
        { action = "backup" }
      ]
      selector = {
        matchLabels = {
          "k10.kasten.io/appNamespace" = kubernetes_namespace.stock.metadata[0].name
        }
      }
    }
  }
  field_manager {
    force_conflicts = true
  }
}

resource "kubernetes_manifest" "backup_policy_with_export" {
  depends_on = [
    kubernetes_manifest.volume_snapshot_class_azure_disk_csi,
    kubernetes_manifest.kasten_location
  ]

  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "Policy"

    metadata = {
      name      = "demoapp-backup-policy-export"
      namespace = var.k10["namespace"]
    }

    spec = {
      comment   = "Backup policy for the demoapp"
      frequency = "@hourly"
      retention = {
        hourly = 24
        daily  = 7
      }
      actions = [
        {
          action = "backup"
          backupParameters = {
            profile = {
              name      = "azure-blob-storage-profile"
              namespace = var.k10["namespace"]
            }
            imageRepoProfile = {
              name      = "azure-blob-storage-profile"
              namespace = var.k10["namespace"]
            }
            # Kanister blueprint hooks should not be put here, they attach through bindings
            # hooks = {
            #   preHook = {
            #     actionName = "backupPrehook"
            #     blueprint  = "postgresql-hooks"
            #   }
            #   onSuccess = {
            #     actionName = "backupPosthook"
            #     blueprint  = "postgresql-hooks"
            #   }
            #   onFailure = {
            #     actionName = "backupPosthook"
            #     blueprint  = "postgresql-hooks"
            #   }
            # }
            filters = {}
          }
        },
        {
          action = "export"
          exportParameters = {
            frequency = "@daily"
            migrationToken = {
              name      = ""
              namespace = ""
            }
            profile = {
              name      = "azure-blob-storage-profile"
              namespace = var.k10["namespace"]
            }
            receiveString = ""
            exportData = {
              enabled = true
            }
            retention = {
              daily   = 7
              weekly  = 0
              monthly = 0
              yearly  = 0
            }
          }
        }
      ]
      selector = {
        matchExpressions = [
          {
            key      = "k10.kasten.io/appNamespace"
            operator = "In"
            values   = [kubernetes_namespace.stock.metadata[0].name]
          }
        ]
      }
    }
  }
  field_manager {
    force_conflicts = true
  }

  # The following values cannot be ignored through the lifecycle, so adding them as computed_fields per https://github.com/hashicorp/terraform-provider-kubernetes/issues/1378
  computed_fields = [
    "spec.actions[1].exportParameters.migrationToken",
    "spec.actions[1].exportParameters.receiveString"
  ]
  # lifecycle {
  #   ignore_changes = [
  #     manifest.spec.actions[1].exportParameters.migrationToken,
  #     manifest.spec.actions[1].exportParameters.receiveString
  #   ]
  # }
}

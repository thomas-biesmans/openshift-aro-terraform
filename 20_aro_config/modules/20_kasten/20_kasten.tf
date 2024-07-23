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

resource "kubernetes_manifest" "bppostgres" {
  # depends_on = [kubernetes_manifest.k10_instance]

  manifest = {
    apiVersion = "cr.kanister.io/v1alpha1"
    kind       = "Blueprint"

    metadata = {
      name      = "postgresql-hooks"
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
                "bash", "-o", "errexit", "-o", "pipefail", "-c", "PGPASSWORD=$${POSTGRES_POSTGRES_PASSWORD} psql -d $${POSTGRES_DATABASE} -U postgres -c \"CHECKPOINT;\""
              ]
              container = "postgresql"
              namespace = "{{ .StatefulSet.Namespace }}"
              pod       = "{{ index .StatefulSet.Pods 0 }}"
            }
          }
        ]
      }
    }
  }
}

resource "kubernetes_manifest" "transformreplica" {
  # depends_on = [kubernetes_manifest.k10_instance]

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

resource "kubernetes_manifest" "bpbinding" {
  # depends_on = [kubernetes_manifest.bppostgres]

  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "BlueprintBinding"

    metadata = {
      name      = "postgres-blueprint-binding"
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
              values = [
                {
                  group    = "apps"
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


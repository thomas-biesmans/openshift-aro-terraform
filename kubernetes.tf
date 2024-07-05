locals {
  aro_kubeconfig = yamldecode(base64decode(jsondecode(data.azapi_resource_action.aro_kubeconfig.output).kubeconfig))
}



provider "kubernetes" {
  host                   = local.aro_kubeconfig.clusters[0].cluster.server
  client_certificate     = base64decode(local.aro_kubeconfig.users[0].user.client-certificate-data)
  client_key             = base64decode(local.aro_kubeconfig.users[0].user.client-key-data)
  cluster_ca_certificate = ""
}


provider "helm" {
  kubernetes {
    host                   = local.aro_kubeconfig.clusters[0].cluster.server
    client_certificate     = base64decode(local.aro_kubeconfig.users[0].user.client-certificate-data)
    client_key             = base64decode(local.aro_kubeconfig.users[0].user.client-key-data)
    cluster_ca_certificate = ""
  }
}


resource "kubernetes_namespace" "kastenions" {
  depends_on = [data.azapi_resource_action.aro_kubeconfig, azurerm_redhat_openshift_cluster.aro_cluster]

  metadata {
    name = "kasten-io"

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


resource "kubernetes_namespace" "hr" {
  depends_on = [data.azapi_resource_action.aro_kubeconfig, azurerm_redhat_openshift_cluster.aro_cluster]

  metadata {
    name = "hr"

    labels = {
      prodlevel = "gold"
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


resource "kubernetes_namespace" "stock" {
  depends_on = [data.azapi_resource_action.aro_kubeconfig, azurerm_redhat_openshift_cluster.aro_cluster]

  metadata {
    name = "stock"

    labels = {
      prodlevel = "gold"
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

resource "helm_release" "stockgres" {
  depends_on = [kubernetes_namespace.stock]

  name             = "stockdb"
  namespace        = kubernetes_namespace.stock.metadata[0].name
  create_namespace = false

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"

  set {
    name  = "global.postgresql.auth.username"
    value = "root"
  }

  set {
    name  = "global.postgresql.auth.password"
    value = "notsecure"
  }

  set {
    name  = "global.postgresql.auth.database"
    value = "stock"
  }
}

resource "kubernetes_config_map" "stockcm" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name      = "stock-demo-configmap"
    namespace = kubernetes_namespace.stock.metadata[0].name
  }

  data = {
    "initinsert.psql" = "${file("${path.module}/initinsert.psql")}"
  }
}

resource "kubernetes_deployment" "stock-deploy" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name      = "stock-demo-deploy"
    namespace = kubernetes_namespace.stock.metadata[0].name
    labels = {
      app = "stock-demo"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "stock-demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "stock-demo"
        }
      }

      spec {
        volume {
          name = "config"
          config_map {
            name = "stock-demo-configmap"
          }
        }
        container {
          image = "tdewin/stock-demo"
          name  = "stock-demo"
          port {
            name           = "stock-demo"
            container_port = "8080"
            protocol       = "TCP"
          }
          volume_mount {
            name       = "config"
            mount_path = "/var/stockdb"
            read_only  = true
          }
          env {
            name  = "POSTGRES_DB"
            value = "stock"
          }

          env {
            name  = "POSTGRES_SERVER"
            value = "stockdb-postgresql"
          }

          env {
            name  = "POSTGRES_USER"
            value = "root"
          }
          env {
            name  = "POSTGRES_PORT"
            value = "5432"
          }
          env {
            name  = "ADMINKEY"
            value = "unlock"
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key  = "password"
                name = "stockdb-postgresql"
              }
            }
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "stock-demo-svc" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name      = "stock-demo-svc"
    namespace = kubernetes_namespace.stock.metadata[0].name
    labels = {
      app = "stock-demo"
    }
  }
  spec {
    selector = {
      app = "stock-demo"
    }

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}


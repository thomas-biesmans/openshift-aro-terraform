resource "kubernetes_namespace" "hr" {
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

  # Initializing a new instance through .sql, .sh, or .sql.gz files, per https://github.com/bitnami/charts/blob/main/bitnami/postgresql/README.md#initialize-a-fresh-instance
  set {
    name  = "primary.initdb.scriptsConfigMap"
    value = kubernetes_config_map.sql_init_insert.metadata[0].name
  }
}

resource "kubernetes_config_map" "sql_init_insert" {
  depends_on = [kubernetes_namespace.stock]

  metadata {
    name      = "stock-demo-initinsert"
    namespace = kubernetes_namespace.stock.metadata[0].name
  }

  data = {
    "initinsert.sql" = data.local_file.initinsert.content
  }
}

resource "kubernetes_deployment" "stock-deploy" {
  depends_on = [helm_release.stockgres]

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
            name = "stock-demo-initinsert"
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

resource "kubernetes_manifest" "stockroute" {
  depends_on = [kubernetes_namespace.stock]
  manifest = {
    apiVersion = "route.openshift.io/v1"
    kind       = "Route"

    metadata = {
      labels = {
        app = "stock-demo"
      }
      name      = "stock-route"
      namespace = kubernetes_namespace.stock.metadata[0].name
    }
    spec = {
      path = "/"
      to = {
        kind   = "Service"
        name   = "stock-demo-svc"
        weight = "100"
      }
      port = {
        targetPort = "http"
      }

      tls = {
        termination = "edge"
      }

      wildcardPolicy = "None"
    }
  }
}

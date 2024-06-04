resource "kubernetes_manifest" "stockroute" {
  manifest = {
    apiVersion = "route.openshift.io/v1"
    kind       = "Route"

    metadata = {
        labels = {
            app= "stock-demo"
        }
        
        name = "stock-route"
        namespace = "stock"
    }
    spec = {
        path= "/"
        to = {
            kind= "Service"
            name= "stock-demo-svc"
            weight= "100"
        }
        port = {
            targetPort= "http"
        }
            
        tls ={
            termination= "edge"
        }
            
        wildcardPolicy= "None"
    }
  }
}


resource "kubernetes_token_request_v1" "k10token" {
  metadata {
    name = "k10-k10"
    namespace = "kasten-io"
  }
  spec {
    expiration_seconds = 36*3600
  }
}


resource "kubernetes_manifest" "bppostgres" {
  manifest = {
    apiVersion = "cr.kanister.io/v1alpha1"
    kind       = "Blueprint"

    metadata = {
      name = "postgresql-hooks"
      namespace = "kasten-io"
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
  manifest = {
      kind = "TransformSet"
      apiVersion = "config.kio.kasten.io/v1alpha1"

      metadata = {
        name = "stockupdate"
        namespace = "kasten-io"
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
  depends_on = [
    kubernetes_manifest.bppostgres
  ]

  manifest = {
    apiVersion = "config.kio.kasten.io/v1alpha1"
    kind       = "BlueprintBinding"

    metadata = {
      name = "postgres-blueprint-binding"
      namespace = "kasten-io"
    }

    spec = {
        blueprintRef = {
            name = "postgresql-hooks"
            namespace = "kasten-io"
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
    name = "k10-eula-info"
    namespace = "kasten-io"
  }

  data = {
    accepted="true"
    company=split("@",data.terraform_remote_state.aro.outputs.owneremail)[1]
    email=data.terraform_remote_state.aro.outputs.owneremail
  }
}


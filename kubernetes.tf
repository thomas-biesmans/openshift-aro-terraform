locals  {
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


resource "kubernetes_namespace" "hr" {
  depends_on = [data.azapi_resource_action.aro_kubeconfig]

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

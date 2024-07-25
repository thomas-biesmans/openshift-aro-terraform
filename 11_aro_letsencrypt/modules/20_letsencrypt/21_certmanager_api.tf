

resource "null_resource" "removing_certificate_api_for_manual_run" {
  depends_on = [null_resource.wait_for_issuer_to_become_ready]

  triggers = {
    always_run = var.certmanager["manual_refresh_api_certificate_trigger_timestamp"]
  }

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      result=$(oc get certificate -n openshift-config -o json | jq -r '.items[].metadata.name')
      if echo $result | grep -qE ".*openshift-api.*"; then
        echo "Found existing certificate 'openshift-api', renewing..."
        cmctl renew openshift-api -n openshift-config
        echo "Certificate 'openshift-api' renewed."
      else
        echo "Existing certificate 'openshift-api' not found, not renewing."
      fi
    EOT
  }
}

resource "kubernetes_manifest" "certificate_api" {
  depends_on = [
    null_resource.wait_for_issuer_to_become_ready,
    null_resource.removing_certificate_api_for_manual_run
  ]

  manifest = {

    "apiVersion" = "cert-manager.io/v1"
    "kind"       = "Certificate"
    "metadata" = {
      "name"      = "openshift-api"
      "namespace" = "openshift-config"
      "labels"    = {
        "manual-refresh-trigger-timestamp" = var.certmanager["manual_refresh_api_certificate_trigger_timestamp"]
      }
    }
    "spec" = {
      "secretName" = "openshift-api-certificate"
      "issuerRef" = {
        "name" = "letsencrypt-prod"
        "kind" = "ClusterIssuer"
      }
      "dnsNames" = ["api.${var.openshift["cluster_name"]}.${var.openshift["cluster_domain"]}"]
    }
  }
}

resource "kubernetes_cluster_role" "patch_cluster_api_cert" {
  metadata {
    name = "patch-cluster-api-cert"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["config.openshift.io"]
    resources  = ["apiservers"]
    verbs      = ["get", "list", "patch", "update"]
  }
}

resource "kubernetes_service_account" "patch_cluster_api_cert" {
  metadata {
    name      = "patch-cluster-api-cert"
    namespace = "openshift-config"
  }

  lifecycle {
    ignore_changes = [
      image_pull_secret,
      secret
    ]
  }
}

resource "kubernetes_cluster_role_binding" "patch_cluster_api_cert" {
  metadata {
    name = "patch-cluster-api-cert"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.patch_cluster_api_cert.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.patch_cluster_api_cert.metadata[0].name
    namespace = kubernetes_service_account.patch_cluster_api_cert.metadata[0].namespace
  }
}

resource "null_resource" "wait_for_certificate_api_order_to_become_valid" {
  depends_on = [kubernetes_manifest.certificate_api]

  lifecycle {
    replace_triggered_by = [null_resource.removing_certificate_api_for_manual_run]
  }

  provisioner "local-exec" {
    command = <<EOT
      export ONE_MINUTES_AGO=$(date -u -d "1 minutes ago" +%Y-%m-%dT%H:%M:%SZ)
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      condition=false
      until $condition; do
        result=$(oc get order -n openshift-config -o json | jq -r ".items[] | select(.metadata.creationTimestamp > \"$ONE_MINUTES_AGO\") | .status.state")
        if echo $result | grep -qE "^$"; then
          echo "Waiting for recent order to be created..."
          sleep 5
        elif echo $result | grep -qE "^errored$"; then
          condition=true
          reason=$(oc get order -n openshift-config -o json | jq -r ".items[] | select(.metadata.creationTimestamp > \"$ONE_MINUTES_AGO\") | .status.reason")
          echo "Orders' states has errored out" + $reason
          exit 1
        elif echo $result | grep -qv "valid"; then
          echo "Waiting for recent orders' state to become valid..."
          sleep 5
        else
          condition=true
          echo "Orders' states are valid"
        fi
      done
    EOT
  }
}

resource "null_resource" "wait_for_certificate_api_secret_to_become_available" {
  depends_on = [kubernetes_manifest.certificate_api]

  lifecycle {
    replace_triggered_by = [null_resource.removing_certificate_api_for_manual_run]
  }

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      until oc get secret openshift-api-certificate -n openshift-config -o json | jq -r ".metadata.name" | grep -qe ".*"; do
        echo "Waiting for secret to become available..."
        sleep 2
      done
      echo "Secret is available"
    EOT
  }
}

resource "kubernetes_job" "patch_cluster_api_cert" {
  depends_on = [
    null_resource.wait_for_certificate_api_order_to_become_valid,
    null_resource.wait_for_certificate_api_secret_to_become_available
  ]
  
  lifecycle {
    replace_triggered_by = [null_resource.removing_certificate_api_for_manual_run]
  }

  metadata {
    name      = "patch-cluster-api-cert"
    namespace = "openshift-config"

    annotations = {
      "argocd.argoproj.io/hook"               = "PostSync"
      "argocd.argoproj.io/hook-delete-policy" = "HookSucceeded"
    }
  }

  spec {
    template {
      metadata {}
      spec {
        container {
          image = "image-registry.openshift-image-registry.svc:5000/openshift/cli:latest"
          env {
            name  = "API_HOST_NAME"
            value = "api.${var.openshift["cluster_name"]}.${var.openshift["cluster_domain"]}"
          }
          command = [
            "/bin/bash",
            "-c",
            <<EOT
              #!/usr/bin/env bash
              if oc get secret openshift-api-certificate -n openshift-config; then
                oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts": {"namedCertificates": [{"names": ["'$API_HOST_NAME'"], "servingCertificate": {"name": "openshift-api-certificate"}}]}}}'
              else
                echo "Could not execute sync as secret 'openshift-api-certificate' in namespace 'openshift-config' does not exist, check status of CertificationRequest"
                exit 1
              fi
            EOT
          ]
          # args    = ["<<EOF\n${base64encode(file("${path.module}/script.sh"))}\nEOF"]
          name = "patch-cluster-api-cert"
        }
        dns_policy                       = "ClusterFirst"
        restart_policy                   = "Never"
        termination_grace_period_seconds = 30
        service_account_name             = kubernetes_service_account.patch_cluster_api_cert.metadata[0].name
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "5m"
    update = "5m"
  }
}

resource "null_resource" "wait_for_certificate_api_push" {
  depends_on = [kubernetes_job.patch_cluster_api_cert]

  lifecycle {
    replace_triggered_by = [kubernetes_job.patch_cluster_api_cert]
  }

  provisioner "local-exec" {
    command = <<EOT
      export KUBECONFIG=${var.kubeconfig_location_relative_to_cwd}
      condition_started_progressing=false
      until $condition_started_progressing; do
        result_started_progressing=$(oc get co kube-apiserver -o json)

        if echo $result_started_progressing | jq -r ".status.conditions[] | select (.type == \"Progressing\") | .status" | grep -qE "False"; then
          echo "ClusterOperator kube-apiserver has not started deploying yet."
          sleep 5
        else
          condition_started_progressing=true
          echo "ClusterOperator kube-apiserver started deploying"

          condition_is_done=false
          until $condition_is_done; do
            result_is_done=$(oc get co kube-apiserver -o json)

            if echo $result_is_done | jq -r ".status.conditions[] | select (.type == \"Progressing\") | .status" | grep -qE "True"; then
              echo "ClusterOperator kube-apiserver is deploying: " $(echo $result_is_done | jq -r ".status.conditions[] | select (.type == \"Progressing\") | .message")
              sleep 5
            else
              condition_is_done=true
              echo "ClusterOperator kube-apiserver is done deploying"
            fi
          done
        fi
      done

    EOT
  }
}


output "k10token" {
  value     = kubernetes_token_request_v1.k10token.token
  sensitive = true
}

output "k10_route_hostname" {
  value = "${data.kubernetes_resource.k10_route.object.spec.host}${data.kubernetes_resource.k10_route.object.spec.path}"
}

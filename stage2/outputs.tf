output "k10token" {
  value = kubernetes_token_request_v1.k10token.token
  sensitive=true
}

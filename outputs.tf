output "aro_kubeconfig_out" {
  value     = module.aro.aro_kubeconfig_out
  sensitive = true
}
output "aro_admin_login" {
  value = module.aro.aro_admin_login
}
output "aro_admin_pass" {
  value = module.aro.aro_admin_pass
  # sensitive = true
}
output "aro_api_ip" {
  value = module.aro.aro_api_ip
}
output "aro_ingress_ip" {
  value = module.aro.aro_ingress_ip
}
output "console_url" {
  value = module.aro.console_url
}
output "aro_name" {
  value = module.aro.aro_name
}
output "aro_id" {
  value = module.aro.aro_id
}

output "k8object" {
  value = module.kasten.k8object
}

output "k10token" {
  value     = module.kasten_instance.k10token
  sensitive = true
}

output "k10_route_hostname" {
  value = module.kasten_instance.k10_route_hostname
}

# output "k8object" {
#   value = module.kasten.k8object
# }

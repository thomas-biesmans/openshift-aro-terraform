terraform {
  required_version = ">=1.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~>2.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.27"
    }
  }
}

# Terraform: optional IaC for this project.
# This example uses the Kubernetes provider to create the namespace and a placeholder.
# No cloud account required; point at your local kubeconfig (minikube/kind).

terraform {
  required_version = ">= 1.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "kubernetes" {
  config_path = var.kube_config_path
}

variable "kube_config_path" {
  description = "Path to kubeconfig (e.g. ~/.kube/config)"
  type        = string
  default     = "~/.kube/config"
}

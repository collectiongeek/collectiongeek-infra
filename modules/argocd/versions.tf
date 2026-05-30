terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      # Pinned to 3.0.x: 3.1.x bundles Helm 3.18.5 with a remote-$ref
      # values.schema.json regression (helm/helm#31136) that breaks the F5
      # nginx-ingress chart. Revert to ~> 3.0 once a provider bundles >= 3.18.6.
      version = ">= 3.0.0, < 3.1.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}
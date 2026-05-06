output "argocd_namespace" {
  description = "Namespace where Argo CD is installed"
  value       = helm_release.argocd.namespace
}

output "argocd_host" {
  description = "Argo CD UI hostname"
  value       = local.argocd_host
}

output "argocd_url" {
  description = "Argo CD UI URL"
  value       = "https://${local.argocd_host}"
}
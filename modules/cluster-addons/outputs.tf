output "ingress_nginx_namespace" {
  description = "Namespace where NGINX Ingress Controller is installed"
  value       = helm_release.ingress_nginx.namespace
}

output "cert_manager_namespace" {
  description = "Namespace where cert-manager is installed"
  value       = helm_release.cert_manager.namespace
}

output "external_dns_namespace" {
  description = "Namespace where external-dns is installed"
  value       = helm_release.external_dns.namespace
}

output "cert_manager_cluster_issuer" {
  description = "Name of the production ClusterIssuer"
  value       = "letsencrypt-prod"
}

output "cert_manager_staging_issuer" {
  description = "Name of the staging ClusterIssuer"
  value       = "letsencrypt-staging"
}
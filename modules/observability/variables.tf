variable "cluster_name" {
    type = string
}

variable "vpc_id" {
    type = string
}

variable "private_route_table_ids" {
    type = list(string)
}

variable "oidc_provider_arn" {
    type = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC issuer URL WITHOUT the 'https://' prefix — used as the prefix on IRSA trust policy condition keys (`<issuer>:sub`, `<issuer>:aud`). IAM matches these literally against the JWT, so a leading 'https://' makes the role unassumable. Pass `module.eks.cluster_oidc_issuer_url`, which is already stripped."
  type        = string
  validation {
    condition     = !startswith(var.oidc_provider_url, "https://")
    error_message = "oidc_provider_url must NOT start with 'https://'. IRSA condition keys require the bare issuer host/path. Pass module.eks.cluster_oidc_issuer_url (already stripped) or strip it with replace(url, \"https://\", \"\")."
  }
}

variable "log_retention_days"   { 
    type = number
    default = 90 
}

variable "trace_retention_days" { 
    type = number
    default = 30 
}

variable "namespace" {
    type = string
    default = "observability"
}
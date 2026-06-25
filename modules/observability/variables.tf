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
    type = string
}   # the issuer without https://

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
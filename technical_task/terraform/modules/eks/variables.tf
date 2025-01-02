# EKS Cluster Variables
variable "cluster_name" {
    type        = string
    description = "The name of the EKS cluster"
}

variable "cluster_version" {
    type        = string
    description = "The version of the EKS cluster"
    default     = "1.31"
}

variable "cluster_endpoint_public_access" {
    type        = bool
    description = "Whether the cluster endpoint is publicly accessible"
    default     = true
}

variable "vpc_id" {
    type        = string
    description = "The ID of the VPC where the cluster is deployed"
    }

variable "private_subnet_ids" {
    type        = list(string)
    description = "List of private subnet IDs"
}

variable "intra_subnet_ids" {
    type        = list(string)
    description = "List of intra-subnet IDs for the control plane"
}

variable "eks_managed_node_groups" {
    type        = map(any)
    description = "Configuration for EKS Managed Node Groups"
    default     = {}
}

variable "enable_cluster_creator_admin_permissions" {
    type        = bool
    description = "Add the caller as an EKS administrator"
    default     = true
}

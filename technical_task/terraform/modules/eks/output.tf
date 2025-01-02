###############################################################################
# Outputs
###############################################################################

output "cluster_name" {
    description = "EKS Cluster Name"
    value       = module.eks.cluster_name
}

output "cluster_endpoint" {
    description = "EKS Cluster Endpoint"
    value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
    description = "EKS Cluster Security Group ID"
    value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
    description = "Base64 encoded certificate data required to communicate with the cluster"
    value       = module.eks.cluster_certificate_authority_data
}
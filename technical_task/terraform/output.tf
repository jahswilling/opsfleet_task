###############################################################################
#Outputs
###############################################################################


# VPC Outputs
output "vpc_id" {
    value = module.vpc.vpc_id
}

output "private_subnets_ids" {
    value = module.vpc.private_subnets_ids
}

output "public_subnets_ids" {
    value = module.vpc.public_subnets_ids
}

output "intra_subnets_ids" {
    value = module.vpc.intra_subnets_ids
}

# Output for the VPC ID
output "imported_vpc_id" {
    value       = data.aws_vpc.existing_vpc.id
    description = "The ID of the existing VPC"
}

# Output for Public Subnet IDs
output "imported_public_subnet_ids" {
    value       = data.aws_subnets.public_subnets.ids
    description = "List of public subnet IDs in the existing VPC"
}

# Output for Private Subnet IDs
output "imported_private_subnet_ids" {
    value       = data.aws_subnets.private_subnets.ids
    description = "List of private subnet IDs in the existing VPC"
}

# Output for Intra Subnet IDs (optional)
output "imported_intra_subnet_ids" {
    value       = data.aws_subnets.intra_subnets.ids
    description = "List of intra subnet IDs in the existing VPC"
}


#EKS outputs
output "eks_cluster_name" {
    description = "The name of the EKS cluster"
    value       = module.eks.cluster_name
    }

output "eks_cluster_endpoint" {
    description = "The endpoint of the EKS cluster"
    value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
    description = "EKS Cluster Security Group ID"
    value       = module.eks.eks_cluster_security_group_id
}

#karpenter output
output "karpenter_iam_role" {
    description = "IAM Role for Karpenter-managed nodes"
    value       = module.karpenter.node_iam_role_name
}

output "karpenter_helm_release_status" {
    description = "Status of the Karpenter Helm release"
    value       = helm_release.karpenter.status
}

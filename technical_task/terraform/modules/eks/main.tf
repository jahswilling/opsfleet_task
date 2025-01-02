###############################################################################
# EKS Cluster Configuration
###############################################################################

module "eks" {
    source  = "terraform-aws-modules/eks/aws"
    version = "20.31.0"

    # General Cluster Configuration
    cluster_name    = var.cluster_name
    cluster_version = var.cluster_version

    cluster_endpoint_public_access  = var.cluster_endpoint_public_access

    # Add-ons
    cluster_addons = {
        coredns                = {}
        eks-pod-identity-agent = {}
        kube-proxy             = {}
        vpc-cni                = {}
    }

    # Networking
    vpc_id     = var.vpc_id
    subnet_ids = var.private_subnet_ids
    control_plane_subnet_ids = var.intra_subnet_ids



    # Managed Node Groups
    eks_managed_node_groups = var.eks_managed_node_groups

    # Cluster Access Configuration
    enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions

    # Node Security Group Tags
    node_security_group_tags = {
        # NOTE - if creating multiple security groups with this module, only tag the
        # security group that Karpenter should utilize with the following tag
        # (i.e. - at most, only one security group should have this tag in your account)
        "karpenter.sh/discovery" = var.cluster_name
    }
}



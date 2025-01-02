###############################################################################
# VPC
###############################################################################

#create vpc
module "vpc" {
    source = "./modules/vpc"

    vpc_name               = "${var.cluster_name}-vpc"
    vpc_cidr               = var.vpc_cidr
    vpc_azs                = ["${var.region}a", "${var.region}b", "${var.region}c"]
    private_subnets        = var.private_subnet_cidrs
    public_subnets         = var.public_subnet_cidrs
    intra_subnets          = var.intra_subnet_cidrs
    enable_nat_gateway     = true
    single_nat_gateway     = true
    one_nat_gateway_per_az = false
    public_subnet_tags     = { "kubernetes.io/role/elb" = 1 }
    private_subnet_tags    = { "kubernetes.io/role/internal-elb" = 1, "karpenter.sh/discovery" = var.cluster_name }
}

# Fetch Existing VPC
data "aws_vpc" "existing_vpc" {
    filter {
        name   = "tag:Name"
        values = ["${var.cluster_name}-vpc"]
    }
    depends_on = [
        module.vpc
    ]
}

data "aws_subnets" "public_subnets" {
    filter {
        name   = "tag:Name"
        values = ["${var.cluster_name}-vpc-public-*"]
    }
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.existing_vpc.id]
    }
    depends_on = [
        module.vpc
    ]
}

data "aws_subnets" "private_subnets" {
    filter {
        name   = "tag:Name"
        values = ["${var.cluster_name}-vpc-private-*"]
    }
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.existing_vpc.id]
    }
    depends_on = [
        module.vpc
    ]
}

data "aws_subnets" "intra_subnets" {
    filter {
        name   = "tag:Name"
        values = ["${var.cluster_name}-vpc-intra-*"]
    }
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.existing_vpc.id]
    }
    depends_on = [
        module.vpc
    ]
}


###############################################################################
# EKS
###############################################################################
module "eks" {
    source = "./modules/eks"

    # Cluster Configuration
    cluster_name    = var.cluster_name
    cluster_version = var.cluster_version

    # Networking: Use data fetched from the existing VPC and subnets
    vpc_id                   = data.aws_vpc.existing_vpc.id
    private_subnet_ids       = data.aws_subnets.private_subnets.ids
    intra_subnet_ids   = data.aws_subnets.intra_subnets.ids

    # Node Groups
    eks_managed_node_groups = {

        karpenter = {
            # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
            ami_type       = "AL2023_ARM_64_STANDARD" # Use Graviton instances
            instance_types = ["t4g.small", "t4g.medium", "m6g.medium"] # Graviton instance types

            min_size     = 2
            max_size     = 5
            desired_size = 2
            
            taints = {
                # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
                # The pods that do not tolerate this taint should run on nodes created by Karpenter
                addons = {
                key    = "CriticalAddonsOnly"
                value  = "true"
                effect = "NO_SCHEDULE"
                },
            }
        }
    }

    # Other Configurations
    enable_cluster_creator_admin_permissions = true

    depends_on = [
        data.aws_vpc.existing_vpc,
        data.aws_subnets.private_subnets,
        data.aws_subnets.intra_subnets
    ]
}

###############################################################################
# Data Sources
###############################################################################
data "aws_ecrpublic_authorization_token" "token" {
    provider = aws.virginia
}


###############################################################################
# Karpenter
###############################################################################
module "karpenter" {
    source = "terraform-aws-modules/eks/aws//modules/karpenter"

    cluster_name = module.eks.cluster_name

    enable_v1_permissions = true

    enable_pod_identity             = true
    create_pod_identity_association = true

    # Attach additional IAM policies to the Karpenter node IAM role
    node_iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }

    depends_on = [
        module.eks
    ]
}
###############################################################################
# Karpenter Helm
###############################################################################
resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.0.0"
  wait                = false

  values = [
    <<-EOT
    serviceAccount:
      create: true
      name: ${module.karpenter.service_account}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    defaultProvisioner:
      limits:
        resources:
          cpu: "1000"
      consolidation:
        enabled: true
      requirements:
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot", "on-demand"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["arm64", "amd64"]
      labels:
        karpenter.sh/capacity-type: "spot"
      fallbackCapacityType: "on-demand"
      instanceTypes:
        - c5.large
        - c5.xlarge
        - m5.large
        - t3.large
        - r5.large
        - c6g.large 
        - t4g.large 
        - m6g.large 
        - r6g.large 
    postInstallHook:
      image:
        repository: "bitnami/kubectl"
        tag: "1.30"
        digest: "sha256:13210e634b6368173205e8559d7c9216cce13795f28f93c39b1bb8784cac8074"
    EOT
  ]

  depends_on = [
    module.karpenter
  ]
}

###############################################################################
# Karpenter Kubectl - NodePool
###############################################################################
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r", "t"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["2", "4", "8", "16", "32"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["2"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["arm64", "amd64"]
          instanceTypes:
            - c5.large
            - c5.xlarge
            - m5.large
            - t3.large
            - r5.large
            - c6g.large 
            - t4g.large 
            - m6g.large 
            - r6g.large 
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
      labels:
        karpenter.sh/capacity-type: "spot" # Prefer Spot instances
      tolerations:
        - key: "karpenter.sh/capacity-type"
          operator: Equal
          value: "spot"
          effect: NoSchedule
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

###############################################################################
# Karpenter Kubectl - NodeClass
###############################################################################
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2023
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}




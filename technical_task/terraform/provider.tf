###############################################################################
# Provider
###############################################################################
provider "aws" {
    region = var.region
    profile = var.company
}

provider "aws" {
    region = "us-east-1"
    alias  = "virginia"
}

provider "helm" {
    kubernetes {
        host                   = module.eks.cluster_endpoint
        cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

        exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        # This requires the awscli to be installed locally where Terraform is executed
        args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
        }
    }
}

provider "kubectl" {
    apply_retry_count      = 5
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    load_config_file       = false

    exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        # This requires the awscli to be installed locally where Terraform is executed
        args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
}

terraform {
    backend "s3" {
        bucket         = "opsfleet-state-bucket"
        region         = "eu-west-2"
        dynamodb_table = "opsfleet-dynamodb-state-lock"
        encrypt        = true
        key            = "opsfleet.tfstate"
    }

    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 5.0"
        }
        kubectl = {
        source  = "gavinbunney/kubectl"
        version = "~> 1.14"
        }
        helm = {
        source  = "hashicorp/helm"
        version = "~> 2.0"
        }
    }
}
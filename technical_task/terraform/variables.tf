###############################################################################
# Environment
###############################################################################
variable "region" {
    type = string
}

variable "company" {
    type = string
}

# EKS Configuration
variable "cluster_name" {
    type = string
}

variable "cluster_version" {
    type        = string
    description = "Kubernetes version for the EKS cluster"
    default     = "1.31"
}

# VPC Configuration
variable "vpc_cidr" {
    type        = string
    description = "CIDR block for the VPC"
    default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
    type        = list(string)
    description = "CIDR blocks for private subnets"
    default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
    type        = list(string)
    description = "CIDR blocks for public subnets"
    default     =  ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "intra_subnet_cidrs" {
    type        = list(string)
    description = "CIDR blocks for public subnets"
    default     =["10.0.104.0/24", "10.0.105.0/24", "10.0.106.0/24"]
}
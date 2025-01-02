
#VPC Variables
variable "vpc_name" {
    description = "Name of the VPC"
    type        = string
}

variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type        = string
}

variable "vpc_azs" {
    description = "Availability Zones"
    type        = list(string)
}

variable "private_subnets" {
    description = "Private subnet CIDRs"
    type        = list(string)
}

variable "public_subnets" {
    description = "Public subnet CIDRs"
    type        = list(string)
}

variable "intra_subnets" {
    description = "Intra subnet CIDRs"
    type        = list(string)
}

variable "enable_nat_gateway" {
    description = "Enable NAT Gateway"
    type        = bool
}

variable "single_nat_gateway" {
    description = "Use single NAT Gateway"
    type        = bool
}

variable "one_nat_gateway_per_az" {
    description = "One NAT Gateway per AZ"
    type        = bool
}

variable "public_subnet_tags" {
    description = "Tags for public subnets"
    type        = map(string)
}

variable "private_subnet_tags" {
    description = "Tags for private subnets"
    type        = map(string)
}
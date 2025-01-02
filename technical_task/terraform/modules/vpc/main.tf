module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"
    version = "5.17.0"

    name = var.vpc_name
    cidr = var.vpc_cidr

    azs             = var.vpc_azs
    private_subnets = var.private_subnets
    public_subnets  = var.public_subnets
    intra_subnets   = var.intra_subnets

    enable_nat_gateway     = var.enable_nat_gateway
    single_nat_gateway     = var.single_nat_gateway
    one_nat_gateway_per_az = var.one_nat_gateway_per_az

    public_subnet_tags = var.public_subnet_tags
    private_subnet_tags = var.private_subnet_tags
}
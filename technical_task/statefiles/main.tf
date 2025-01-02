###############################################################################
# Provider
###############################################################################
provider "aws" {
    region  = var.region
    profile = var.company
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

###############################################################################
# S3 Bucket
###############################################################################
resource "aws_s3_bucket" "state" {
    bucket        = "${var.company}-state-bucket"
    force_destroy = true
}

###############################################################################
# DynamoDB Table
###############################################################################
resource "aws_dynamodb_table" "state_lock" {
  name         = "${var.company}-dynamodb-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
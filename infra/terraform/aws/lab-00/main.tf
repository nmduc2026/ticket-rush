terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "profile" {
  type    = string
  default = "ticketrush"
}

variable "expires_at" {
  type        = string
  description = "Ngày dự kiến destroy lab (YYYY-MM-DD), gắn vào tag ExpiresAt"
}

provider "aws" {
  region  = var.region
  profile = var.profile

  default_tags {
    tags = {
      Project   = "ticketrush"
      Lab       = "lab-00"
      ExpiresAt = var.expires_at
    }
  }
}

data "aws_caller_identity" "current" {}

# Tên bucket phải duy nhất toàn cầu -> gắn account id
resource "aws_s3_bucket" "hello" {
  bucket        = "ticketrush-lab00-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "hello" {
  bucket                  = aws_s3_bucket.hello.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket" {
  value = aws_s3_bucket.hello.bucket
}

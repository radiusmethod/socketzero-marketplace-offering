terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      "source-repository" = "socketzero-terraform-examples"
      "socketzero-version" = var.socketzero_version
      "deployment-type"   = "basic"
    }
  }
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = data.aws_region.current.id

  vpc_cidr = "10.10.0.0/16"
  azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnets = [
    cidrsubnet(local.vpc_cidr, 4, 0), # 10.10.0.0/20
    cidrsubnet(local.vpc_cidr, 4, 1), # 10.10.16.0/20
    cidrsubnet(local.vpc_cidr, 4, 2), # 10.10.32.0/20
  ]

  private_subnets = [
    cidrsubnet(local.vpc_cidr, 4, 8),  # 10.10.128.0/20
    cidrsubnet(local.vpc_cidr, 4, 9),  # 10.10.144.0/20
    cidrsubnet(local.vpc_cidr, 4, 10), # 10.10.160.0/20
  ]

  receiver_config = templatefile("${path.module}/templates/config.json.tmpl", {
    web_server_ip = aws_instance.web_server_test.private_ip
  })
}
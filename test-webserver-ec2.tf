# Known to work well and stable for simple web servers
locals {
  # This is a well-tested AL2023 AMI that works reliably
  web_server_ami = "ami-0cbbe2c6a1bb2ad63"  # us-east-1 AL2023
}

resource "aws_instance" "web_server_test" {
  ami                         = local.web_server_ami
  instance_type               = "t2.nano"  
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.web_server_test.id]
  iam_instance_profile        = aws_iam_instance_profile.socketzero_ami.name
  associate_public_ip_address = false

  # Simple root volume with encryption for security
  root_block_device {
    volume_type = "gp3"
    volume_size = 8  
    encrypted   = true
    kms_key_id  = var.kms_key_id  # Uses customer-managed KMS key if provided
  }

  user_data = <<-EOF
            #!/bin/bash
            dnf update -y
            dnf install -y nginx
            echo "Hello World from $(hostname -f)" > /usr/share/nginx/html/index.html
            systemctl enable nginx
            systemctl start nginx
            EOF

  tags = {
    Name = "test-web-server"
  }
}

resource "aws_security_group" "web_server_test" {
  name   = "web-server-test"
  vpc_id = module.vpc.vpc_id

  ingress {
    description = "Allow HTTP from VPC range"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-test"
  }
}


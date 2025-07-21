# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web_server_test" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.private_subnets[0]
  vpc_security_group_ids      = [aws_security_group.web_server_test.id]
  iam_instance_profile        = aws_iam_instance_profile.socketzero_ami.name
  associate_public_ip_address = false

  # Enable EBS encryption for security
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
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


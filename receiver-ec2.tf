# SocketZero Receiver Instance
# Using Stable 1.0.0 AMI: ami-08a1c83424ca22b36
# This is the marketplace-ready unencrypted AMI
resource "aws_security_group" "socketzero_receiver" {
  name   = "socketzero-receiver"
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "receiver_from_lb" {
  type                     = "ingress"
  from_port                = var.receiver_port
  to_port                  = var.receiver_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.socketzero_receiver.id
  source_security_group_id = aws_security_group.load_balancer.id
}

resource "aws_instance" "socketzero_receiver" {
  ami                         = var.socketzero_ami_id
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.socketzero_ami.name
  vpc_security_group_ids      = [aws_security_group.socketzero_receiver.id]

  # IMPORTANT: Enable EBS encryption for production security
  # The AMI is unencrypted per AWS Marketplace requirements
  root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
    kms_key_id  = var.kms_key_id  # Uses customer-managed KMS key if provided
  }

  user_data = <<-EOF
                #!/bin/bash
                cat <<EOC | sudo tee /opt/socketzero/config.json > /dev/null
                ${local.receiver_config}
                EOC

                sudo systemctl restart socketzero-receiver
                EOF

  tags = {
    Name = "socketzero-receiver"
    SocketZeroVersion = var.socketzero_version
    AMI = var.socketzero_ami_id
  }
}


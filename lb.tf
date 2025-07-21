resource "aws_security_group" "load_balancer" {
  name   = "socketzero-receiver-lb"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.trusted_ip_cidrs
    description = "Allow HTTPS from specified IPs"
  }
}

resource "aws_security_group_rule" "lb_to_receiver" {
  type                     = "egress"
  from_port                = var.receiver_port
  to_port                  = var.receiver_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.load_balancer.id
  source_security_group_id = aws_security_group.socketzero_receiver.id
}

resource "aws_lb_target_group" "socketzero_receiver" {
  name        = "socketzero-receiver"
  port        = var.receiver_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/ping"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }

  ip_address_type  = "ipv4"
  protocol_version = "HTTP1"
}

resource "aws_lb_target_group_attachment" "example" {
  target_group_arn = aws_lb_target_group.socketzero_receiver.arn
  target_id        = aws_instance.socketzero_receiver.id
  port             = var.receiver_port
}

resource "aws_lb" "socketzero_receiver" {
  name               = "socketzero-receiver"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.load_balancer.id]
  subnets            = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]
  ip_address_type    = "ipv4"
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.socketzero_receiver.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"

  certificate_arn = aws_acm_certificate_validation.ami_socketzero_app.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.socketzero_receiver.arn

    forward {
      target_group {
        arn    = aws_lb_target_group.socketzero_receiver.arn
        weight = 1
      }

      stickiness {
        enabled  = false
        duration = 3600
      }
    }
  }
}

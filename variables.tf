variable "receiver_port" {
  description = "Port that receiver listens on"
  type = number
}

variable "aws_route53_zone" {
  description = "Existing aws zone where new record will be added"
  type = string
}

variable "trusted_ip_cidrs" {
  description = "List of IP addresses allowed to access the receiver load balancer"
  type        = list(string)
}

variable "kms_key_id" {
  description = "Optional KMS key ID for EBS encryption. If not provided, uses default AWS managed key."
  type        = string
  default     = null
}

variable "socketzero_version" {
  description = "SocketZero version being deployed"
  type        = string
  default     = "stable-1.0.0"
}

variable "socketzero_ami_id" {
  description = "SocketZero AMI ID for the specified version"
  type        = string
  default     = "ami-08a1c83424ca22b36"  # Stable 1.0.0 marketplace AMI
}

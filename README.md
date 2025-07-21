# SocketZero AWS Marketplace Terraform Examples

Deploy SocketZero on AWS using Terraform with best practices for security and production readiness.

## 🚀 Quick Start Guide

### Prerequisites
- **Subscribe to SocketZero on AWS Marketplace**: [Get SocketZero AMI](https://aws.amazon.com/marketplace/pp/prodview-qjqz3izsnofoo)
- AWS CLI configured with appropriate permissions
- Terraform installed (>= 1.0)
- Existing Route53 Public hosted zone
- IP addresses for security group access

### 3-Step Deployment

#### Step 1: Clone and Configure
```bash
# Navigate to the terraform examples
cd socketzero-marketplace-offerings

# Copy and edit the configuration
cp terraform.tfvars.example terraform.tfvars
```

#### Step 2: Update Configuration
Edit `terraform.tfvars` with your values:
```hcl
# Your existing Route53 hosted zone (required)
aws_route53_zone = "your-domain.com"

# Port that SocketZero receiver listens on
receiver_port = 9997

# IP addresses/CIDRs allowed to access the load balancer
trusted_ip_cidrs = ["YOUR.IP.ADDRESS/32"]

# SocketZero version and AMI configuration
socketzero_version = "stable-1.0.0"
socketzero_ami_id  = "ami-08a1c83424ca22b36"
```

#### Step 3: Deploy
```bash
# Initialize and deploy
terraform init
terraform plan
terraform apply
```

**That's it!** Your SocketZero receiver will be available at `https://ami.your-domain.com`

## 🔒 Security & Encryption

### Important Security Information

⚠️ **CRITICAL**: The SocketZero AMI is **unencrypted per AWS Marketplace requirements**, but **EBS encryption is automatically enabled** in these Terraform examples for production security.

#### Why is the AMI unencrypted?

AWS Marketplace requires AMIs to be distributed unencrypted to ensure compatibility across all AWS accounts and regions. This does not compromise SocketZero's security capabilities.

#### How Encryption is Enabled

**Our Terraform examples automatically enable encryption:**
```hcl
root_block_device {
  encrypted   = true
  volume_type = "gp3"
  volume_size = 8
  kms_key_id  = var.kms_key_id  # Optional: use your own KMS key
}
```

**Alternative encryption methods:**

<details>
<summary>AWS Console Method</summary>

In the EC2 launch wizard:
1. Expand "Configure Storage"
2. Check "Encrypted" 
3. Select your KMS key
</details>

<details>
<summary>AWS CLI Method</summary>

```bash
aws ec2 run-instances \
  --image-id ami-08a1c83424ca22b36 \
  --instance-type t3.small \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"Encrypted":true,"VolumeType":"gp3"}}]'
```
</details>

<details>
<summary>Enable Account-Wide Encryption</summary>

```bash
aws ec2 enable-ebs-encryption-by-default --region us-east-1
```
</details>

#### Security Features

All SocketZero security features work perfectly with encrypted storage:
- ✅ **Zero-trust networking**
- ✅ **Post-quantum cryptography**  
- ✅ **End-to-end encryption**
- ✅ **Identity-based access controls**
- ✅ **Certificate-based authentication**
- ✅ **EBS encryption enabled** by default
- ✅ **Security groups** restricting access to trusted IPs
- ✅ **Private subnets** for internal resources
- ✅ **TLS/SSL** termination at load balancer

#### Security Best Practices

1. **Always encrypt in production** (done automatically in our examples)
2. **Use customer-managed KMS keys** for enhanced control
3. **Enable encryption by default** in your AWS account
4. **Regularly rotate encryption keys** per your security policy

## 🏗️ Architecture

This Terraform configuration creates:
- **VPC** with public/private subnets across multiple AZs
- **Application Load Balancer** with TLS termination
- **SocketZero Receiver** instance (encrypted EBS)
- **Test Web Server** for demonstration
- **Route53 DNS** record
- **Security Groups** with minimal required access
- **IAM Roles** for instance permissions

All infrastructure is defined in easy-to-read `.tf` files in the root directory.

## 📁 Project Structure

```
socketzero-marketplace-offering/
├── README.md                    # Complete documentation and setup guide
├── main.tf                     # Terraform provider and requirements
├── variables.tf                # Input variables and configuration
├── outputs.tf                  # Deployment outputs and endpoints
├── locals.tf                   # Local values and computed config
├── terraform.tfvars.example    # Example configuration file
├── validate.sh                 # Validation script for deployment
├── vpc.tf                      # VPC and networking configuration
├── iam.tf                      # IAM roles and policies
├── receiver-ec2.tf             # SocketZero receiver instance
├── test-webserver-ec2.tf       # Test web server for demonstration
├── lb.tf                       # Application Load Balancer configuration
├── dns.tf                      # Route53 DNS records
└── templates/
    └── config.json.tmpl        # SocketZero receiver configuration template
```

## 🔧 Configuration Options

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_route53_zone` | Existing Route53 zone | - | ✅ |
| `receiver_port` | SocketZero receiver port | `9997` | ✅ |
| `trusted_ip_cidrs` | IPs allowed to access ALB | `[]` | ✅ |
| `socketzero_version` | SocketZero version identifier | `stable-1.0.0` | ❌ |
| `socketzero_ami_id` | Specific AMI ID for version | `ami-08a1c83424ca22b36` | ❌ |
| `kms_key_id` | KMS key for encryption | AWS managed | ❌ |

> 💡 **Note**: The default AMI ID corresponds to SocketZero Stable 1.0.0 from [AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-qjqz3izsnofoo). You must subscribe to the product before deployment.

## 📝 Example Configuration

```hcl
# terraform.tfvars
aws_route53_zone = "example.com"
receiver_port    = 9997
trusted_ip_cidrs = [
  "203.0.113.1/32",    # Your IP
  "198.51.100.0/24",   # Office network
]
socketzero_version = "stable-1.0.0"
socketzero_ami_id  = "ami-08a1c83424ca22b36"
```

## ⚙️ SocketZero Configuration

### Configuration File Location
- **Path:** `/opt/socketzero/config.json`
- **Generated:** From Terraform template at instance launch
- **Updates:** Edit file directly on instance for immediate changes

### Example Configuration
```json
{
  "authz": false,
  "cookie": "__Host-socketzero-authservice-session-id-cookie",
  "redisHost": "localhost:6379",
  "redisPassword": "",
  "upgraderDisabled": true,
  "tunnels": [
    {
      "hostname": "web-server.apps.socketzero.com",
      "listenPort": 80,
      "targetPort": 80,
      "transport": "tcp",
      "targetHost": "10.10.128.10",
      "friendlyName": "Web Server Tunnel",
      "roles": ["admin"]
    }
  ]
}
```

### Updating Configuration

**For immediate changes on existing instance:**
```bash
# Edit the config file
sudo vi /opt/socketzero/config.json

# Restart the service to apply changes
sudo systemctl restart socketzero-receiver

# Check service status
sudo systemctl status socketzero-receiver
```

**For persistent changes across redeployments:**
- Update the template in `templates/config.json.tmpl`
- Modify variables in `terraform.tfvars`
- Re-apply Terraform: `terraform apply`

## 🌐 Load Balancer & DNS

### How it Works
- The SocketZero receiver is deployed behind an AWS Application Load Balancer (ALB)
- ALB listens on **port 443 (HTTPS)** and forwards to receiver on configured port (default: 9997)
- Only IPs in `trusted_ip_cidrs` can access the ALB
- A CNAME record (e.g., `ami.your-domain.com`) points to the ALB in Route53

### After Deployment
- Connect using: `https://ami.your-domain.com`
- Add this hostname in your SocketZero client configuration
- Use **port 443** for the connection

## 🧪 Testing Your Deployment

After deployment completes:

1. **Install SocketZero Client**:
   - Get the client from: [SocketZero Client Repository](https://github.com/radiusmethod/socketzero-client)
   - Follow the installation instructions in that repository

2. **Connect with SocketZero Client**:
   - Add hostname: `ami.your-domain.com`
   - Port: `443` (HTTPS)

3. **Test the Tunnel**:
   - Navigate to: `http://web-server.apps.socketzero.com`
   - You should see: "Hello World from [hostname]"

4. **Verify Encryption**:
   - Check EC2 console shows encrypted volumes
   - Confirm security groups only allow trusted IPs

## 🔄 Updates & Management

### Update to New SocketZero Version
```bash
# Update variables in terraform.tfvars
# socketzero_version = "stable-1.1.0"
# socketzero_ami_id  = "ami-NEW_AMI_ID"

# Re-apply Terraform
terraform apply
```

### Manual Instance Management
If you want to use the SocketZero receiver on a different EC2 instance (not managed by Terraform):

1. Launch your EC2 instance using the SocketZero Receiver AMI
2. Copy your desired `config.json` to `/opt/socketzero/config.json`
3. Ensure proper IAM permissions and security group rules
4. Restart the service: `sudo systemctl restart socketzero-receiver`
5. Update DNS/load balancer configuration if needed

### SSM Parameter Store
The AMI ID can be stored in AWS SSM Parameter Store under `/socketzero/receiver/latest-ami` for automated version management.

## 🆘 Troubleshooting

### Common Issues

**Can't connect to receiver:**
- Check security group allows your IP in `trusted_ip_cidrs`
- Verify Route53 DNS record exists and points to ALB
- Confirm SSL certificate is valid
- Test ALB health checks are passing

**Config changes not applied:**
- Restart service: `sudo systemctl restart socketzero-receiver`
- Check logs: `sudo journalctl -u socketzero-receiver -f`
- Verify config file syntax: `cat /opt/socketzero/config.json | jq`

**Encryption not working:**
- Verify `encrypted = true` in `root_block_device` configuration
- Check instance shows encrypted volumes in EC2 console
- Confirm KMS key permissions if using custom key

**Service not starting:**
- Check service status: `sudo systemctl status socketzero-receiver`
- Review logs: `sudo journalctl -u socketzero-receiver -f`
- Verify config file permissions: `ls -la /opt/socketzero/config.json`

### Health Checks
```bash
# Check if SocketZero service is running
sudo systemctl status socketzero-receiver

# View recent logs
sudo journalctl -u socketzero-receiver --since "10 minutes ago"

# Test local connectivity
curl -k https://localhost:9997/health
```

## 📞 Support

For issues with:
- **Terraform examples**: Check this repository's issues
- **SocketZero product**: Contact support@radiusmethod.com
- **Client installation**: See [SocketZero Client Repository](https://github.com/radiusmethod/socketzero-client)
- **AWS resources**: Consult AWS documentation
- **Security/Encryption**: Review the security section above

---

**Ready to get started?** Follow the [Quick Start Guide](#-quick-start-guide) above! 
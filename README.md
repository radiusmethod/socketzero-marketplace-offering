# SocketZero AWS Marketplace Terraform Examples

Deploy SocketZero on AWS using Terraform with best practices for security and production readiness.

## Table of Contents

- [Important Notes](#important-notes)
- [Quick Start Guide](#quick-start-guide)
  - [Prerequisites](#prerequisites)
  - [3-Step Deployment](#3-step-deployment)
  - [Finding Your AMI ID](#finding-your-ami-id)
- [Security & Encryption](#security--encryption)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Configuration Options](#configuration-options)
- [Example Configuration](#example-configuration)
- [SocketZero Configuration](#socketzero-configuration)
- [Load Balancer & DNS](#load-balancer--dns)
- [Testing Your Deployment](#testing-your-deployment)
- [Install SocketZero client application](#install-socketzero-client-application)
  - [SocketZero client application](#socketzero-client-application)
  - [Linux Installation](#linux-installation)
- [Testing Your Setup](#testing-your-setup)
  - [Security Notes](#security-notes)
  - [Verification Steps](#verification-steps)
- [Adding Additional Tunnels](#adding-additional-tunnels)
  - [Requirements for Additional Tunnels](#requirements-for-additional-tunnels)
  - [Common Tunnel Examples](#common-tunnel-examples)
  - [Troubleshooting Additional Tunnels](#troubleshooting-additional-tunnels)
- [Updates & Management](#updates--management)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

---

## Important Notes

### SocketZero Client Application Requirement
This SocketZero AMI extends the functionality of the SocketZero Client Application and without it, this product has very limited utility. Please note that the SocketZero Client Application does not require its own licensing and is provided **free of charge** with the subscription to this SocketZero AMI offering. Client installation instructions are provided in the **[Install SocketZero client application](#install-socketzero-client-application)** section below.

### Subscription Benefits
Customers receive full access to SocketZero after subscribing to the AMI and up to **5 free connections**. Additional connections may require separate licensing arrangements.

### Internet Connection Requirement
This product requires an internet connection to deploy properly. Terraform will download and install packages during deployment including system updates, web server software, and SocketZero service configurations.

> ⚠️ **Important**: Ensure your deployment environment has outbound internet access for package downloads and AWS service communications.

## Quick Start Guide

### Prerequisites
- **Subscribe to SocketZero on AWS Marketplace**: [Get SocketZero AMI](https://aws.amazon.com/marketplace/pp/prodview-qjqz3izsnofoo)
- AWS CLI configured with appropriate permissions
- Terraform installed (>= 1.0)
- Existing Route53 public hosted zone with a registered domain using Route53 nameservers
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
socketzero_ami_id  = "ami-REPLACE_WITH_YOUR_AMI_ID"  # See "Finding Your AMI ID" below

# Optional: Custom KMS key ID for EBS encryption (if not set, uses AWS-managed key)
# kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
```

#### Step 2.5: Finding Your AMI ID

**Important**: SocketZero provides a unique AMI ID for each subscription. You need to find your specific AMI ID:

**Method 1: AWS Console**
1. Go to [SocketZero on AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-qjqz3izsnofoo)
2. Click "Continue to Subscribe" (if not already subscribed)
3. Click "Continue to Configuration"
4. Your unique AMI ID will be displayed (e.g., `ami-08245aa9e252ea9f2`)
5. Copy this AMI ID and update your `terraform.tfvars` file

**Method 2: AWS CLI**
```bash
# Find your SocketZero AMI (after subscribing)
aws ec2 describe-images \
  --owners aws-marketplace \
  --filters "Name=product-code,Values=SOCKETZERO_PRODUCT_CODE" \
  --query 'Images[0].ImageId' \
  --output text
```

**Method 3: EC2 Console**
1. Go to EC2 → Launch Instance
2. Browse more AMIs → AWS Marketplace AMIs
3. Search for "SocketZero"
4. Your subscribed AMI will show with its unique ID

#### Step 3: Deploy
```bash
# Initialize and deploy
terraform init
terraform plan
terraform apply
```

**That's it!** Your SocketZero receiver will be available at `https://ami.your-domain.com`

## Security & Encryption

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

## Architecture

This Terraform configuration creates:
- **VPC** with public/private subnets across multiple AZs
- **Application Load Balancer** with TLS termination
- **SocketZero Receiver** instance (encrypted EBS)
- **Test Web Server** for demonstration
- **Route53 DNS** record
- **Security Groups** with minimal required access
- **IAM Roles** for instance permissions

All infrastructure is defined in easy-to-read `.tf` files in the root directory.

## Project Structure

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

## Configuration Options

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_route53_zone` | Existing Route53 zone | - | ✅ |
| `receiver_port` | SocketZero receiver port | `9997` | ✅ |
| `trusted_ip_cidrs` | IPs allowed to access ALB | `[]` | ✅ |
| `socketzero_version` | SocketZero version identifier | `stable-1.0.0` | ❌ |
| `socketzero_ami_id` | Your unique SocketZero AMI ID | See Step 2.5 | ✅ |
| `kms_key_id` | KMS key for encryption | AWS managed | ❌ |

> 💡 **Important**: Each SocketZero subscription receives a unique AMI ID. You must subscribe at [AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-qjqz3izsnofoo) and find your specific AMI ID (see Step 2.5 above).

## Example Configuration

```hcl
# terraform.tfvars
aws_route53_zone = "example.com"
receiver_port    = 9997
trusted_ip_cidrs = [
  "203.0.113.1/32",    # Your IP
  "198.51.100.0/24",   # Office network
]
socketzero_version = "stable-1.0.0"
socketzero_ami_id  = "ami-08245aa9e252ea9f2"  # Your unique AMI ID from Marketplace
```

## SocketZero Configuration

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

## Load Balancer & DNS

### How it Works
- The SocketZero receiver is deployed behind an AWS Application Load Balancer (ALB)
- ALB listens on **port 443 (HTTPS)** and forwards to receiver on configured port (default: 9997)
- Only IPs in `trusted_ip_cidrs` can access the ALB
- A CNAME record (e.g., `ami.your-domain.com`) points to the ALB in Route53

### After Deployment
- Connect using: `https://ami.your-domain.com`
- Add this hostname in your SocketZero client configuration
- Use **port 443** for the connection

## Testing Your Deployment

## Install SocketZero client application

To connect to your SocketZero receiver and access the tunneled services, you need to install the SocketZero client:

### SocketZero client application

| | | |
|----------|-----|-----|
| **macOS** | [AMD64](https://radiusmethod-public-downloads.s3.us-east-1.amazonaws.com/socketzero/installer/v0.5.9/SocketZero-0.5.9-x64.pkg) | [ARM64](https://radiusmethod-public-downloads.s3.us-east-1.amazonaws.com/socketzero/installer/v0.5.9/SocketZero-0.5.9-arm64.pkg) |
| **Linux** | [AMD64](https://radiusmethod-public-downloads.s3.us-east-1.amazonaws.com/socketzero/installer/v0.5.9/SocketZero-0.5.9-x86_64.AppImage) | [ARM64](https://radiusmethod-public-downloads.s3.us-east-1.amazonaws.com/socketzero/installer/v0.5.9/SocketZero-0.5.9-arm64.AppImage) |
| **Windows** | [AMD64](https://radiusmethod-public-downloads.s3.us-east-1.amazonaws.com/socketzero/installer/v0.5.9/SocketZero-0.5.9-x64.exe) | [ARM64](https://radiusmethod-public-downloads.s3.us-east-1.amazonaws.com/socketzero/installer/v0.5.9/SocketZero-0.5.9-arm64.exe) |

#### Linux Installation

Linux installation requires a few additional steps:

1. Download the AppImage from the table above
2. Make it executable: `chmod +x SocketZero.AppImage`
3. Run it: `./SocketZero.AppImage`
4. Linux will prompt for sudo password to install the service (on first launch)
5. The app launches normally

## Testing Your Setup

1. **Connect with SocketZero Client**
   - Open the SocketZero client application and select the "+" symbol
   - Enter a **Name** such as Test-Web-Server
   - Enter the following **Host name / address**: `ami.your-domain.com`
2. **Open browser** and navigate to: `http://web-server.apps.socketzero.com`
3. **Expected result**: You should see "Hello World from [hostname]"
4. **Verify tunnel**: The traffic is flowing through your SocketZero receiver to the private web server

If you see the web page, congratulations! Your SocketZero deployment is working correctly.

### Security Notes

- **Client Authentication**: The client connects securely to your receiver using HTTPS
- **Zero Trust**: No direct access to private resources without going through SocketZero
- **Encrypted Tunnels**: All traffic between client and receiver is encrypted

### Verification Steps

- **Check EC2 console**: Confirm encrypted volumes are enabled
- **Verify security groups**: Only trusted IPs can access the load balancer  
- **Test tunnel access**: Private web server accessible only through SocketZero

## Adding Additional Tunnels

After your SocketZero deployment is working, you can add tunnels to other applications and services.

### Requirements for Additional Tunnels

**Network Accessibility:**
- Target applications/assets must be accessible from the SocketZero receiver instance
- This means they should be in the same VPC, connected VPCs, or accessible via VPN/Transit Gateway
- Security groups must allow traffic from the SocketZero receiver to the target service

**Common Scenarios:**
- **Same VPC**: Applications in private subnets of the `socketzero-ami` VPC
- **Connected VPCs**: Applications in peered VPCs or Transit Gateway connected networks
- **On-premises**: Applications accessible via VPN or Direct Connect
- **Public services**: Internet-accessible applications (with proper security)

### Adding a New Tunnel

1. **Verify Network Connectivity**:
   Test connectivity from the SocketZero receiver to your target service:
   ```bash
   # Connect to SocketZero receiver via SSH or Session Manager
   ssh -i your-key.pem ec2-user@<receiver-public-ip>
   # OR: EC2 → Instances → socketzero-receiver → Connect → Session Manager
   
   # Test connectivity (replace with your target IP/hostname and port)
   telnet 10.0.1.100 3306  # Example: MySQL database
   curl -I http://10.0.2.50:8080  # Example: Web application
   ```

2. **Update Security Groups** (if needed):
   - Ensure target service security groups allow traffic from SocketZero receiver
   - Update receiver security group if additional outbound rules are needed

3. **Update SocketZero Configuration**:
   ```bash
   # Connect to SocketZero receiver
   # Backup current configuration
   sudo cp /opt/socketzero/config.json /opt/socketzero/config.json.backup
   
   # Edit configuration to add new tunnel
   sudo nano /opt/socketzero/config.json
   ```

4. **Example Updated Configuration**:
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
         "targetHost": "10.10.128.45",
         "friendlyName": "Web Server Tunnel",
         "roles": ["admin"]
       },
       {
         "hostname": "database.apps.socketzero.com",
         "listenPort": 3306,
         "targetPort": 3306,
         "transport": "tcp",
         "targetHost": "10.0.1.100",
         "friendlyName": "MySQL Database",
         "roles": ["admin"]
       },
       {
         "hostname": "api.apps.socketzero.com",
         "listenPort": 8080,
         "targetPort": 8080,
         "transport": "tcp",
         "targetHost": "internal-api.company.local",
         "friendlyName": "Internal API",
         "roles": ["admin"]
       }
     ]
   }
   ```

5. **Apply Configuration Changes**:
   ```bash
   # Validate JSON syntax
   cat /opt/socketzero/config.json | jq
   
   # Restart SocketZero service
   sudo systemctl restart socketzero-receiver
   
   # Verify service is running
   sudo systemctl status socketzero-receiver
   
   # Check logs for any errors
   sudo journalctl -u socketzero-receiver -f
   ```

6. **Test New Tunnels**:
   - Connect with your SocketZero client
   - Access the new tunnel endpoints:
     - `http://database.apps.socketzero.com:3306`
     - `http://api.apps.socketzero.com:8080`

### Tunnel Configuration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `hostname` | Client-side hostname for accessing the tunnel | `myapp.apps.socketzero.com` |
| `listenPort` | Port the tunnel listens on (client-side) | `8080` |
| `targetPort` | Port on the target service | `80` |
| `transport` | Protocol (usually `tcp`) | `tcp` |
| `targetHost` | IP or hostname of target service | `10.0.1.50` or `myservice.local` |
| `friendlyName` | Display name in SocketZero client | `My Application` |
| `roles` | Access control (typically `["admin"]`) | `["admin"]` |

### Common Tunnel Examples

**Database Access:**
```json
{
  "hostname": "postgres.apps.socketzero.com",
  "listenPort": 5432,
  "targetPort": 5432,
  "transport": "tcp",
  "targetHost": "10.0.1.200",
  "friendlyName": "PostgreSQL Database",
  "roles": ["admin"]
}
```

**SSH Access:**
```json
{
  "hostname": "server.apps.socketzero.com",
  "listenPort": 22,
  "targetPort": 22,
  "transport": "tcp",
  "targetHost": "10.0.2.100",
  "friendlyName": "Internal Server SSH",
  "roles": ["admin"]
}
```

**Web Applications:**
```json
{
  "hostname": "grafana.apps.socketzero.com",
  "listenPort": 3000,
  "targetPort": 3000,
  "transport": "tcp",
  "targetHost": "monitoring.internal.company.com",
  "friendlyName": "Grafana Dashboard",
  "roles": ["admin"]
}
```

### Troubleshooting Additional Tunnels

**Connection Issues:**
- Verify network connectivity from receiver to target
- Check security group rules allow required ports
- Ensure target service is running and accessible
- Test with `telnet` or `curl` from receiver instance

**Configuration Issues:**
- Validate JSON syntax with `jq`
- Check SocketZero service logs: `sudo journalctl -u socketzero-receiver -f`
- Ensure no port conflicts between tunnels
- Verify hostname uniqueness for each tunnel

### Persistent Configuration (via Terraform)

**For changes that persist across redeployments:**
- Update the template in `templates/config.json.tmpl`
- Modify variables in `terraform.tfvars`
- Re-apply Terraform: `terraform apply`

**For immediate changes on existing instance:**
- Edit the config file directly: `sudo nano /opt/socketzero/config.json`
- Restart the service: `sudo systemctl restart socketzero-receiver`

## Updates & Management

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

## Troubleshooting

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

## Support

For issues with:
- **Terraform examples**: Check this repository's issues
- **SocketZero product**: Contact support@radiusmethod.com
- **Client installation**: See [SocketZero Client Repository](https://github.com/radiusmethod/socketzero-client)
- **AWS resources**: Consult AWS documentation
- **Security/Encryption**: Review the security section above

---

**Ready to get started?** Follow the [Quick Start Guide](#-quick-start-guide) above! 
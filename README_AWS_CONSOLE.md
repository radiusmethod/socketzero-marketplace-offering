# SocketZero Deployment using AWS Console

This guide shows how to deploy the SocketZero infrastructure using the AWS Console web interface instead of Terraform. This is equivalent to the Terraform configuration in this repository.

> **💡 Looking for an easier way?** Consider using the **[Terraform configuration](README.md)** instead! It automates all the steps below and is much faster to deploy. This manual guide is provided for learning purposes and situations where Terraform isn't available.

## Table of Contents

- [Important Notes](#important-notes)
  - [SocketZero Client Application Requirement](#socketzero-client-application-requirement)
  - [Subscription Benefits](#subscription-benefits)
  - [Internet Connection Requirement](#internet-connection-requirement)
- [Prerequisites](#prerequisites)
- [Deployment Overview](#deployment-overview)
- [Step-by-Step Console Deployment](#step-by-step-console-deployment)
  - [Configuration Values to Use](#configuration-values-to-use)
  - [Step 0.5: EC2 Key Pair Setup (for SSH Access)](#step-05-ec2-key-pair-setup-for-ssh-access)
    - [Option A: Use Existing Key Pair](#option-a-use-existing-key-pair)
    - [Option B: Create New Key Pair](#option-b-create-new-key-pair)
  - [Step 1: Create VPC and Networking](#step-1-create-vpc-and-networking)
    - [1.1 Create VPC](#11-create-vpc)
    - [1.2 Create Internet Gateway](#12-create-internet-gateway)
    - [1.3 Create Subnets](#13-create-subnets)
    - [1.4 Create NAT Gateway](#14-create-nat-gateway)
    - [1.5 Create Route Tables](#15-create-route-tables)
  - [Step 2: Create Security Groups](#step-2-create-security-groups)
    - [2.1 Create Security Groups (No Rules Initially)](#21-create-security-groups-no-rules-initially)
    - [2.2 Add Security Group Rules](#22-add-security-group-rules)
  - [Step 3: Create IAM Roles and Policies](#step-3-create-iam-roles-and-policies)
    - [3.1 Create IAM Role for EC2](#31-create-iam-role-for-ec2)
  - [Step 4: Route53 and ACM Certificate](#step-4-route53-and-acm-certificate)
    - [4.1 Request ACM Certificate](#41-request-acm-certificate)
    - [4.2 Validate Certificate via DNS](#42-validate-certificate-via-dns)
  - [Step 5: Create Application Load Balancer](#step-5-create-application-load-balancer)
    - [5.1 Create Target Group](#51-create-target-group)
    - [5.2 Create Application Load Balancer](#52-create-application-load-balancer)
  - [Step 6: Launch EC2 Instances](#step-6-launch-ec2-instances)
    - [6.1 Launch Test Web Server](#61-launch-test-web-server)
    - [6.2 Launch SocketZero Receiver](#62-launch-socketzero-receiver)
    - [6.3 Configure SocketZero Receiver](#63-configure-socketzero-receiver)
    - [6.4 Register Instance with Target Group](#64-register-instance-with-target-group)
  - [Step 7: Create DNS Record](#step-7-create-dns-record)
    - [7.1 Create CNAME Record](#71-create-cname-record)
  - [Deployment Complete](#deployment-complete)
- [Install SocketZero client application](#install-socketzero-client-application)
  - [SocketZero client application](#socketzero-client-application)
  - [Linux Installation](#linux-installation)
- [Testing Your Setup](#testing-your-setup)
  - [Security Notes](#security-notes)
  - [Verification Steps](#verification-steps)
  - [Troubleshooting](#troubleshooting)
  - [Resource Summary](#resource-summary)
- [Adding Additional Tunnels](#adding-additional-tunnels)
  - [Requirements for Additional Tunnels](#requirements-for-additional-tunnels)
  - [Adding a New Tunnel](#adding-a-new-tunnel)
  - [Tunnel Configuration Parameters](#tunnel-configuration-parameters)
  - [Common Tunnel Examples](#common-tunnel-examples)
  - [Troubleshooting Additional Tunnels](#troubleshooting-additional-tunnels)
- [Cleanup](#cleanup)
  - [Partial Cleanup - Remove Demo Components Only](#partial-cleanup---remove-demo-components-only)
  - [Full Cleanup - Remove Everything](#full-cleanup---remove-everything)
  - [Cleanup Verification](#cleanup-verification)

---

## Important Notes

### SocketZero Client Application Requirement
This SocketZero AMI extends the functionality of the SocketZero Client Application and without it, this product has very limited utility. Please note that the SocketZero Client Application does not require its own licensing and is provided **free of charge** with the subscription to this SocketZero AMI offering. Client installation instructions are provided in the **[Install SocketZero client application](#install-socketzero-client-application)** section below.

### Subscription Benefits
Customers receive full access to SocketZero after subscribing to the AMI and up to **5 free connections**. Additional connections may require separate licensing arrangements.

### Internet Connection Requirement
This product requires an internet connection to deploy properly. The following packages are downloaded during deployment:

**For Test Web Server (Ubuntu):**
- System updates via `apt update`
- Nginx web server via `apt install nginx`

**For SocketZero Receiver:**
- SocketZero service updates and configuration files
- SSL/TLS certificates for secure communication

**For Infrastructure:**
- AWS service communications (Route53, ACM, Load Balancer health checks)
- DNS resolution and certificate validation

> ⚠️ **Important**: Ensure your deployment environment has outbound internet access for package downloads and AWS service communications.

## Prerequisites

- AWS account with appropriate permissions
- Subscribe to SocketZero on AWS Marketplace: [Get SocketZero AMI](https://aws.amazon.com/marketplace/pp/prodview-qjqz3izsnofoo)
- Existing Route53 public hosted zone with a registered domain using Route53 nameservers
- Your IP address for security group configuration
- EC2 Key Pair for SSH access (we'll create this if needed)

## Deployment Overview

We'll create the infrastructure in this order:
1. VPC and Networking
2. Security Groups  
3. IAM Roles and Policies
4. Route53 and ACM Certificate
5. Application Load Balancer
6. EC2 Instances

## Step-by-Step Console Deployment

### Configuration Values to Use

Before starting, note these values you'll need throughout:

```
VPC CIDR: 10.10.0.0/16
Public Subnet 1: 10.10.1.0/24 (us-east-1a)
Public Subnet 2: 10.10.2.0/24 (us-east-1b)  
Private Subnet 1: 10.10.128.0/24 (us-east-1a)
Private Subnet 2: 10.10.129.0/24 (us-east-1b)
Your Domain: your-domain.com
Your IP: YOUR.IP.ADDRESS/32
Receiver Port: 9997
SocketZero AMI: ami-REPLACE_WITH_YOUR_AMI_ID (find yours in AWS Marketplace)
```

### Step 0.5: EC2 Key Pair Setup (for SSH Access)

#### Option A: Use Existing Key Pair

If you already have an EC2 key pair in the `us-east-1` region:

1. **Check Existing Key Pairs**:
   - Go to AWS Console → Services → EC2
   - In left menu: Network & Security → Key Pairs
   - Note the name of your existing key pair

2. **Verify Private Key Access**:
   - Ensure you have the `.pem` file for your key pair
   - Set proper permissions: `chmod 400 your-key.pem`

3. **Use in Later Steps**:
   - When prompted for key pair selection, choose your existing key pair
   - Skip to Step 1

#### Option B: Create New Key Pair

If you don't have a key pair or want to create a new one:

1. **Navigate to EC2 Key Pairs**:
   - Go to AWS Console → Services → EC2
   - In left menu: Network & Security → Key Pairs
   - Click "Create key pair"

2. **Configure Key Pair**:
   - **Name**: `socketzero-keypair`
   - **Key pair type**: RSA
   - **Private key file format**: 
     - Choose `.pem` for macOS/Linux
     - Choose `.ppk` for Windows (PuTTY)
   - Click "Create key pair"

3. **Save Private Key**:
   - The private key file will automatically download
   - **Important**: Save this file securely - you cannot download it again
   - Set proper permissions (Linux/macOS): `chmod 400 socketzero-keypair.pem`

> 💡 **Note**: Remember your key pair name for use in the EC2 instance launch steps below.

### Step 1: Create VPC and Networking

### 1.1 Create VPC

1. **Navigate to VPC Dashboard**:
   - Go to AWS Console → Services → VPC
   - Click "Create VPC"

2. **Configure VPC**:
   - **Resources to create**: VPC only
   - **Name tag**: `socketzero-ami`
   - **IPv4 CIDR block**: `10.10.0.0/16`
   - **IPv6 CIDR block**: No IPv6 CIDR block
   - **Tenancy**: Default
   - Click "Create VPC"

3. **Enable DNS Settings**:
   - Select your new VPC
   - Actions → Edit VPC settings
   - ✅ Check "Enable DNS resolution"
   - ✅ Check "Enable DNS hostnames"
   - Click "Save changes"

### 1.2 Create Internet Gateway

1. **Create Internet Gateway**:
   - In VPC Dashboard → Internet gateways
   - Click "Create internet gateway"
   - **Name tag**: `socketzero-ami`
   - Click "Create internet gateway"

2. **Attach to VPC**:
   - Select the gateway → Actions → Attach to VPC
   - **Available VPCs**: Select `socketzero-ami`
   - Click "Attach internet gateway"

### 1.3 Create Subnets

**Create Public Subnet 1:**
1. Go to VPC Dashboard → Subnets → Create subnet
2. **VPC ID**: Select `socketzero-ami`
3. **Subnet name**: `socketzero-ami-public-us-east-1a`
4. **Availability Zone**: us-east-1a
5. **IPv4 CIDR block**: `10.10.1.0/24`
6. Click "Create subnet"

**Create Public Subnet 2:**
1. Click "Create subnet"
2. **VPC ID**: Select `socketzero-ami`
3. **Subnet name**: `socketzero-ami-public-us-east-1b`
4. **Availability Zone**: us-east-1b
5. **IPv4 CIDR block**: `10.10.2.0/24`
6. Click "Create subnet"

**Create Private Subnet 1:**
1. Click "Create subnet"
2. **VPC ID**: Select `socketzero-ami`
3. **Subnet name**: `socketzero-ami-private-us-east-1a`
4. **Availability Zone**: us-east-1a
5. **IPv4 CIDR block**: `10.10.128.0/24`
6. Click "Create subnet"

**Create Private Subnet 2:**
1. Click "Create subnet"
2. **VPC ID**: Select `socketzero-ami`
3. **Subnet name**: `socketzero-ami-private-us-east-1b`
4. **Availability Zone**: us-east-1b
5. **IPv4 CIDR block**: `10.10.129.0/24`
6. Click "Create subnet"

### 1.4 Create NAT Gateway

1. **Allocate Elastic IP**:
   - Go to VPC Dashboard → Elastic IPs
   - Click "Allocate Elastic IP address"
   - **Public IPv4 address pool**: Amazon's pool of IPv4 addresses
   - Click "Allocate"

2. **Create NAT Gateway**:
   - Go to VPC Dashboard → NAT gateways
   - Click "Create NAT gateway"
   - **Name**: `socketzero-ami`
   - **Subnet**: Select `socketzero-ami-public-us-east-1a`
   - **Connectivity type**: Public
   - **Elastic IP allocation ID**: Select the IP you just allocated
   - Click "Create NAT gateway"

### 1.5 Create Route Tables

**Create Public Route Table:**
1. Go to VPC Dashboard → Route tables → Create route table
2. **Name**: `socketzero-ami-public`
3. **VPC**: Select `socketzero-ami`
4. Click "Create route table"

**Configure Public Routes:**
1. Select the public route table → Routes tab → Edit routes
2. Click "Add route"
3. **Destination**: `0.0.0.0/0`
4. **Target**: Internet Gateway → Select `socketzero-ami`
5. Click "Save changes"

**Associate Public Subnets:**
1. Select public route table → Subnet associations tab → Edit subnet associations
2. ✅ Check both public subnets (`socketzero-ami-public-us-east-1a` and `socketzero-ami-public-us-east-1b`)
3. Click "Save associations"

**Create Private Route Table:**
1. Create route table → **Name**: `socketzero-ami-private`
2. **VPC**: Select `socketzero-ami`
3. Click "Create route table"

**Configure Private Routes:**
1. Select private route table → Routes tab → Edit routes
2. Click "Add route"
3. **Destination**: `0.0.0.0/0`
4. **Target**: NAT Gateway → Select `socketzero-ami`
5. Click "Save changes"

**Associate Private Subnets:**
1. Select private route table → Subnet associations tab → Edit subnet associations
2. ✅ Check both private subnets (`socketzero-ami-private-us-east-1a` and `socketzero-ami-private-us-east-1b`)
3. Click "Save associations"

### Step 2: Create Security Groups

### 2.1 Create Security Groups (No Rules Initially)

**Create Load Balancer Security Group:**
1. Go to VPC Dashboard → Security groups → Create security group
2. **Security group name**: `socketzero-receiver-lb`
3. **Description**: `Security group for SocketZero receiver load balancer`
4. **VPC**: Select `socketzero-ami`
5. **Leave inbound and outbound rules empty for now**
6. Click "Create security group"

**Create SocketZero Receiver Security Group:**
1. Click "Create security group"
2. **Security group name**: `socketzero-receiver`
3. **Description**: `Security group for SocketZero receiver`
4. **VPC**: Select `socketzero-ami`
5. **Leave inbound and outbound rules empty for now**
6. Click "Create security group"

**Create Web Server Security Group:**
1. Click "Create security group"
2. **Security group name**: `web-server-test`
3. **Description**: `Security group for test web server`
4. **VPC**: Select `socketzero-ami`
5. **Leave inbound and outbound rules empty for now**
6. Click "Create security group"

### 2.2 Add Security Group Rules

Now that all security groups exist, we can add rules that reference each other:

**Configure Load Balancer Security Group Rules:**
1. Select `socketzero-receiver-lb` security group
2. **Inbound rules** tab → Edit inbound rules → Add rule:
   - **Type**: HTTPS
   - **Port range**: 443
   - **Source**: Custom → `YOUR.IP.ADDRESS/32` (replace with your IP)
   - **Description**: `Allow HTTPS from trusted IPs`
3. **Outbound rules** tab → Edit outbound rules → Add rule:
   - **Type**: Custom TCP
   - **Port range**: 9997
   - **Destination**: Custom → Select `socketzero-receiver` security group
   - **Description**: `Allow outbound to receiver`
4. Click "Save rules"

**Configure Receiver Security Group Rules:**
1. Select `socketzero-receiver` security group
2. **Inbound rules** tab → Edit inbound rules:
   - **Add rule 1**:
     - **Type**: Custom TCP
     - **Port range**: 9997
     - **Source**: Custom → Select `socketzero-receiver-lb` security group
     - **Description**: `Allow receiver port from load balancer`
   - **Add rule 2** (for SSH access):
     - **Type**: SSH
     - **Port range**: 22
     - **Source**: Custom → `YOUR.IP.ADDRESS/32` (replace with your IP)
     - **Description**: `Allow SSH from trusted IPs`
3. **Outbound rules**: Leave as default (All traffic allowed)
4. Click "Save rules"

**Configure Web Server Security Group Rules:**
1. Select `web-server-test` security group
2. **Inbound rules** tab → Edit inbound rules:
   - **Add rule 1**:
     - **Type**: HTTP
     - **Port range**: 80
     - **Source**: Custom → `10.10.0.0/16`
     - **Description**: `Allow HTTP from VPC range`
   - **Add rule 2** (for SSH access):
     - **Type**: SSH
     - **Port range**: 22
     - **Source**: Custom → `10.10.0.0/16`
     - **Description**: `Allow SSH from VPC range`
3. **Outbound rules**: Leave as default (All traffic allowed)
4. Click "Save rules"

### Step 3: Create IAM Roles and Policies

### 3.1 Create IAM Role for EC2

1. **Navigate to IAM**:
   - Go to AWS Console → Services → IAM
   - Click "Roles" → Create role

2. **Select Trusted Entity**:
   - **Trusted entity type**: AWS service
   - **Service or use case**: EC2
   - Click "Next"

3. **Add Permissions**:
   - Search for `AmazonSSMManagedInstanceCore`
   - ✅ Check the policy
   - Click "Next"

4. **Configure Role**:
   - **Role name**: `socketzero-ami-role`
   - **Description**: `IAM role for SocketZero EC2 instances with SSM access`
   - Click "Create role"

### Step 4: Route53 and ACM Certificate

### 4.1 Request ACM Certificate

1. **Navigate to Certificate Manager**:
   - Go to AWS Console → Services → Certificate Manager
   - **Important**: Make sure you're in **us-east-1** region (ALB requirement)
   - Click "Request a certificate"

2. **Configure Certificate**:
   - **Certificate type**: Request a public certificate
   - Click "Next"

3. **Domain Names**:
   - **Fully qualified domain name**: `ami.your-domain.com` (replace with your domain)
   - Click "Next"

4. **Validation Method**:
   - **Validation method**: DNS validation
   - Click "Next"

5. **Tags** (optional):
   - Add tags if desired
   - Click "Request"

### 4.2 Validate Certificate via DNS

1. **Get Validation Records**:
   - Click on your certificate
   - In the **Domain** section, click "Create records in Route 53"
   - Click "Create records"

2. **Wait for Validation**:
   - Status will change from "Pending validation" to "Issued"
   - This typically takes 5-10 minutes

### Step 5: Create Application Load Balancer

### 5.1 Create Target Group

1. **Navigate to Load Balancers**:
   - Go to AWS Console → Services → EC2
   - In left menu: Load Balancing → Target groups
   - Click "Create target group"

2. **Configure Target Group**:
   - **Target type**: Instances
   - **Target group name**: `socketzero-receiver`
   - **Protocol**: HTTP
   - **Port**: 9997
   - **VPC**: Select `socketzero-ami`

3. **Health Check Settings**:
   - **Health check protocol**: HTTP
   - **Health check path**: `/ping`
   - **Advanced health check settings**:
     - **Port**: Traffic port
     - **Healthy threshold**: 5
     - **Unhealthy threshold**: 2
     - **Timeout**: 5 seconds
     - **Interval**: 30 seconds
     - **Success codes**: 200

4. **Register Targets**:
   - Skip for now (we'll add after creating EC2 instance)
   - Click "Next" → "Create target group"

### 5.2 Create Application Load Balancer

1. **Create Load Balancer**:
   - Go to Load Balancing → Load balancers
   - Click "Create load balancer"
   - Choose "Application Load Balancer"

2. **Basic Configuration**:
   - **Load balancer name**: `socketzero-receiver`
   - **Scheme**: Internet-facing
   - **IP address type**: IPv4

3. **Network Mapping**:
   - **VPC**: Select `socketzero-ami`
   - **Mappings**: 
     - ✅ us-east-1a → Select `socketzero-ami-public-us-east-1a`
     - ✅ us-east-1b → Select `socketzero-ami-public-us-east-1b`

4. **Security Groups**:
   - Remove default security group
   - ✅ Select `socketzero-receiver-lb`

5. **Listeners and Routing**:
   - **Protocol**: HTTPS
   - **Port**: 443
   - **Default action**: Forward to target group → `socketzero-receiver`

6. **Secure Listener Settings**:
   - **Security policy**: ELBSecurityPolicy-TLS13-1-2-Res-2021-06
   - **Default SSL/TLS certificate**: From ACM
   - **Certificate**: Select your `ami.your-domain.com` certificate

7. Click "Create load balancer"

### Step 6: Launch EC2 Instances

### 6.1 Launch Test Web Server

1. **Navigate to EC2**:
   - Go to AWS Console → Services → EC2
   - Click "Launch instance"

2. **Basic Configuration**:
   - **Name**: `test-web-server`
   - **AMI**: Ubuntu Server 22.04 LTS (search for "Ubuntu")
   - **Instance type**: t2.micro

3. **Key Pair**:
   - **Key pair**: Select your key pair (e.g., `socketzero-keypair` or your existing key pair)

4. **Network Settings**:
   - Click "Edit"
   - **VPC**: Select `socketzero-ami`
   - **Subnet**: Select `socketzero-ami-private-us-east-1a`
   - **Auto-assign public IP**: Disable
   - **Firewall (security groups)**: Select existing → `web-server-test`

5. **Configure Storage**:
   - **Size**: 8 GiB
   - **Volume type**: gp3
   - **Encrypted**: ✅ Yes
   - **KMS key**: (default) aws/ebs or select your custom key

6. **Advanced Details**:
   - **IAM instance profile**: `socketzero-ami-role`
   - **User data** (paste this script):
```bash
#!/bin/bash
apt update -y
apt install -y nginx
echo "Hello World from $(hostname -f)" > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx
```

7. Click "Launch instance"

### 6.2 Launch SocketZero Receiver

1. **Launch Instance**:
   - Click "Launch instance"
   - **Name**: `socketzero-receiver`

2. **AMI Selection**:
   - **My AMIs** → **AWS Marketplace AMIs**
   - Search for "SocketZero" 
   - **Important**: Select YOUR unique SocketZero AMI (each subscription has a different AMI ID)
   - If you don't see it, ensure you've subscribed at the [AWS Marketplace](https://aws.amazon.com/marketplace/pp/prodview-qjqz3izsnofoo)

3. **Instance Configuration**:
   - **Instance type**: t3.micro
   - **Key pair**: Select your key pair (e.g., `socketzero-keypair` or your existing key pair)

4. **Network Settings**:
   - **VPC**: Select `socketzero-ami`
   - **Subnet**: Select `socketzero-ami-public-us-east-1a`
   - **Auto-assign public IP**: Enable
   - **Firewall**: Select existing → `socketzero-receiver`

5. **Configure Storage**:
   - **Size**: 8 GiB
   - **Volume type**: gp3
   - **Encrypted**: ✅ Yes

6. **Advanced Details**:
   - **IAM instance profile**: `socketzero-ami-role`

7. **Tags**:
   - Add tags:
     - **Key**: SocketZeroVersion, **Value**: stable-1.0.0
     - **Key**: AMI, **Value**: your-unique-ami-id (e.g., ami-08245aa9e252ea9f2)

8. Click "Launch instance"

### 6.3 Configure SocketZero Receiver

After both instances launch, we need to configure SocketZero with the tunnel settings:

1. **Get Web Server Private IP**:
   - Go to EC2 → Instances
   - Select `test-web-server`
   - Note the **Private IPv4 address** (e.g., 10.10.128.45)

2. **Connect to SocketZero Receiver**:
   - Select `socketzero-receiver` instance
   - Connect → Session Manager (or SSH if you prefer)

3. **Create SocketZero Configuration**:
   Replace "$WEB_SERVER_IP" with your actual web server IP:
```bash
# Create the SocketZero configuration file
sudo tee /opt/socketzero/config.json > /dev/null << EOF
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
      "targetHost": "$WEB_SERVER_IP",
      "friendlyName": "Web Server Tunnel",
      "roles": ["admin"]
    }
  ]
}
EOF

# Restart SocketZero service to apply configuration
sudo systemctl restart socketzero-receiver

# Verify service is running
sudo systemctl status socketzero-receiver
```

4. **Verify Configuration**:
```bash
# Check that the config file was created correctly
cat /opt/socketzero/config.json | jq

# Check service logs if needed
sudo journalctl -u socketzero-receiver -f
```

### 6.4 Register Instance with Target Group

1. **Add Target to Target Group**:
   - Go to EC2 → Load Balancing → Target groups
   - Select `socketzero-receiver`
   - **Targets** tab → "Register targets"
   - Select your `socketzero-receiver` instance
   - **Port**: 9997
   - Click "Include as pending below" → "Register pending targets"

2. **Wait for Health Check**:
   - Target should change from "initial" → "healthy" (takes 2-3 minutes)

### Step 7: Create DNS Record

### 7.1 Create CNAME Record

1. **Get Load Balancer DNS**:
   - Go to EC2 → Load Balancing → Load balancers
   - Select `socketzero-receiver`
   - Copy the **DNS name** (e.g., `socketzero-receiver-123456789.us-east-1.elb.amazonaws.com`)

2. **Create Route53 Record**:
   - Go to AWS Console → Services → Route 53
   - **Hosted zones** → Select your domain
   - Click "Create record"

3. **Configure Record**:
   - **Record name**: `ami`
   - **Record type**: CNAME
   - **Value**: Paste the load balancer DNS name
   - **TTL**: 300
   - Click "Create records"

### Deployment Complete

Your SocketZero infrastructure is now deployed using the AWS Console!

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

- **Zero Trust**: No direct access to private resources without going through SocketZero
- **Encrypted Tunnels**: All traffic between client and receiver is encrypted
- **Private Network Access**: Web server in private subnet is only accessible via SocketZero tunnel

### Verification Steps

1. **Check Target Group Health**:
   - EC2 → Target groups → `socketzero-receiver`
   - Targets tab → Status should be "healthy"

2. **Test Load Balancer**:
   - Wait 5-10 minutes for DNS propagation
   - Visit `https://ami.your-domain.com`
   - Should show SocketZero login/interface

3. **Test SSL Certificate**:
   - Browser should show valid SSL certificate
   - No security warnings

4. **Access Instances via SSM**:
   - EC2 → Instances → Select instance → Connect → Session Manager
   - No SSH keys required!

5. **Access Instances via SSH** (Alternative):
   - **SocketZero Receiver** (public subnet):
     ```bash
     ssh -i your-key-pair.pem ec2-user@<receiver-public-ip>
     ```
   - **Test Web Server** (private subnet, via receiver as bastion):
     ```bash
     # First SSH to receiver, then SSH to web server
     ssh -i your-key-pair.pem ec2-user@<receiver-public-ip>
     ssh ec2-user@<web-server-private-ip>
     ```

### Troubleshooting

**Target Group Unhealthy:**
- Check security groups allow port 9997
- Verify SocketZero service is running: `
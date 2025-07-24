# SocketZero Deployment using AWS CLI

This guide shows how to deploy the SocketZero infrastructure using AWS CLI commands instead of Terraform. This is equivalent to the Terraform configuration in this repository.

> **💡 Looking for an easier way?** Consider using the **[Terraform configuration](README.md)** instead! It automates all the steps below and is much faster to deploy. This manual guide is provided for learning purposes and situations where Terraform isn't available.

## Table of Contents

- [Important Notes](#important-notes)
  - [SocketZero Client Application Requirement](#socketzero-client-application-requirement)
  - [Subscription Benefits](#subscription-benefits)
  - [Internet Connection Requirement](#internet-connection-requirement)
  - [SSH Access](#ssh-access)
- [Prerequisites](#prerequisites)
- [Deployment Overview](#deployment-overview)
- [Step-by-Step Deployment](#step-by-step-deployment)
  - [Variables Setup](#variables-setup)
  - [Step 1: Create VPC and Networking](#step-1-create-vpc-and-networking)
  - [Step 2: Create Security Groups](#step-2-create-security-groups)
  - [Step 3: Create IAM Roles and Policies](#step-3-create-iam-roles-and-policies)
  - [Step 4: Route53 and ACM Certificate](#step-4-route53-and-acm-certificate)
  - [Step 5: Create Application Load Balancer](#step-5-create-application-load-balancer)
  - [Step 6: Launch EC2 Instances](#step-6-launch-ec2-instances)
  - [Step 7: Configure SocketZero Receiver](#step-7-configure-socketzero-receiver)
  - [Step 8: Create DNS Record](#step-8-create-dns-record)
- [Deployment Complete](#deployment-complete)
- [Install SocketZero client application](#install-socketzero-client-application)
  - [SocketZero client application](#socketzero-client-application)
  - [Linux Installation](#linux-installation)
  - [Configuration](#configuration)
- [Testing Your Setup](#testing-your-setup)

---

## Important Notes

### SocketZero Client Application Requirement
This SocketZero AMI extends the functionality of the SocketZero Client Application and without it, this product has very limited utility. Please note that the SocketZero Client Application does not require its own licensing and is provided **free of charge** with the subscription to this SocketZero AMI offering. The SocketZero Client Application installation instructions are provided in the **[Install SocketZero client application](#install-socketzero-client-application)** section below.

### Subscription Benefits
Customers receive full access to SocketZero after subscribing to the AMI and up to **5 free connections**. Additional connections may require separate licensing arrangements.

### Internet Connection Requirement
This product requires an internet connection to deploy properly. The test web server downloads and installs nginx during deployment.

> ⚠️ **Important**: Ensure your deployment environment has outbound internet access for package downloads and AWS service communications.

### SSH Access
The SocketZero AMI uses **`ubuntu`** as the SSH username.

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- Subscribe to SocketZero on AWS Marketplace: [Get SocketZero AMI](https://aws.amazon.com/marketplace/pp/prodview-qjqz3izsnofoo)
- Existing Route53 public hosted zone with a registered domain using Route53 nameservers
- jq installed for JSON parsing

## Deployment Overview

We'll create the infrastructure in this order:
1. VPC and Networking
2. Security Groups
3. IAM Roles and Policies
4. Route53 and ACM Certificate
5. Application Load Balancer
6. EC2 Instances

## Step-by-Step Deployment

### Variables Setup

First, set your environment variables:

```bash
# Configuration variables - UPDATE THESE VALUES
export AWS_REGION="us-east-1"
export VPC_CIDR="10.10.0.0/16"
export PUBLIC_SUBNET_1_CIDR="10.10.1.0/24"
export PUBLIC_SUBNET_2_CIDR="10.10.2.0/24"
export PRIVATE_SUBNET_1_CIDR="10.10.128.0/24"
export PRIVATE_SUBNET_2_CIDR="10.10.129.0/24"
export ROUTE53_ZONE="your-domain.com"  # UPDATE THIS
export TRUSTED_IP_CIDR="YOUR.IP.ADDRESS/32"  # UPDATE THIS
export RECEIVER_PORT="9997"
export SOCKETZERO_AMI_ID="ami-REPLACE_WITH_YOUR_AMI_ID"  # Get from AWS Marketplace
export KMS_KEY_ID=""  # Optional: Your KMS key ARN

# Get availability zones
export AZ1=$(aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[0].ZoneName' --output text)
export AZ2=$(aws ec2 describe-availability-zones --region $AWS_REGION --query 'AvailabilityZones[1].ZoneName' --output text)

echo "Using AZs: $AZ1 and $AZ2"

# IMPORTANT: Find your unique SocketZero AMI ID
# Method 1: AWS Console - Go to Marketplace → SocketZero → Continue to Configuration
# Method 2: CLI command (run this after subscribing):
# aws ec2 describe-images --owners aws-marketplace --filters "Name=name,Values=*SocketZero*" --query 'Images[0].ImageId' --output text

echo "Update SOCKETZERO_AMI_ID with your unique AMI ID before proceeding!"
```

### Step 1: Create VPC and Networking

```bash
# Create VPC
export VPC_ID=$(aws ec2 create-vpc \
  --cidr-block $VPC_CIDR \
  --query 'Vpc.VpcId' \
  --output text)

aws ec2 create-tags \
  --resources $VPC_ID \
  --tags Key=Name,Value=socketzero-ami

# Enable DNS support and hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames

echo "Created VPC: $VPC_ID"

# Create Internet Gateway
export IGW_ID=$(aws ec2 create-internet-gateway \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID

aws ec2 create-tags \
  --resources $IGW_ID \
  --tags Key=Name,Value=socketzero-ami

echo "Created Internet Gateway: $IGW_ID"

# Create public subnets
export PUBLIC_SUBNET_1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_1_CIDR \
  --availability-zone $AZ1 \
  --query 'Subnet.SubnetId' \
  --output text)

export PUBLIC_SUBNET_2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PUBLIC_SUBNET_2_CIDR \
  --availability-zone $AZ2 \
  --query 'Subnet.SubnetId' \
  --output text)

# Tag public subnets
aws ec2 create-tags \
  --resources $PUBLIC_SUBNET_1_ID \
  --tags Key=Name,Value=socketzero-ami-public-$AZ1

aws ec2 create-tags \
  --resources $PUBLIC_SUBNET_2_ID \
  --tags Key=Name,Value=socketzero-ami-public-$AZ2

# Create private subnets
export PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_1_CIDR \
  --availability-zone $AZ1 \
  --query 'Subnet.SubnetId' \
  --output text)

export PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $PRIVATE_SUBNET_2_CIDR \
  --availability-zone $AZ2 \
  --query 'Subnet.SubnetId' \
  --output text)

# Tag private subnets
aws ec2 create-tags \
  --resources $PRIVATE_SUBNET_1_ID \
  --tags Key=Name,Value=socketzero-ami-private-$AZ1

aws ec2 create-tags \
  --resources $PRIVATE_SUBNET_2_ID \
  --tags Key=Name,Value=socketzero-ami-private-$AZ2

echo "Created subnets:"
echo "  Public: $PUBLIC_SUBNET_1_ID, $PUBLIC_SUBNET_2_ID"
echo "  Private: $PRIVATE_SUBNET_1_ID, $PRIVATE_SUBNET_2_ID"

# Create Elastic IP for NAT Gateway
export EIP_ALLOC_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --query 'AllocationId' \
  --output text)

# Create NAT Gateway
export NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_1_ID \
  --allocation-id $EIP_ALLOC_ID \
  --query 'NatGateway.NatGatewayId' \
  --output text)

aws ec2 create-tags \
  --resources $NAT_GW_ID \
  --tags Key=Name,Value=socketzero-ami

echo "Created NAT Gateway: $NAT_GW_ID"

# Wait for NAT Gateway to be available
echo "Waiting for NAT Gateway to be available..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW_ID

# Create route tables
export PUBLIC_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

export PRIVATE_RT_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.RouteTableId' \
  --output text)

# Tag route tables
aws ec2 create-tags \
  --resources $PUBLIC_RT_ID \
  --tags Key=Name,Value=socketzero-ami-public

aws ec2 create-tags \
  --resources $PRIVATE_RT_ID \
  --tags Key=Name,Value=socketzero-ami-private

# Create routes
aws ec2 create-route \
  --route-table-id $PUBLIC_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

aws ec2 create-route \
  --route-table-id $PRIVATE_RT_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW_ID

# Associate subnets with route tables
aws ec2 associate-route-table \
  --subnet-id $PUBLIC_SUBNET_1_ID \
  --route-table-id $PUBLIC_RT_ID

aws ec2 associate-route-table \
  --subnet-id $PUBLIC_SUBNET_2_ID \
  --route-table-id $PUBLIC_RT_ID

aws ec2 associate-route-table \
  --subnet-id $PRIVATE_SUBNET_1_ID \
  --route-table-id $PRIVATE_RT_ID

aws ec2 associate-route-table \
  --subnet-id $PRIVATE_SUBNET_2_ID \
  --route-table-id $PRIVATE_RT_ID

echo "VPC networking setup complete!"
```

### Step 2: Create Security Groups

```bash
# Load Balancer Security Group
export LB_SG_ID=$(aws ec2 create-security-group \
  --group-name socketzero-receiver-lb \
  --description "Security group for SocketZero receiver load balancer" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow HTTPS from trusted IPs
aws ec2 authorize-security-group-ingress \
  --group-id $LB_SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr $TRUSTED_IP_CIDR

echo "Created LB Security Group: $LB_SG_ID"

# SocketZero Receiver Security Group
export RECEIVER_SG_ID=$(aws ec2 create-security-group \
  --group-name socketzero-receiver \
  --description "Security group for SocketZero receiver" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow receiver port from load balancer
aws ec2 authorize-security-group-ingress \
  --group-id $RECEIVER_SG_ID \
  --protocol tcp \
  --port $RECEIVER_PORT \
  --source-group $LB_SG_ID

echo "Created Receiver Security Group: $RECEIVER_SG_ID"

# Web Server Security Group
export WEB_SG_ID=$(aws ec2 create-security-group \
  --group-name web-server-test \
  --description "Security group for test web server" \
  --vpc-id $VPC_ID \
  --query 'GroupId' \
  --output text)

# Allow HTTP from VPC
aws ec2 authorize-security-group-ingress \
  --group-id $WEB_SG_ID \
  --protocol tcp \
  --port 80 \
  --cidr $VPC_CIDR

echo "Created Web Server Security Group: $WEB_SG_ID"

# Add egress rule for LB to receiver
aws ec2 authorize-security-group-egress \
  --group-id $LB_SG_ID \
  --protocol tcp \
  --port $RECEIVER_PORT \
  --source-group $RECEIVER_SG_ID
```

### Step 3: Create IAM Roles and Policies

```bash
# Create IAM role for EC2 instances
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role \
  --role-name socketzero-ami-role \
  --assume-role-policy-document file://trust-policy.json

# Attach SSM policy for secure access
aws iam attach-role-policy \
  --role-name socketzero-ami-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Create instance profile
aws iam create-instance-profile \
  --instance-profile-name socketzero-ami

aws iam add-role-to-instance-profile \
  --instance-profile-name socketzero-ami \
  --role-name socketzero-ami-role

echo "Created IAM role and instance profile"

# Clean up temp file
rm trust-policy.json
```

### Step 4: Route53 and ACM Certificate

```bash
# Get hosted zone ID
export HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='${ROUTE53_ZONE}.'].Id" \
  --output text | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
  echo "Error: Hosted zone for $ROUTE53_ZONE not found"
  exit 1
fi

echo "Using hosted zone: $HOSTED_ZONE_ID"

# Request ACM certificate
export CERT_ARN=$(aws acm request-certificate \
  --domain-name "ami.${ROUTE53_ZONE}" \
  --validation-method DNS \
  --query 'CertificateArn' \
  --output text)

echo "Requested certificate: $CERT_ARN"

# Wait a moment for the certificate to be processed
sleep 10

# Get validation records
aws acm describe-certificate \
  --certificate-arn $CERT_ARN \
  --query 'Certificate.DomainValidationOptions[0]' > validation_record.json

export VALIDATION_NAME=$(cat validation_record.json | jq -r '.ResourceRecord.Name')
export VALIDATION_VALUE=$(cat validation_record.json | jq -r '.ResourceRecord.Value')

# Create DNS validation record
cat > dns-validation-record.json << EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "$VALIDATION_NAME",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$VALIDATION_VALUE"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://dns-validation-record.json

echo "Created DNS validation record"

# Wait for certificate validation
echo "Waiting for certificate validation (this may take several minutes)..."
aws acm wait certificate-validated --certificate-arn $CERT_ARN

echo "Certificate validated successfully!"

# Clean up temp files
rm validation_record.json dns-validation-record.json
```

### Step 5: Create Application Load Balancer

```bash
# Create Application Load Balancer
export ALB_ARN=$(aws elbv2 create-load-balancer \
  --name socketzero-receiver \
  --subnets $PUBLIC_SUBNET_1_ID $PUBLIC_SUBNET_2_ID \
  --security-groups $LB_SG_ID \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

# Get ALB DNS name
export ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "Created ALB: $ALB_ARN"
echo "ALB DNS: $ALB_DNS"

# Create target group
export TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
  --name socketzero-receiver \
  --protocol HTTP \
  --port $RECEIVER_PORT \
  --vpc-id $VPC_ID \
  --target-type instance \
  --health-check-enabled \
  --health-check-protocol HTTP \
  --health-check-port traffic-port \
  --health-check-path /ping \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 5 \
  --unhealthy-threshold-count 2 \
  --matcher HttpCode=200 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

echo "Created target group: $TARGET_GROUP_ARN"

# Create HTTPS listener
export LISTENER_ARN=$(aws elbv2 create-listener \
  --load-balancer-arn $ALB_ARN \
  --protocol HTTPS \
  --port 443 \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-Res-2021-06 \
  --certificates CertificateArn=$CERT_ARN \
  --default-actions Type=forward,TargetGroupArn=$TARGET_GROUP_ARN \
  --query 'Listeners[0].ListenerArn' \
  --output text)

echo "Created HTTPS listener: $LISTENER_ARN"
```

### Step 6: Launch EC2 Instances

```bash
# Get the latest Ubuntu AMI for test web server
export UBUNTU_AMI=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)

# Create web server user data
cat > web-server-userdata.sh << 'EOF'
#!/bin/bash
apt update -y
apt install -y nginx
echo "Hello World from $(hostname -f)" > /var/www/html/index.html
systemctl enable nginx
systemctl start nginx
EOF

# Launch test web server
export WEB_SERVER_ID=$(aws ec2 run-instances \
  --image-id $UBUNTU_AMI \
  --instance-type t2.micro \
  --subnet-id $PRIVATE_SUBNET_1_ID \
  --security-group-ids $WEB_SG_ID \
  --iam-instance-profile Name=socketzero-ami \
  --user-data file://web-server-userdata.sh \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={Encrypted=true,VolumeType=gp3,VolumeSize=8$([ ! -z "$KMS_KEY_ID" ] && echo ",KmsKeyId=$KMS_KEY_ID")}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=test-web-server}]' \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched web server: $WEB_SERVER_ID"

# Get web server private IP
export WEB_SERVER_IP=$(aws ec2 describe-instances \
  --instance-ids $WEB_SERVER_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

# Note: We'll configure SocketZero after launch (no user data needed for marketplace compliance)

# Launch SocketZero receiver (without user data for marketplace compliance)
export RECEIVER_ID=$(aws ec2 run-instances \
  --image-id $SOCKETZERO_AMI_ID \
  --instance-type t3.micro \
  --subnet-id $PUBLIC_SUBNET_1_ID \
  --security-group-ids $RECEIVER_SG_ID \
  --iam-instance-profile Name=socketzero-ami \
  --associate-public-ip-address \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={Encrypted=true,VolumeType=gp3,VolumeSize=8$([ ! -z "$KMS_KEY_ID" ] && echo ",KmsKeyId=$KMS_KEY_ID")}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=socketzero-receiver},{Key=SocketZeroVersion,Value=stable-1.0.0},{Key=AMI,Value=$SOCKETZERO_AMI_ID}]" \
  --query 'Instances[0].InstanceId' \
  --output text)

echo "Launched SocketZero receiver: $RECEIVER_ID"

# Wait for instances to be running
echo "Waiting for instances to be running..."
aws ec2 wait instance-running --instance-ids $RECEIVER_ID $WEB_SERVER_ID

# Register receiver with target group
aws elbv2 register-targets \
  --target-group-arn $TARGET_GROUP_ARN \
  --targets Id=$RECEIVER_ID,Port=$RECEIVER_PORT

echo "Registered receiver with target group"

# Clean up temp files
rm web-server-userdata.sh
```

### Step 7: Configure SocketZero Receiver

After instances are launched, configure SocketZero with tunnel settings:

```bash
echo "Configuring SocketZero receiver..."

# Get web server private IP for configuration
export WEB_SERVER_PRIVATE_IP=$(aws ec2 describe-instances \
  --instance-ids $WEB_SERVER_ID \
  --query 'Reservations[0].Instances[0].PrivateIpAddress' \
  --output text)

echo "Web server private IP: $WEB_SERVER_PRIVATE_IP"

# Create SocketZero configuration
cat > socketzero-config.json << EOF
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
      "targetHost": "$WEB_SERVER_PRIVATE_IP",
      "friendlyName": "Web Server Tunnel",
      "roles": ["admin"]
    }
  ]
}
EOF

# Apply configuration to receiver instance
aws ssm send-command \
  --instance-ids $RECEIVER_ID \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    'sudo tee /opt/socketzero/config.json > /dev/null << EOF',
    '$(cat socketzero-config.json)',
    'EOF',
    'sudo systemctl restart socketzero-receiver',
    'sudo systemctl status socketzero-receiver'
  ]" \
  --query 'Command.CommandId' \
  --output text

echo "SocketZero configuration applied. Check SSM Run Command for results."

# Clean up temp file
rm socketzero-config.json
```

### Step 8: Create DNS Record

```bash
# Create CNAME record pointing to ALB
cat > dns-cname-record.json << EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "ami.${ROUTE53_ZONE}",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [
          {
            "Value": "$ALB_DNS"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch file://dns-cname-record.json

echo "Created DNS CNAME record: ami.${ROUTE53_ZONE} -> $ALB_DNS"

# Clean up temp file
rm dns-cname-record.json
```

## Deployment Complete

Your SocketZero infrastructure is now deployed! 

### Access URLs
- **SocketZero Receiver**: `https://ami.${ROUTE53_ZONE}`
- **Test Web Server**: `http://web-server.apps.socketzero.com` (via SocketZero tunnel)

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

### Configuration

After installing the client:

1. **Launch SocketZero Client**
2. **Add New Profile**:
   - **Profile Name**: `My SocketZero Server`
   - **Hostname**: `ami.${ROUTE53_ZONE}` (your deployed receiver)
   - **Port**: `443`
   - **Protocol**: `HTTPS`
3. **Connect** to your profile
4. **Test the tunnel** by opening: `http://web-server.apps.socketzero.com`

### Alternative: CLI Client

For command-line usage:

**Install via npm:**
```bash
npm install -g @socketzero/cli
```

**Connect:**
```bash
socketzero connect --hostname ami.${ROUTE53_ZONE} --port 443 --ssl
```

**Check status:**
```bash
socketzero status
socketzero tunnels list
```

### Testing Your Setup

1. **Connect with SocketZero Client**
2. **Open browser** and navigate to: `http://web-server.apps.socketzero.com`
3. **Expected result**: You should see "Hello World from [hostname]"
4. **Verify tunnel**: The traffic is flowing through your SocketZero receiver to the private web server

If you see the web page, congratulations! Your SocketZero deployment is working correctly.

### Verification Commands

```bash
# Check instance status
aws ec2 describe-instances \
  --instance-ids $RECEIVER_ID $WEB_SERVER_ID \
  --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $TARGET_GROUP_ARN

# Test SSL certificate
openssl s_client -connect ami.${ROUTE53_ZONE}:443 -servername ami.${ROUTE53_ZONE} < /dev/null

# Access instances via SSM
aws ssm start-session --target $RECEIVER_ID
aws ssm start-session --target $WEB_SERVER_ID
```

### Environment Variables Summary

Save these for future reference:

```bash
echo "=== Infrastructure IDs ==="
echo "VPC_ID=$VPC_ID"
echo "PUBLIC_SUBNET_1_ID=$PUBLIC_SUBNET_1_ID"
echo "PUBLIC_SUBNET_2_ID=$PUBLIC_SUBNET_2_ID"
echo "PRIVATE_SUBNET_1_ID=$PRIVATE_SUBNET_1_ID"
echo "PRIVATE_SUBNET_2_ID=$PRIVATE_SUBNET_2_ID"
echo "LB_SG_ID=$LB_SG_ID"
echo "RECEIVER_SG_ID=$RECEIVER_SG_ID"
echo "WEB_SG_ID=$WEB_SG_ID"
echo "ALB_ARN=$ALB_ARN"
echo "TARGET_GROUP_ARN=$TARGET_GROUP_ARN"
echo "CERT_ARN=$CERT_ARN"
echo "RECEIVER_ID=$RECEIVER_ID"
echo "WEB_SERVER_ID=$WEB_SERVER_ID"
echo "HOSTED_ZONE_ID=$HOSTED_ZONE_ID"
```

## Cleanup

To delete all resources, run the cleanup commands in reverse order:

```bash
# Delete instances
aws ec2 terminate-instances --instance-ids $RECEIVER_ID $WEB_SERVER_ID

# Wait for termination
aws ec2 wait instance-terminated --instance-ids $RECEIVER_ID $WEB_SERVER_ID

# Delete ALB and target group
aws elbv2 delete-listener --listener-arn $LISTENER_ARN
aws elbv2 delete-target-group --target-group-arn $TARGET_GROUP_ARN
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN

# Delete certificate
aws acm delete-certificate --certificate-arn $CERT_ARN

# Delete DNS records (you'll need to modify the change batch to use "DELETE")
# Delete security groups, VPC, etc. (order matters due to dependencies)
```

---
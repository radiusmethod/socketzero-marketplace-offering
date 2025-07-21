#!/bin/bash

# SocketZero Terraform Validation Script
echo "🔍 SocketZero Terraform Validation"
echo "=================================="

# Check if terraform.tfvars exists
if [ ! -f terraform.tfvars ]; then
    echo "❌ terraform.tfvars not found"
    echo "   Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
else
    echo "✅ terraform.tfvars found"
fi

# Check Terraform version
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1 | cut -d' ' -f2 | cut -d'v' -f2)
    echo "✅ Terraform version: $TERRAFORM_VERSION"
else
    echo "❌ Terraform not found. Please install Terraform >= 1.0"
    exit 1
fi

# Check AWS CLI
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI found"
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        echo "✅ AWS credentials configured (Account: $ACCOUNT_ID)"
    else
        echo "❌ AWS credentials not configured"
        echo "   Please run 'aws configure' or set AWS credentials"
        exit 1
    fi
else
    echo "❌ AWS CLI not found. Please install AWS CLI"
    exit 1
fi

# Validate Terraform configuration
echo ""
echo "🔧 Validating Terraform configuration..."
if terraform fmt -check=true -diff=true . &> /dev/null; then
    echo "✅ Terraform formatting is correct"
else
    echo "⚠️  Terraform formatting could be improved"
    echo "   Run 'terraform fmt' to fix formatting"
fi

echo ""
echo "🎉 Validation complete!"
echo ""
echo "📋 Next steps:"
echo "1. Run: terraform init"
echo "2. Run: terraform plan"
echo "3. Run: terraform apply"
echo ""
echo "📚 For detailed instructions, see README.md" 
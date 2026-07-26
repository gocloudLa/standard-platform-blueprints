<!-- =============================================================================
This file is generated and maintained by GoCloud CLI
DO NOT EDIT MANUALLY - Changes will be overwritten on next generation
============================================================================= -->

# democorp.cloud Infrastructure Project

This repository contains the infrastructure configuration for **democorp.cloud** using Terraform.

## 📋 Project Overview

- **Client**: democorp.cloud
- **Company**: dmc
- **Region**: us-east-2
- **Terraform Version**: 1.0.0

## 🌍 Environments Configuration

| Environment | Region | Projects | Workloads | Terragrunt | Secrets |
|-------------|--------|----------|-----------|------------|----------|
| Lab VPC Net | `us-east-2` | - | - | ✅ | ❌ |
| Lab VPC Ac1 | `us-east-2` | - | - | ✅ | ❌ |
| Shared | `us-east-2` | - | - | ✅ | ❌ |


## 🚀 Quick Start

### 1. **Initial AWS SSO Configuration**

#### ⚡ Automatic Option (Recommended)
```bash
# Setup AWS SSO profiles
gocloud sso setup

# Login to all AWS profiles
gocloud sso login --all

# Verify SSO status
gocloud sso verify
```

#### 🔧 Manual Option
```bash
# 1. Generate AWS configuration
terragrunt init

# 2. Set environment variable
export AWS_CONFIG_FILE=$(pwd)/.aws/config

# 3. Login to all profiles
# The automatic script will detect and login to all available profiles
# Or manually for specific profiles:
AWS_CONFIG_FILE=$(pwd)/.aws/config aws sso login --profile <profile-name>
```

### 2. **Initialize the Entire Project**
```bash
# Initialize and update all modules
terragrunt init --all
```

### 3. **Verify Configuration**
```bash
# Verify everything is configured correctly
gocloud sso verify

# Plan all environments (just to verify)
terragrunt plan -concise --all
```

## 🏗️ Daily Work Commands

### **Global Commands**

```bash
# Initialize and update all modules
terragrunt init --all

# Plan all infrastructure
terragrunt plan -concise --all
```

### **Environment Commands**

#### **Example: Lab VPC Net Environment**

```bash
# Initialize
terragrunt init --all --queue-include-dir "*/lab_vpc_net" --queue-include-dir "*/*/lab_vpc_net"

# Plan
terragrunt plan -concise --all --queue-include-dir "*/lab_vpc_net" --queue-include-dir "*/*/lab_vpc_net"

# Apply
terragrunt apply --all --queue-include-dir "*/lab_vpc_net" --queue-include-dir "*/*/lab_vpc_net"
```

#### **Example: Lab VPC Ac1 Environment**

```bash
# Initialize
terragrunt init --all --queue-include-dir "*/lab_vpc_ac1" --queue-include-dir "*/*/lab_vpc_ac1"

# Plan
terragrunt plan -concise --all --queue-include-dir "*/lab_vpc_ac1" --queue-include-dir "*/*/lab_vpc_ac1"

# Apply
terragrunt apply --all --queue-include-dir "*/lab_vpc_ac1" --queue-include-dir "*/*/lab_vpc_ac1"
```

#### **Example: Shared Environment**

```bash
# Initialize
terragrunt init --all --queue-include-dir "*/shared" --queue-include-dir "*/*/shared"

# Plan
terragrunt plan -concise --all --queue-include-dir "*/shared" --queue-include-dir "*/*/shared"

# Apply
terragrunt apply --all --queue-include-dir "*/shared" --queue-include-dir "*/*/shared"
```

### **Specific Directory Commands**

You can also work with specific directories using `--working-dir`:

```bash
# Initialize a specific directory
terragrunt init --working-dir=./base/shared/

# Plan a specific directory
terragrunt plan --working-dir=./base/shared/

# Apply a specific directory
terragrunt apply --working-dir=./base/shared/
```



## 📝 Important Notes

- **Local Configuration**: The `.aws/config` file is generated automatically and doesn't pollute your global configuration
- **Credentials**: You only need to do `aws sso login` when credentials expire
- **Version Control**: Generated files are excluded from git
- **Parallelization**: Scripts execute operations in parallel for greater speed
- **Authentication Modes**: Supports both auto-generated SSO profiles and user-provided authentication via `TF_AWS_NO_PROFILE=true`

## 🆘 Troubleshooting

### **Error: "failed to get shared config profile"**
```bash
# Run the configuration script
gocloud sso setup
```

### **Expired Credentials**
```bash
# Check profile status
gocloud sso verify

# Re-login to specific profiles
AWS_CONFIG_FILE=$(pwd)/.aws/config aws sso login --profile <profile-name>
```

### **Custom Authentication**
```bash
# Force to not use auto-generated profiles and trust user-provided authentication
TF_AWS_NO_PROFILE=true terragrunt plan --all
```

### **Initialization Issues**
```bash
# Clean and reinitialize
terragrunt init -upgrade -reconfigure --all
```

---

## 🤝 Support

- **Email**: info@gocloud.la
- **Website**: [www.gocloud.la](https://www.gocloud.la)
- **AWS Partner**: Advanced Partner (Terraform, DevOps, GenAI)

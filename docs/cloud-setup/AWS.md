# AWS Setup Guide

**Complete AWS configuration for Backend-First IDP**

This guide walks you through setting up AWS for use with the Backend-First IDP platform.

**Time required**: 15-20 minutes
**Cost**: ~$100-300/month (Kubernetes cluster + managed infrastructure)

---

## Prerequisites

- AWS account with admin access
- AWS CLI installed and configured
- kubectl installed
- Basic understanding of AWS services (IAM, VPC, EC2)

---

## Step 1: Create IAM User for Crossplane

### 1.1: Create IAM Policy

The Crossplane AWS provider needs permissions to create infrastructure.

**Option A: Admin Access (for testing/dev)**:
```bash
# ⚠️ USE ONLY FOR TESTING - grants full AWS access
aws iam create-policy \
  --policy-name CrossplaneAdminPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }]
  }'
```

**Option B: Least Privilege (recommended for production)**:
```bash
# Create policy with minimal required permissions
aws iam create-policy \
  --policy-name CrossplanePolicy \
  --policy-document file://crossplane-policy.json

# crossplane-policy.json content:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RDSFullAccess",
      "Effect": "Allow",
      "Action": [
        "rds:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ElastiCacheFullAccess",
      "Effect": "Allow",
      "Action": [
        "elasticache:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3FullAccess",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2NetworkAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeSecurityGroups",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:CreateSubnetGroup",
        "ec2:DeleteSubnetGroup",
        "ec2:DescribeSubnets",
        "ec2:DescribeVpcs",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": [
        "iam:GetRole",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
```

### 1.2: Create IAM User

```bash
# Create user
aws iam create-user --user-name crossplane

# Attach policy (replace ACCOUNT_ID with your AWS account ID)
aws iam attach-user-policy \
  --user-name crossplane \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/CrossplanePolicy

# Create access keys
aws iam create-access-key --user-name crossplane
```

**Save the output**:
```json
{
  "AccessKey": {
    "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
    "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "Status": "Active",
    "CreateDate": "2026-01-15T12:00:00Z"
  }
}
```

**Store credentials securely**:
```bash
# Set environment variables for setup script
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

---

## Step 2: Provision Kubernetes Cluster

You need a Kubernetes cluster to run ArgoCD + Crossplane. Two options:

### Option A: Amazon EKS (Recommended for Production)

**Using eksctl**:
```bash
# Install eksctl (if not installed)
# macOS
brew install eksctl

# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create cluster (takes ~15 minutes)
eksctl create cluster \
  --name backend-first-idp \
  --region us-west-2 \
  --nodes 3 \
  --node-type t3.medium \
  --managed

# Verify cluster access
kubectl get nodes
# Expected: 3 nodes in Ready state
```

**Using AWS Console**:
1. Navigate to: https://console.aws.amazon.com/eks/
2. Click "Create cluster"
3. Settings:
   - **Name**: backend-first-idp
   - **Kubernetes version**: 1.28 or higher
   - **Networking**: Use default VPC
   - **Node group**: 3 nodes, t3.medium
4. Wait ~15 minutes for provisioning
5. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name backend-first-idp
   ```

**Cost**: ~$200-250/month
- EKS control plane: $72/month
- 3x t3.medium nodes: $100-150/month (on-demand)
- Data transfer: $10-30/month

### Option B: Local KIND (Testing Only)

**For testing without cloud costs**:
```bash
# Install KIND
brew install kind  # macOS
# or
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/

# Create local cluster
kind create cluster --name backend-first-idp

# Verify
kubectl cluster-info --context kind-backend-first-idp
```

**Note**: KIND doesn't create real AWS resources (uses mock providers for testing).

---

## Step 3: Configure Default VPC and Subnets

Crossplane needs VPC information for RDS, ElastiCache, etc.

### 3.1: Get VPC ID

```bash
# Get default VPC ID
export VPC_ID=$(aws ec2 describe-vpcs \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' \
  --output text)

echo "VPC ID: $VPC_ID"
# Output: vpc-0123456789abcdef
```

### 3.2: Get Subnet IDs

```bash
# Get all subnet IDs in default VPC
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone]' \
  --output table

# Example output:
# |  subnet-abc123  |  us-west-2a  |
# |  subnet-def456  |  us-west-2b  |
# |  subnet-ghi789  |  us-west-2c  |
```

**Save these for later** - you'll need them in Crossplane Compositions.

### 3.3: Create DB Subnet Group (Optional)

For better organization:
```bash
# Create subnet group for databases
aws rds create-db-subnet-group \
  --db-subnet-group-name backend-first-idp-db \
  --db-subnet-group-description "Subnet group for Backend-First IDP databases" \
  --subnet-ids subnet-abc123 subnet-def456 subnet-ghi789 \
  --tags Key=ManagedBy,Value=Crossplane
```

---

## Step 4: Test AWS Connectivity

Before proceeding, verify AWS credentials work:

```bash
# Test AWS API access
aws sts get-caller-identity

# Expected output:
{
  "UserId": "AIDAIOSFODNN7EXAMPLE",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/crossplane"
}

# Test basic EC2 access
aws ec2 describe-regions --output table

# Test RDS access
aws rds describe-db-instances --region us-west-2
```

**If errors occur**:
- Verify IAM policy is attached: `aws iam list-attached-user-policies --user-name crossplane`
- Check access key is active: `aws iam list-access-keys --user-name crossplane`
- Verify credentials: `aws configure list`

---

## Step 5: Run Setup Script

Now you're ready to install the platform:

```bash
# Clone repository (if not already done)
git clone https://github.com/[ORG]/backend-first-idp.git
cd backend-first-idp

# Export AWS credentials (from Step 1.2)
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# Run setup script
./scripts/setup.sh
```

**Follow the prompts**:
```
Which cloud provider would you like to configure?
  1) AWS
  2) GCP (Coming soon)
  3) Azure (Coming soon)
  4) Skip for now
Enter choice [1-4]: 1

ℹ Configuring AWS Provider...
✓ Created AWS credentials secret
✓ AWS provider configured successfully
```

---

## Step 6: Verify Installation

### 6.1: Check Provider Health

```bash
# Wait for provider to be ready (takes ~2 minutes)
kubectl get providers

# Expected output:
NAME          INSTALLED   HEALTHY   PACKAGE                          AGE
provider-aws  True        True      upbound/provider-aws:v0.48.0     2m
```

**If not healthy**:
```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws

# Common issues:
# - Credentials invalid: Re-check access keys
# - Network connectivity: Verify cluster has internet access
```

### 6.2: Check ProviderConfig

```bash
# Verify ProviderConfig exists
kubectl get providerconfigs

# Expected output:
NAME        AGE
default     2m
```

### 6.3: Test First Resource

Create a test RDS database:

```bash
# Apply test claim
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: test-aws-setup
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 20
    version: "15"
  writeConnectionSecretToRef:
    name: test-aws-connection
EOF

# Watch provisioning (takes ~5-10 minutes)
kubectl get postgresql test-aws-setup -n dev --watch

# Expected progression:
# NAME              SYNCED   READY   AGE
# test-aws-setup    False    False   10s
# test-aws-setup    True     False   90s
# test-aws-setup    True     True    5m
```

### 6.4: Verify in AWS Console

```bash
# Get RDS instance ID
kubectl get dbinstances.rds.aws.upbound.io -A

# Or check AWS Console:
# https://console.aws.amazon.com/rds/
```

**You should see**:
- RDS instance named similar to "test-aws-setup-xxxxx"
- Status: Available
- Engine: PostgreSQL 15

---

## Step 7: Production Hardening (Optional)

For production environments, apply these additional security measures:

### 7.1: Enable Secrets Encryption at Rest

```bash
# Configure etcd encryption
kubectl create secret generic encryption-config \
  -n kube-system \
  --from-file=encryption-config.yaml

# See: /security/encryption/README.md for full guide
```

### 7.2: Restrict Crossplane IAM Permissions

After testing, refine IAM policy to only necessary services:

```bash
# Example: If only using RDS and S3
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rds:*",
        "s3:*",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:DescribeSecurityGroups"
      ],
      "Resource": "*"
    }
  ]
}
```

### 7.3: Enable CloudTrail Logging

```bash
# Create CloudTrail for audit logging
aws cloudtrail create-trail \
  --name backend-first-idp-audit \
  --s3-bucket-name backend-first-idp-audit-logs

# Start logging
aws cloudtrail start-logging \
  --name backend-first-idp-audit
```

### 7.4: Set Up Cost Alerts

```bash
# Create billing alarm (via AWS Console)
# Navigate to: CloudWatch > Billing > Create alarm
# Set threshold: $500/month
# Notification: Email your team
```

---

## Step 8: Configure Multi-Region (Optional)

To provision resources in multiple AWS regions:

### 8.1: Create Region-Specific ProviderConfigs

```yaml
# us-west-2 (already default)
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: aws-us-west-2
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: credentials
  region: us-west-2

---
# us-east-1
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: aws-us-east-1
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: credentials
  region: us-east-1
```

### 8.2: Use Region-Specific Configs in Claims

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: db-east
  namespace: production
spec:
  parameters:
    size: large
    region: us-east-1  # Specify region
  providerConfigRef:
    name: aws-us-east-1
```

---

## Troubleshooting

### Issue: Provider not becoming healthy

**Symptom**: `kubectl get providers` shows "Unknown" or "Unhealthy"

**Solution**:
```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws

# Common issues:
# 1. Invalid credentials
aws sts get-caller-identity  # Test manually

# 2. Network connectivity
kubectl run test-net --image=curlimages/curl --rm -it -- curl https://aws.amazon.com

# 3. Provider installation failed
kubectl describe provider provider-aws
```

### Issue: RDS instance stuck in creating

**Symptom**: PostgreSQL claim never reaches READY state

**Debug**:
```bash
# Check managed resources
kubectl get managed -o wide

# Check specific RDS instance
kubectl describe dbinstances.rds.aws.upbound.io <instance-name>

# Look for errors in events:
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

**Common causes**:
- VPC/subnet configuration issues
- Security group problems
- IAM permissions missing

### Issue: Connection secret not created

**Symptom**: Secret missing after RDS is ready

**Solution**:
```bash
# Verify claim has writeConnectionSecretToRef
kubectl get postgresql <name> -n <namespace> -o yaml | grep -A 3 writeConnectionSecretToRef

# Check if secret exists but in different namespace
kubectl get secrets --all-namespaces | grep <name>

# Force reconcile
kubectl annotate postgresql <name> -n <namespace> crossplane.io/paused=false --overwrite
```

### Issue: AWS rate limiting

**Symptom**: "Rate exceeded" errors in logs

**Solution**:
```bash
# Reduce Crossplane poll interval
kubectl edit deployment crossplane -n crossplane-system

# Add environment variable:
env:
- name: POLL_INTERVAL
  value: "60s"  # Default is 1m, increase if needed
```

---

## Cost Optimization

### Estimated Monthly Costs

**Development environment**:
- EKS cluster (control plane): $72
- 3x t3.medium nodes: $100 (on-demand) or $40 (spot)
- 1x small RDS (db.t3.micro): $15
- 1x small ElastiCache (cache.t3.micro): $12
- S3 storage (100 GB): $2
- **Total**: ~$200/month

**Production environment**:
- EKS cluster: $72
- 3x t3.large nodes: $150 (on-demand)
- 2x large RDS (db.t3.large, HA): $280
- 2x medium ElastiCache (cache.t3.medium, HA): $120
- S3 storage (1 TB): $23
- **Total**: ~$645/month

### Cost Reduction Tips

**Use Spot Instances for dev**:
```bash
eksctl create nodegroup \
  --cluster backend-first-idp \
  --name spot-nodes \
  --node-type t3.medium \
  --nodes 3 \
  --spot
# Saves ~60% vs on-demand
```

**Auto-scale nodes**:
```bash
# Install cluster autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

**Delete unused resources**:
```bash
# Find orphaned resources
kubectl get managed | grep -v READY

# Clean up test resources
kubectl delete postgresql test-aws-setup -n dev
```

---

## Next Steps

1. ✅ AWS setup complete!
2. 📖 Try the [Quick Start Guide](/docs/quickstart.md) to provision your first database
3. 🎓 Complete the [Tutorial](/TUTORIAL.md) for hands-on labs
4. 🎬 Watch the [Demo](/docs/DEMO.md) to see full workflow

---

## Support

**Issues with AWS setup?**
- 💬 Slack: #backend-first-idp on [CNCF Slack](https://slack.cncf.io)
- 🐛 GitHub Issues: [Report bug](https://github.com/[ORG]/backend-first-idp/issues)
- 📧 Email: aws-help@backend-first-idp.io

**AWS-specific questions?**
- AWS Support: https://console.aws.amazon.com/support/
- Crossplane AWS Provider: https://marketplace.upbound.io/providers/upbound/provider-aws

---

**Last Updated**: 2026-01-15

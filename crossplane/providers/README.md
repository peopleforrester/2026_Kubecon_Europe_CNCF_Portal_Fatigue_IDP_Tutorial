# Crossplane Provider Configuration

This directory contains Crossplane provider configurations for AWS, GCP, and Azure using Upbound's granular provider family.

## Overview

### Why Upbound Providers?

- **Granular**: Install only the services you need (S3, RDS, etc.) instead of monolithic providers
- **Maintained**: Actively maintained by Upbound with regular updates
- **Performance**: Smaller packages mean faster installation and lower resource usage
- **Version Control**: Pin specific service versions independently

### Installed Providers

#### AWS Providers
- `provider-aws-s3` - S3 bucket management
- `provider-aws-rds` - RDS database provisioning
- `provider-aws-ec2` - VPC, security groups, networking
- `provider-aws-elasticache` - Redis/Memcached clusters

#### GCP Providers
- `provider-gcp-storage` - Cloud Storage buckets
- `provider-gcp-sql` - Cloud SQL databases
- `provider-gcp-compute` - VPC and networking
- `provider-gcp-redis` - Memorystore Redis

#### Azure Providers
- `provider-azure-storage` - Blob storage
- `provider-azure-sql` - Azure SQL Database
- `provider-azure-network` - VNet and NSG
- `provider-azure-cache` - Azure Cache for Redis

## Setup Instructions

### Prerequisites

- Kubernetes cluster with Crossplane installed
- Cloud provider account (AWS, GCP, or Azure)
- kubectl configured and connected
- Cloud CLI tools installed (optional but recommended)

### Step 1: Install Providers

```bash
# AWS providers
kubectl apply -f crossplane/providers/aws-provider.yaml

# GCP providers
kubectl apply -f crossplane/providers/gcp-provider.yaml

# Azure providers
kubectl apply -f crossplane/providers/azure-provider.yaml
```

### Step 2: Wait for Providers to be Ready

```bash
# Check provider status
kubectl get providers

# Wait for all providers to be HEALTHY and INSTALLED
watch kubectl get providers
```

Expected output:
```
NAME                        INSTALLED   HEALTHY   PACKAGE                                          AGE
provider-aws-s3            True        True      xpkg.upbound.io/upbound/provider-aws-s3:v2.5.1   1m
provider-aws-rds           True        True      xpkg.upbound.io/upbound/provider-aws-rds:v2.5.1  1m
...
```

### Step 3: Configure Credentials

Choose your cloud provider and follow the credential setup:

#### AWS Credentials

```bash
# Option 1: From AWS credentials file
kubectl create secret generic aws-credentials \
  -n crossplane-system \
  --from-file=credentials=~/.aws/credentials

# Option 2: From environment variables
kubectl create secret generic aws-credentials \
  -n crossplane-system \
  --from-literal=credentials="[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}"
```

See `aws-credentials-template.yaml` for detailed instructions.

#### GCP Credentials

```bash
# 1. Create service account
gcloud iam service-accounts create crossplane-provider

# 2. Grant permissions
PROJECT_ID=your-project-id
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:crossplane-provider@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/editor"

# 3. Create key
gcloud iam service-accounts keys create /tmp/gcp-creds.json \
  --iam-account=crossplane-provider@${PROJECT_ID}.iam.gserviceaccount.com

# 4. Create secret
kubectl create secret generic gcp-credentials \
  -n crossplane-system \
  --from-file=credentials=/tmp/gcp-creds.json

# 5. Update ProviderConfig with project ID
# Edit gcp-provider.yaml and replace YOUR_GCP_PROJECT_ID
```

See `gcp-credentials-template.yaml` for detailed instructions.

#### Azure Credentials

```bash
# 1. Create service principal
az ad sp create-for-rbac \
  --name crossplane-provider \
  --role Contributor \
  --scopes /subscriptions/YOUR_SUBSCRIPTION_ID \
  --sdk-auth > /tmp/azure-creds.json

# 2. Create secret
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-file=credentials=/tmp/azure-creds.json
```

See `azure-credentials-template.yaml` for detailed instructions.

### Step 4: Verify Configuration

```bash
# Check provider configs
kubectl get providerconfigs

# Check secrets
kubectl get secrets -n crossplane-system | grep credentials

# Test provider by creating a simple resource
# (See ../compositions/ for examples)
```

## Security Best Practices

### Credential Management

1. **Never commit credentials to Git**
   - `.gitignore` is configured to exclude credential files
   - Use `*-template.yaml` files as examples only

2. **Use cloud-native identity when possible**
   - AWS: IAM Roles for Service Accounts (IRSA)
   - GCP: Workload Identity
   - Azure: Managed Identity

3. **Rotate credentials regularly**
   - Set expiration on cloud provider keys
   - Automate rotation with external secrets operators

4. **Least privilege principle**
   - Grant only necessary permissions
   - Use resource-specific roles when available

### Secret Rotation

```bash
# Update AWS credentials
kubectl create secret generic aws-credentials \
  -n crossplane-system \
  --from-file=credentials=/path/to/new/creds \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart provider pods to pick up new credentials
kubectl rollout restart deployment \
  -n crossplane-system \
  -l pkg.crossplane.io/provider=aws
```

## Troubleshooting

### Providers Not Installing

```bash
# Check provider pod logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=aws-s3

# Check for image pull errors
kubectl describe provider provider-aws-s3
```

Common issues:
- Network connectivity to package registry
- Insufficient cluster resources
- Image pull rate limits

### Authentication Failures

```bash
# Verify secret exists and has correct key
kubectl get secret aws-credentials -n crossplane-system -o yaml

# Check provider logs for auth errors
kubectl logs -n crossplane-system deployment/provider-aws-s3
```

Common issues:
- Incorrect credential format
- Expired credentials
- Missing permissions in cloud provider IAM

### Provider Not Becoming Healthy

```bash
# Check provider configuration
kubectl describe providerconfig default

# Verify secret reference is correct
kubectl get providerconfig default -o yaml

# Check provider conditions
kubectl get provider provider-aws-s3 -o jsonpath='{.status.conditions}'
```

## Provider Versions

Current versions (as of April 2026):
- AWS Providers: v2.5.1
- GCP Providers: v2.5.1
- Azure Providers: v2.5.1

### Upgrading Providers

```bash
# Update provider version in YAML files
# Then apply:
kubectl apply -f crossplane/providers/aws-provider.yaml

# Monitor the upgrade
kubectl get providers -w
```

## Cost Considerations

Installing providers does not incur cloud costs. Costs occur when:
- Compositions create actual resources (RDS instances, S3 buckets, etc.)
- Resources are provisioned via Claims

See Phase 4 (Compositions) for cost estimation and budgeting.

## Next Steps

1. ✅ Providers installed and configured
2. 📋 Create Compositions (Phase 4)
3. 📋 Define Claims (Phase 5)
4. 📋 Provision infrastructure via GitOps

See `../compositions/` for Composition examples.

## Support

- **GitHub Issues**: [Report provider issues](../../issues)
- **Crossplane Slack**: [Join #upbound-providers](https://slack.crossplane.io)
- **Documentation**: [Upbound Provider Docs](https://marketplace.upbound.io)

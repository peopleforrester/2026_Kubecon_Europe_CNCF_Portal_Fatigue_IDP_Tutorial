# Development Environment

This directory contains Crossplane Claims for the development environment. Claims are GitOps-managed infrastructure requests that developers can easily understand and modify.

## What's Deployed

### PostgreSQL Database
- **File**: `postgresql-claim.yaml`
- **Size**: Small (db.t3.micro) - cost-optimized for dev
- **Storage**: 20 GB
- **Backups**: 1 day retention
- **High Availability**: Disabled (single AZ)
- **Cost**: ~$15/month

## How It Works

### 1. Developer Commits a Claim
```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: app-database
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 20
```

### 2. ArgoCD Detects the Change
- ArgoCD ApplicationSet monitors `environments/dev/`
- Automatically syncs new/changed claims to cluster

### 3. Crossplane Provisions Resources
- Reads the PostgreSQL claim
- Uses the matching Composition (xpostgresql.aws.platform.io)
- Creates actual AWS resources:
  - RDS PostgreSQL instance
  - DB subnet group
  - Security group with firewall rules
  - Automated backups

### 4. Connection Secret is Created
- Crossplane writes connection details to a Kubernetes Secret
- Secret name: `app-database-connection` (from `writeConnectionSecretToRef`)
- Contains: endpoint, port, username, password, database

### 5. Application Uses the Secret
```yaml
env:
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: app-database-connection
      key: endpoint
```

## Adding New Infrastructure

### Request a Redis Cache
```bash
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: Redis
metadata:
  name: app-cache
  namespace: dev
spec:
  parameters:
    size: small
    numNodes: 1
  writeConnectionSecretToRef:
    name: app-cache-connection
EOF
```

### Request an S3 Bucket
```bash
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: S3Bucket
metadata:
  name: app-storage
  namespace: dev
spec:
  parameters:
    versioning: true
    blockPublicAccess: true
  writeConnectionSecretToRef:
    name: app-storage-connection
EOF
```

## GitOps Workflow

### Option 1: Git Commit (Recommended)
```bash
# 1. Create claim file
cat > my-redis.yaml <<EOF
apiVersion: platform.io/v1alpha1
kind: Redis
...
EOF

# 2. Commit to Git
git add environments/dev/my-redis.yaml
git commit -m "Add Redis cache for dev"
git push

# 3. ArgoCD auto-syncs within seconds
# 4. Crossplane provisions the infrastructure
```

### Option 2: kubectl (Quick Testing)
```bash
kubectl apply -f environments/dev/postgresql-claim.yaml
```

## Viewing Resources

### Check Claim Status
```bash
# List all claims in dev
kubectl get postgresql,redis,s3bucket -n dev

# Detailed status
kubectl describe postgresql app-database -n dev
```

### Check Provisioned Resources
```bash
# View all Crossplane-managed resources
kubectl get managed

# Check specific RDS instance
kubectl get instance -n crossplane-system
```

### Access Connection Secrets
```bash
# View secret names
kubectl get secrets -n dev | grep connection

# Decode connection details
kubectl get secret app-database-connection -n dev -o yaml
```

## Troubleshooting

### Claim Stuck in Pending
```bash
# Check claim events
kubectl describe postgresql app-database -n dev

# Check Crossplane logs
kubectl logs -n crossplane-system deployment/crossplane

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=aws-rds
```

### Resources Not Provisioning
Common issues:
1. **Missing credentials**: Ensure AWS credentials secret exists
2. **Region issues**: Verify region is valid and you have access
3. **Quota limits**: Check AWS service quotas
4. **Network config**: Ensure VPC/subnets exist if specified

### Connection Secret Not Created
```bash
# Check if resource is ready
kubectl get postgresql app-database -n dev -o jsonpath='{.status.conditions}'

# Secret only created when resource is READY
# May take 5-10 minutes for RDS provisioning
```

## Environment Characteristics

### Development Environment
- **Purpose**: Feature development and testing
- **Cost Optimization**: Smallest instance sizes
- **Availability**: Single AZ (acceptable downtime)
- **Backups**: Minimal retention (1 day)
- **Security**: Private access only
- **Lifecycle**: Ephemeral - can be destroyed/recreated

### Promotion to Staging
When ready for staging:
1. Copy claim to `environments/staging/`
2. Update size to `medium`
3. Enable multi-AZ if needed
4. Increase backup retention
5. Commit and push

## Cost Estimation

Current dev infrastructure:
- PostgreSQL (small): ~$15/month
- **Total**: ~$15/month

Adding Redis cache (small): +$10/month
Adding S3 bucket: +$1/month (minimal usage)

## Next Steps

1. ✅ Claims applied via Git
2. ⏳ ArgoCD syncs automatically
3. ⏳ Crossplane provisions AWS resources
4. ⏳ Connection secrets created
5. ✅ Applications can connect

See [../staging/README.md](../staging/README.md) for staging environment details.

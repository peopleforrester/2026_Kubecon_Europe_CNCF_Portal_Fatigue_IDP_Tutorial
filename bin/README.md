# Platform CLI

> **Backend-First IDP Command Line Interface**
> Intuitive infrastructure provisioning with validation, cost estimation, and GitOps integration

## What This Solves

**Before CLI (Manual YAML):**
- 15 minutes of YAML writing (error-prone)
- No immediate validation
- Unknown costs until deployed
- Manual Git operations
- Complex connection secret management

**After CLI:**
- 10 seconds to provision
- Immediate validation
- Cost visibility upfront
- Auto-generated, best-practice YAML
- Guided workflows

## Installation

### Add to PATH

```bash
# From project root
export PATH="${PWD}/bin:${PATH}"

# Test installation
platform --version
```

### Make Permanent

```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export PATH="/path/to/backend-first-idp/bin:${PATH}"' >> ~/.bashrc
source ~/.bashrc
```

### Verify

```bash
platform --help
```

## Quick Start

### 1. Discovery - What Can I Provision?

```bash
# List all infrastructure types
platform list

# Get detailed info for PostgreSQL
platform list postgres

# See Redis options
platform list redis
```

**Output:**
```
Available Infrastructure Types:

postgres - PostgreSQL Database
  Description: Managed PostgreSQL database with automated backups
  Versions: 14.x, 15.x, 16.x
  Sizes: small, medium, large
  Features: Multi-AZ, automated backups, encryption, read replicas
  Example: platform create postgres my-db --size=small --env=dev
...
```

### 2. Cost Estimation - How Much Will This Cost?

```bash
# Estimate PostgreSQL costs
platform cost postgres --size=medium

# Compare all sizes
platform cost postgres --compare

# Estimate with Multi-AZ
platform cost postgres --size=large --multi-az

# Estimate Redis with HA
platform cost redis --size=medium --nodes=2
```

**Output:**
```
PostgreSQL Cost Estimate

Configuration:
  Instance:    db.t3.small
  Multi-AZ:    false
  Storage:     20 GB

Cost Breakdown:
  Instance:    $30/month
  Storage:     $0/month (first 20GB included)
  ────────────────────────────
  Total:       ~$30/month

Annual:      ~$360/year
```

### 3. Creation - Provision Infrastructure

```bash
# Create development database
platform create postgres my-db --size=small --env=dev

# Create staging Redis with HA
platform create redis my-cache \
  --size=medium \
  --nodes=2 \
  --auto-failover \
  --env=staging

# Create production S3 bucket
platform create s3bucket my-storage --env=production

# Dry run (preview only)
platform create postgres test-db --size=large --env=dev --dry-run
```

**Output:**
```
ℹ Validating claim...
✓ Name 'my-db' is valid
✓ Namespace 'dev' is valid

💰 Cost Estimate: ~$15/month (db.t3.micro)

ℹ Generating claim...

📄 Generated Claim:
────────────────────────────────────────
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-db
  namespace: dev
...
────────────────────────────────────────

Create this claim? [Y/n] y

✓ Created: environments/dev/my-db.yaml

Next steps:
  1. Review the claim: cat environments/dev/my-db.yaml
  2. Commit to git:
     git add environments/dev/my-db.yaml
     git commit -m 'feat: Add postgres my-db'
     git push
  3. Check status:
     platform status postgres my-db --env=dev

✓ Done! Infrastructure will be provisioned via GitOps
```

### 4. Status - Check Provisioning Progress

```bash
# Check status
platform status postgres my-db --env=dev

# Watch live updates
platform status postgres my-db --env=dev --watch

# Verbose output
platform status redis my-cache --env=staging --verbose
```

**Output:**
```
Status Check: PostgreSQL/my-db (dev)

✓ Status: Ready
✓ Synced: True

Conditions:
  Ready     True    Resource is ready
  Synced    True    Successfully reconciled

Connection Secret:
  ✓ Secret exists: my-db-connection

✓ Infrastructure is ready to use!
```

### 5. Connect - Get Connection Details

```bash
# Get connection details
platform connect postgres my-db --env=dev

# Show password
platform connect postgres my-db --env=dev --show-password

# Export as environment variables
platform connect postgres my-db --env=dev --format=env --export

# Get connection URL
platform connect postgres my-db --env=dev --format=url

# JSON format (for scripts)
platform connect redis my-cache --env=staging --format=json
```

**Output:**
```
PostgreSQL Connection Details

Connection:
  Host:        my-db.abc123.us-west-2.rds.amazonaws.com
  Port:        5432
  Database:    postgres
  Username:    postgres
  Password:    ********

Connection String:
  postgresql://postgres:********@my-db.abc123.us-west-2.rds.amazonaws.com:5432/postgres

Usage in Application:
  env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: my-db-connection
        key: endpoint
  ...
```

### 6. Validate - Check Before Deploying

```bash
# Validate a claim file
platform validate environments/dev/my-db.yaml

# Validate all claims in environment
platform validate environments/dev/*.yaml
```

**Output:**
```
Validating: environments/dev/my-db.yaml

✓ YAML syntax valid
✓ Metadata.name present
✓ Metadata.namespace present

Type-specific checks (PostgreSQL):
✓ Size valid: small
✓ Public access blocked (security)

✓ Validation PASSED
```

### 7. Promote - Move Between Environments

```bash
# Promote dev database to staging
platform promote postgres my-db --from=dev --to=staging

# Promote to production with custom size
platform promote postgres my-db \
  --from=staging \
  --to=production \
  --size=xlarge

# Dry run to preview changes
platform promote redis my-cache \
  --from=dev \
  --to=staging \
  --dry-run
```

**Output:**
```
Promotion Plan

Source:      dev/my-db (postgres)
Target:      staging/my-db (postgres)
Path:        dev → staging

Automatic Upgrades:
  • Size: small → medium
  • Multi-AZ: false
  • Backup Retention: 7 days

Proceed with promotion? [Y/n] y

✓ Created: environments/staging/my-db.yaml

Next steps:
  1. Review changes: git diff environments/staging/my-db.yaml
  2. Commit and push
  3. Monitor: platform status postgres my-db --env=staging

✓ Promotion complete!
```

### 8. Delete - Remove Infrastructure

```bash
# Delete with confirmation
platform delete postgres my-db --env=dev

# Delete without confirmation (be careful!)
platform delete redis my-cache --env=staging --force

# Delete claim but keep the resource
platform delete postgres my-db --env=dev --keep-data
```

## Commands Reference

### `platform list`

List available infrastructure types and their parameters.

```bash
platform list                 # List all types
platform list postgres        # PostgreSQL details
platform list redis           # Redis details
platform list s3bucket        # S3 Bucket details
```

### `platform cost`

Estimate monthly infrastructure costs.

```bash
platform cost postgres --size=medium
platform cost postgres --size=large --multi-az
platform cost postgres --compare        # Compare all sizes
platform cost redis --size=medium --nodes=2
platform cost s3bucket
```

### `platform create`

Create new infrastructure claims with validation and cost estimation.

```bash
# PostgreSQL
platform create postgres <name> --size=<size> --env=<env> [options]

Options:
  --version=VER       Engine version (default: 15.3)
  --storage=GB        Storage in GB (default: 20)
  --multi-az          Enable multi-AZ deployment
  --backup-days=N     Backup retention days (default: 7)

# Redis
platform create redis <name> --size=<size> --env=<env> [options]

Options:
  --version=VER       Engine version (default: 7.0)
  --nodes=N           Number of nodes (default: 1)
  --auto-failover     Enable automatic failover

# S3 Bucket
platform create s3bucket <name> --env=<env> [options]

Options:
  --versioning        Enable versioning (default: true)
  --lifecycle         Enable lifecycle policies
  --public            Allow public access (not recommended)

# Global Options
  --dry-run           Generate YAML without creating
  --auto-commit       Automatically commit to git
  --skip-cost         Skip cost estimation
```

### `platform status`

Check provisioning status of infrastructure resources.

```bash
platform status <type> <name> --env=<env> [options]

Options:
  --watch             Watch status updates (refresh every 5s)
  --json              Output in JSON format
  --verbose           Show detailed information
```

### `platform connect`

Get connection details for provisioned infrastructure.

```bash
platform connect <type> <name> --env=<env> [options]

Options:
  --format=FORMAT     Output format (env, json, yaml, url)
  --show-password     Display password (default: masked)
  --export            Export as environment variables
```

### `platform validate`

Validate infrastructure claim files before deployment.

```bash
platform validate <file>

Checks:
  ✓ YAML syntax
  ✓ Required fields
  ✓ Value constraints
  ✓ Security best practices
  ✓ Cost warnings
  ✓ Environment-specific rules
```

### `platform promote`

Promote infrastructure claims between environments with automatic upgrades.

```bash
platform promote <type> <name> --from=<env> --to=<env> [options]

Options:
  --size=SIZE         Override size for target environment
  --multi-az          Enable Multi-AZ (PostgreSQL production)
  --nodes=N           Override number of nodes (Redis)
  --dry-run           Show changes without creating files
  --auto-commit       Automatically commit promotion

Promotion Paths:
  dev → staging       Upgrade to medium size, add HA
  staging → production  Upgrade to large size, add Multi-AZ, increase backups
```

### `platform delete`

Delete infrastructure claims and optionally the provisioned resources.

```bash
platform delete <type> <name> --env=<env> [options]

Options:
  --force             Skip confirmation prompt
  --keep-data         Keep the cloud resource (delete claim only)
  --auto-commit       Automatically commit deletion

⚠️ WARNING: This will delete infrastructure and may cause data loss!
```

## Workflows

### Developer Workflow (Dev Environment)

```bash
# 1. Discover what's available
platform list

# 2. Estimate costs
platform cost postgres --size=small

# 3. Create infrastructure
platform create postgres my-app-db --size=small --env=dev

# 4. Check status
platform status postgres my-app-db --env=dev --watch

# 5. Get connection details
platform connect postgres my-app-db --env=dev --format=env

# 6. Use in application (copy env vars)
```

### Platform Team Workflow (Promotion)

```bash
# 1. Validate dev claims
platform validate environments/dev/*.yaml

# 2. Promote to staging (automatic upgrades)
platform promote postgres my-app-db --from=dev --to=staging

# 3. Test in staging
platform status postgres my-app-db --env=staging

# 4. Promote to production (with overrides)
platform promote postgres my-app-db \
  --from=staging \
  --to=production \
  --size=xlarge \
  --multi-az

# 5. Monitor production
platform status postgres my-app-db --env=production --verbose
```

### Cost Optimization Workflow

```bash
# 1. Compare costs
platform cost postgres --compare
platform cost redis --compare

# 2. Right-size for environment
platform create postgres dev-db --size=small --env=dev      # $15/mo
platform create postgres stage-db --size=medium --env=staging  # $30/mo
platform create postgres prod-db --size=large --multi-az --env=production  # $120/mo

# 3. Clean up unused resources
platform delete postgres old-db --env=dev --force
```

## Best Practices

### 1. Always Validate Before Committing

```bash
# Create with dry-run
platform create postgres my-db --size=small --env=dev --dry-run

# Validate the generated file
platform validate environments/dev/my-db.yaml

# Then commit
git add environments/dev/my-db.yaml
git commit -m 'feat: Add postgres database'
```

### 2. Use Cost Estimation

```bash
# Check cost before creating
platform cost postgres --size=large --multi-az

# Compare options
platform cost postgres --compare

# Choose appropriate size for environment
```

### 3. Promote with Automatic Upgrades

```bash
# Let the CLI handle environment-specific configurations
platform promote postgres my-db --from=dev --to=staging

# CLI automatically:
# • Upgrades size: small → medium
# • Adds HA where appropriate
# • Increases backup retention
```

### 4. Monitor Provisioning

```bash
# Watch status in real-time
platform status postgres my-db --env=dev --watch

# Check verbose details
platform status postgres my-db --env=dev --verbose
```

### 5. Secure Connection Management

```bash
# Never hardcode credentials
# Use connection secrets in deployments

# Get connection pattern
platform connect postgres my-db --env=dev

# Use in application:
env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: my-db-connection
        key: endpoint
```

## Troubleshooting

### CLI Command Not Found

```bash
# Check PATH
echo $PATH

# Add to PATH
export PATH="/path/to/backend-first-idp/bin:${PATH}"

# Make permanent in ~/.bashrc
echo 'export PATH="/path/to/backend-first-idp/bin:${PATH}"' >> ~/.bashrc
```

### Validation Errors

```bash
# Run validation
platform validate environments/dev/my-db.yaml

# Common errors:
# • Invalid size (use: small, medium, large)
# • Missing required fields (namespace, name)
# • Security violations (public access enabled)
```

### Status Shows "Unknown"

```bash
# Check if kubectl is configured
kubectl cluster-info

# Check if resource exists
kubectl get postgresql my-db -n dev

# Check ArgoCD sync
kubectl get applications -n argocd
```

### Connection Secret Not Found

```bash
# Wait for resource to be Ready
platform status postgres my-db --env=dev

# Secret only created when status=Ready
# Provisioning typically takes 5-10 minutes
```

## Integration Examples

### Export to Shell Script

```bash
# Generate and export env vars
platform connect postgres my-db --env=dev --format=env --export --show-password > db-env.sh

# Source in scripts
source db-env.sh
echo $DATABASE_URL
```

### CI/CD Integration

```yaml
# GitHub Actions
- name: Create staging database
  run: |
    platform create postgres staging-db \
      --size=medium \
      --env=staging \
      --auto-commit

- name: Wait for ready
  run: |
    platform status postgres staging-db --env=staging --watch
```

### Application Configuration

```bash
# Get JSON for config file
platform connect postgres my-db --env=dev --format=json > config/database.json

# Get YAML for Helm values
platform connect redis my-cache --env=dev --format=yaml > values/redis.yaml
```

## Advanced Usage

### Custom Provisioning

```bash
# PostgreSQL with custom settings
platform create postgres my-db \
  --size=large \
  --storage=100 \
  --multi-az \
  --backup-days=30 \
  --version=16.0 \
  --env=production

# Redis cluster
platform create redis my-cache \
  --size=large \
  --nodes=3 \
  --auto-failover \
  --snapshot-days=7 \
  --env=production
```

### Batch Operations

```bash
# Create multiple resources
for env in dev staging production; do
  platform create postgres app-db --size=small --env=$env --auto-commit
done

# Validate all claims
find environments -name "*.yaml" -exec platform validate {} \;
```

## What's Next

The CLI dramatically reduces friction, but we can go even further:

### Phase 7: Kyverno Policies
- Automatic security defaults injection
- Cost limit enforcement
- Compliance validation
- Coming next!

### Phase 8: Application CRD
- `Application` resource auto-provisions dependencies
- Auto-wires connection secrets
- One resource = full stack
- The ultimate abstraction!

## Architecture

```
┌─────────────────────────────────────────┐
│           Platform CLI                  │
│  (Developer-Friendly Interface)         │
├─────────────────────────────────────────┤
│ • Validation (pre-flight checks)        │
│ • Cost Estimation (AWS pricing)         │
│ • YAML Generation (best practices)      │
│ • Git Integration (commits)             │
└──────────────┬──────────────────────────┘
               │ Generates
               ▼
┌─────────────────────────────────────────┐
│      Infrastructure Claims (YAML)       │
│   environments/{dev,staging,prod}/      │
└──────────────┬──────────────────────────┘
               │ GitOps
               ▼
┌─────────────────────────────────────────┐
│            ArgoCD                       │
│   (Automatic Sync & Deployment)         │
└──────────────┬──────────────────────────┘
               │ Applies to Cluster
               ▼
┌─────────────────────────────────────────┐
│           Crossplane                    │
│  (Provisions Real Infrastructure)       │
└──────────────┬──────────────────────────┘
               │ Creates
               ▼
┌─────────────────────────────────────────┐
│      AWS/GCP/Azure Resources            │
│  (RDS, ElastiCache, S3, etc.)           │
└─────────────────────────────────────────┘
```

**Developer Experience:**
```
10 seconds → Validated claim → Cost estimate → Git commit → Infrastructure ready
```

## Contributing

Found a bug? Have a feature request?

```bash
# Report issues
# Suggest improvements
# Submit PRs

# The CLI is designed to be:
• Intuitive - Clear, helpful output
• Safe - Validation prevents mistakes
• Transparent - Shows what it's doing
• GitOps-native - Everything via Git
```

---

**Backend-First IDP CLI** - Making infrastructure provisioning as easy as running a command.

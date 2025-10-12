# Kyverno Policy Engine

> **Automatic Guardrails for Backend-First IDP**
> Security defaults, cost controls, and compliance enforcement without blocking developers

## What This Solves

**The Problem:**
- Developers forget security settings (public databases, no encryption)
- Cost overruns from oversized dev instances
- Inconsistent configurations across environments
- Manual policy enforcement doesn't scale

**The Solution:**
Kyverno automatically:
- ✅ Injects security defaults (encryption, private access, backups)
- ✅ Enforces cost limits (small instances in dev, medium in staging)
- ✅ Validates compliance (naming, labels, documentation)
- ✅ Prevents mistakes (no public access, no 0.0.0.0/0 CIDRs)

**Developer Experience:**
```yaml
# Developer writes (minimal):
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-db
  namespace: dev
spec:
  parameters:
    size: large  # ← Kyverno blocks this in dev!
```

**Kyverno auto-fixes to:**
```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-db
  namespace: dev
  labels:
    security.platform.io/encryption: "true"
    security.platform.io/private-access: "true"
    cost.platform.io/environment: "dev"
spec:
  parameters:
    size: small  # ← Enforced for dev
    encryptionAtRest: true  # ← Auto-injected
    encryptionInTransit: true  # ← Auto-injected
    networkConfig:
      publiclyAccessible: false  # ← Auto-injected
    backupRetentionDays: 7  # ← Auto-injected
```

## Installation

### Deploy Kyverno

```bash
# Install Kyverno v1.11.0
kubectl apply -k kyverno/install/

# Verify installation
kubectl get pods -n kyverno

# Expected output:
# NAME                       READY   STATUS    RESTARTS   AGE
# kyverno-xxx                1/1     Running   0          30s
```

### Deploy Policies

```bash
# Apply all policies
kubectl apply -f kyverno/policies/

# Verify policies
kubectl get clusterpolicy

# Expected output:
# NAME                                    BACKGROUND   VALIDATIONFAILUREACTION
# postgres-security-defaults              true         enforce
# redis-security-defaults                 true         enforce
# s3-security-defaults                    true         enforce
# infrastructure-cost-controls            false        enforce
# infrastructure-compliance-standards     false        enforce
```

## Policies Overview

### 1. Security Defaults

#### PostgreSQL Security (`postgres-security-defaults.yaml`)

**What it does:**
- ✅ Injects encryption (at-rest and in-transit) automatically
- ✅ Blocks public access (publiclyAccessible: false)
- ✅ Enforces backup retention (minimum 1 day)
- ✅ Validates allowed CIDRs (blocks 0.0.0.0/0)
- ✅ Adds security labels for tracking

**Example:**
```bash
# Developer creates this:
platform create postgres my-db --size=small --env=dev

# Kyverno automatically adds:
# - encryptionAtRest: true
# - encryptionInTransit: true
# - networkConfig.publiclyAccessible: false
# - backupRetentionDays: 7
# - Security labels
```

#### Redis Security (`redis-security-defaults.yaml`)

**What it does:**
- ✅ Enforces authentication (authTokenEnabled: true)
- ✅ Injects encryption (transit and at-rest)
- ✅ Ensures snapshot retention for durability
- ✅ Validates network access (blocks 0.0.0.0/0)
- ✅ Adds security labels

**Example:**
```bash
# Developer forgets authentication
# Kyverno auto-adds:
# - authTokenEnabled: true
# - transitEncryption: true
# - atRestEncryption: true
# - snapshotRetentionDays: 3
```

#### S3 Security (`s3-security-defaults.yaml`)

**What it does:**
- 🚨 **CRITICAL**: Forces blockPublicAccess: true (prevents #1 cloud vuln)
- ✅ Injects encryption (AES256 by default)
- ✅ Enables versioning for data protection
- ✅ Requires lifecycle policies in production
- ✅ Adds compliance labels

**Example:**
```yaml
# Developer tries to create public bucket:
apiVersion: platform.io/v1alpha1
kind: S3Bucket
spec:
  parameters:
    blockPublicAccess: false  # ← REJECTED by Kyverno!

# Error: "S3 buckets MUST block all public access. Public S3 buckets are a critical security risk."
```

### 2. Cost Controls (`cost-controls.yaml`)

**Environment-Specific Limits:**

| Environment | PostgreSQL Size | Redis Size | Multi-AZ | Nodes |
|-------------|-----------------|------------|----------|-------|
| **Dev** | `small` only (~$15/mo) | `small` only (~$10/mo) | ❌ Not allowed | 1 only |
| **Staging** | `small` or `medium` (~$15-30/mo) | `small` or `medium` (~$10-25/mo) | ⚠️ Optional | ≤3 |
| **Production** | Any size (with labels) | Any size (with labels) | ✅ Recommended | Any |

**What it does:**
- ✅ Blocks oversized instances in dev (cost optimization)
- ✅ Limits staging to small/medium sizes
- ✅ Requires cost-center and owner labels in production
- ✅ Injects cost tracking labels automatically
- ✅ Enforces storage limits (dev: max 100GB)

**Examples:**
```bash
# ❌ Rejected in dev:
platform create postgres my-db --size=large --env=dev
# Error: "Dev PostgreSQL databases must use 'small' size for cost optimization"

# ❌ Rejected in dev:
platform create redis my-cache --nodes=3 --env=dev
# Error: "Dev Redis caches limited to 1 node for cost optimization"

# ✅ Accepted in staging:
platform create postgres my-db --size=medium --env=staging

# ✅ Accepted in production (with labels):
platform create postgres my-db --size=xlarge --env=production
# (requires cost-center and owner labels)
```

### 3. Compliance Standards (`compliance-standards.yaml`)

**What it does:**
- ✅ Validates naming conventions (RFC 1123: lowercase, alphanumeric, hyphens)
- ✅ Requires standard labels (app, environment)
- ✅ Enforces production documentation (owner, description)
- ✅ Validates environment label matches namespace
- ✅ Injects platform tracking labels and timestamps
- ✅ Adds HA labels based on configuration

**Naming Rules:**
```bash
# ✅ Valid names:
my-database
api-cache-01
user-storage

# ❌ Invalid names:
MyDatabase          # No uppercase
api_cache           # No underscores
-cache              # Can't start with hyphen
db-                 # Can't end with hyphen
```

**Required Labels:**
```yaml
metadata:
  labels:
    app: my-app              # Required: application name
    environment: dev         # Required: must match namespace
    owner: team@company.com  # Required in production
```

**Required Annotations (Production):**
```yaml
metadata:
  annotations:
    description: "Primary API database for user service"  # Required in production
```

## How Policies Work

### Mutation (Auto-Inject)

Kyverno automatically adds missing security settings:

```yaml
# What you write:
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: api-db
  namespace: dev
spec:
  parameters:
    size: small

# What gets created (Kyverno mutations):
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: api-db
  namespace: dev
  labels:
    security.platform.io/encryption: "true"
    security.platform.io/private-access: "true"
    security.platform.io/backups: "enabled"
    cost.platform.io/environment: "dev"
    platform.io/managed: "true"
  annotations:
    platform.io/created-at: "2024-01-15T10:30:00Z"
spec:
  parameters:
    size: small
    encryptionAtRest: true            # ← Auto-added
    encryptionInTransit: true         # ← Auto-added
    backupRetentionDays: 7            # ← Auto-added
    networkConfig:
      publiclyAccessible: false       # ← Auto-added
```

### Validation (Block Bad Configs)

Kyverno prevents dangerous configurations:

```yaml
# ❌ This will be REJECTED:
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
spec:
  parameters:
    networkConfig:
      publiclyAccessible: true  # ← BLOCKED!
      allowedCIDRs:
        - "0.0.0.0/0"           # ← BLOCKED!

# Error: "PostgreSQL databases must NOT be publicly accessible (security violation)"
```

### Environment-Specific Rules

Kyverno applies different rules per environment:

```yaml
# Dev environment:
- Size limited to 'small'
- No Multi-AZ allowed
- Storage max 100GB
- Labels: app, environment (required)

# Staging environment:
- Size limited to 'small' or 'medium'
- Multi-AZ optional
- Labels: app, environment (required)

# Production environment:
- Any size allowed
- Multi-AZ recommended
- Labels: app, environment, owner, cost-center (required)
- Description annotation (required)
```

## Testing Policies

### Test Security Injection

```bash
# Create minimal claim
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: test-db
  namespace: dev
  labels:
    app: test
    environment: dev
spec:
  parameters:
    size: small
  writeConnectionSecretToRef:
    name: test-db-connection
EOF

# Check mutations
kubectl get postgresql test-db -n dev -o yaml

# Should see auto-injected:
# - encryptionAtRest: true
# - encryptionInTransit: true
# - networkConfig.publiclyAccessible: false
# - Security labels
```

### Test Cost Controls

```bash
# Try to create large instance in dev (should fail)
platform create postgres oversized-db --size=large --env=dev

# Expected error:
# Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
#
# policy postgres-dev-size-limit/postgres-dev-size-limit failed:
# Dev PostgreSQL databases must use 'small' size for cost optimization (~$15/month).
# Use staging for larger instances.
```

### Test Public Access Block

```bash
# Try to create public S3 bucket (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: S3Bucket
metadata:
  name: public-bucket
  namespace: dev
  labels:
    app: test
    environment: dev
spec:
  parameters:
    blockPublicAccess: false  # ← Will be REJECTED
EOF

# Expected error:
# S3 buckets MUST block all public access (blockPublicAccess: true).
# Public S3 buckets are a critical security risk.
```

### Test Compliance Standards

```bash
# Try invalid naming (should fail)
platform create postgres MyDatabase --env=dev

# Expected error:
# Resource names must be lowercase alphanumeric with hyphens only (RFC 1123)

# Try production without owner (should fail)
platform create postgres prod-db --size=large --env=production

# Expected error:
# Production infrastructure must have 'owner' label (email or team identifier)
```

## Policy Reports

### View Policy Violations

```bash
# List policy reports
kubectl get policyreport -A

# View detailed report
kubectl describe policyreport polr-ns-dev -n dev

# Check cluster-wide reports
kubectl get clusterpolicyreport

# View specific policy report
kubectl describe clusterpolicyreport cpol-postgres-security-defaults
```

### Monitor Policy Decisions

```bash
# Watch policy events
kubectl get events -n dev --watch | grep kyverno

# View admission webhook decisions
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno

# Check policy metrics (if enabled)
kubectl port-forward -n kyverno svc/kyverno-svc-metrics 8000:8000
curl http://localhost:8000/metrics | grep kyverno
```

## Troubleshooting

### Policy Not Applied

```bash
# Check if policy exists
kubectl get clusterpolicy postgres-security-defaults

# Check policy status
kubectl describe clusterpolicy postgres-security-defaults

# Look for errors in Kyverno logs
kubectl logs -n kyverno -l app.kubernetes.io/name=kyverno --tail=50

# Verify webhook is running
kubectl get validatingwebhookconfigurations | grep kyverno
kubectl get mutatingwebhookconfigurations | grep kyverno
```

### Mutation Not Working

```bash
# Check if background scanning is enabled
kubectl get configmap kyverno -n kyverno -o yaml | grep background

# Trigger policy re-evaluation
kubectl annotate postgresql test-db -n dev policy.kyverno.io/trigger=true

# Check policy rule matches
kubectl describe clusterpolicy postgres-security-defaults | grep -A 10 "match:"
```

### Policy Conflicts

```bash
# Multiple policies might conflict - check order
kubectl get clusterpolicy -o custom-columns=NAME:.metadata.name,BACKGROUND:.spec.background,ACTION:.spec.validationFailureAction

# View admission sequence
kubectl get events --sort-by='.lastTimestamp' | grep admission
```

## Best Practices

### 1. Test Policies in Non-Prod First

```bash
# Apply to dev/staging first
kubectl apply -f kyverno/policies/postgres-security-defaults.yaml

# Set to audit mode initially
kubectl patch clusterpolicy postgres-security-defaults --type=merge -p '{"spec":{"validationFailureAction":"audit"}}'

# Review reports
kubectl get policyreport -A

# Switch to enforce when ready
kubectl patch clusterpolicy postgres-security-defaults --type=merge -p '{"spec":{"validationFailureAction":"enforce"}}'
```

### 2. Use Audit Mode for New Policies

```yaml
spec:
  validationFailureAction: audit  # Start with audit
  # Switch to enforce after validation
```

### 3. Document Exemptions

```yaml
# Exempt specific resources when needed
metadata:
  annotations:
    policies.kyverno.io/exclude: "postgres-dev-size-limit"
    justification: "Special case: load testing requires large instance"
```

### 4. Monitor Policy Impact

```bash
# Track denials
kubectl get policyreport -A -o json | jq '.items[].results[] | select(.result=="fail")'

# Track mutations
kubectl get events -A | grep mutated

# Cost savings from policies
kubectl get postgresql -A -o custom-columns=NAME:.metadata.name,SIZE:.spec.parameters.size,ENV:.metadata.namespace
```

## Integration with CLI

The Platform CLI works seamlessly with Kyverno:

```bash
# CLI generates claim
platform create postgres my-db --size=small --env=dev

# Kyverno validates and mutates
# ✓ Size is valid for dev environment
# ✓ Auto-injected security defaults
# ✓ Added tracking labels

# Result: Secure, compliant, cost-optimized infrastructure
```

## Architecture

```
┌─────────────────────────────────────┐
│        Platform CLI                 │
│   (Generates Claims)                │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│        Git Repository               │
│   (GitOps Source of Truth)          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│          ArgoCD                     │
│   (Applies to Cluster)              │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    Kyverno Admission Webhooks       │
│  ┌───────────────────────────────┐  │
│  │ 1. Validate (block bad config)│  │
│  │ 2. Mutate (inject defaults)   │  │
│  │ 3. Generate (create resources)│  │
│  └───────────────────────────────┘  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│        Crossplane Claims            │
│   (Secure, Compliant, Optimized)    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│    Cloud Infrastructure             │
│   (AWS/GCP/Azure Resources)         │
└─────────────────────────────────────┘
```

## What's Next: Phase 8

With CLI (Phase 6) and Kyverno (Phase 7) in place, we have:
- ✅ Intuitive developer experience
- ✅ Automatic security guardrails
- ✅ Cost controls
- ✅ Compliance enforcement

**Phase 8: Application CRD** takes it further:
- One `Application` resource provisions entire stack
- Auto-wires infrastructure to deployments
- Lifecycle management (delete app = delete infrastructure)
- The ultimate abstraction!

---

**Kyverno Policies** - Security and compliance on autopilot, without blocking developers.

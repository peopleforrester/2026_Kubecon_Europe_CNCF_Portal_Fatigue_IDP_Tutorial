# GCP Setup Guide

**Complete Google Cloud Platform configuration for Backend-First IDP**

This guide walks you through setting up GCP for use with the Backend-First IDP platform.

**Status**: 🔄 In Development (Q2 2026)
**Time required**: 15-20 minutes
**Cost**: ~$100-250/month (GKE cluster + managed infrastructure)

---

## Prerequisites

- Google Cloud account with admin access
- gcloud CLI installed and configured
- kubectl installed
- Basic understanding of GCP services (IAM, VPC, GCE)

---

## Step 1: Create Service Account for Crossplane

### 1.1: Set Up GCP Project

```bash
# Set your project ID
export PROJECT_ID="backend-first-idp"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# Set project
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  storage-api.googleapis.com \
  iam.googleapis.com
```

### 1.2: Create Service Account

```bash
# Create service account
gcloud iam service-accounts create crossplane \
  --display-name "Crossplane Infrastructure Provisioning" \
  --description "Service account for Crossplane to manage GCP resources"

# Get service account email
export SA_EMAIL="crossplane@${PROJECT_ID}.iam.gserviceaccount.com"
```

### 1.3: Grant Permissions

**Option A: Admin Access (for testing/dev)**:
```bash
# ⚠️ USE ONLY FOR TESTING - grants broad permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/editor"
```

**Option B: Least Privilege (recommended for production)**:
```bash
# Grant specific roles
for role in \
  roles/cloudsql.admin \
  roles/redis.admin \
  roles/storage.admin \
  roles/compute.networkAdmin \
  roles/iam.serviceAccountUser
do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role"
done
```

### 1.4: Create Service Account Key

```bash
# Create and download key
gcloud iam service-accounts keys create crossplane-key.json \
  --iam-account=$SA_EMAIL

# Verify key was created
ls -l crossplane-key.json
# Output: -rw------- 1 user user 2345 Jan 15 12:00 crossplane-key.json

# IMPORTANT: Keep this file secure!
chmod 600 crossplane-key.json
```

**Store key for setup**:
```bash
# Set environment variable for setup script
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/crossplane-key.json"
```

---

## Step 2: Provision GKE Cluster

You need a Kubernetes cluster to run ArgoCD + Crossplane. Two options:

### Option A: Google Kubernetes Engine (Recommended)

**Using gcloud**:
```bash
# Create GKE cluster (takes ~5-7 minutes)
gcloud container clusters create backend-first-idp \
  --region us-central1 \
  --num-nodes 1 \
  --node-locations us-central1-a,us-central1-b,us-central1-c \
  --machine-type e2-standard-2 \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 5 \
  --enable-autorepair \
  --enable-autoupgrade \
  --release-channel stable

# Get credentials
gcloud container clusters get-credentials backend-first-idp --region us-central1

# Verify cluster access
kubectl get nodes
# Expected: 3 nodes in Ready state
```

**Using GCP Console**:
1. Navigate to: https://console.cloud.google.com/kubernetes/
2. Click "Create cluster"
3. Settings:
   - **Name**: backend-first-idp
   - **Location**: Regional (us-central1)
   - **Kubernetes version**: Latest stable
   - **Node pool**: 3 nodes, e2-standard-2
   - **Autoscaling**: Enabled (1-5 nodes)
4. Wait ~5-7 minutes for provisioning
5. Click "Connect" and run the command shown

**Cost**: ~$150-200/month
- GKE control plane: Free (GKE Autopilot) or $72/month (Standard)
- 3x e2-standard-2 nodes: $100-130/month (preemptible: ~$30/month)
- Network egress: $10-20/month

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

**Note**: KIND doesn't create real GCP resources (uses mock providers for testing).

---

## Step 3: Configure VPC and Network

### 3.1: Get VPC Information

```bash
# Get default VPC
export VPC_NAME=$(gcloud compute networks list --filter="name:default" --format="value(name)")

echo "VPC Name: $VPC_NAME"
# Output: default

# Get VPC self-link
gcloud compute networks describe $VPC_NAME --format="value(selfLink)"
# Output: https://www.googleapis.com/compute/v1/projects/PROJECT_ID/global/networks/default
```

### 3.2: Create Subnet for Databases (Optional)

```bash
# Create dedicated subnet for Cloud SQL
gcloud compute networks subnets create database-subnet \
  --network=default \
  --region=us-central1 \
  --range=10.128.0.0/20 \
  --enable-private-ip-google-access

# List subnets
gcloud compute networks subnets list --filter="network:default"
```

---

## Step 4: Test GCP Connectivity

Before proceeding, verify GCP credentials work:

```bash
# Test authentication
gcloud auth list

# Expected output:
                 Credentialed Accounts
ACTIVE  ACCOUNT
*       you@example.com

# Test project access
gcloud projects describe $PROJECT_ID

# Test Cloud SQL API
gcloud sql instances list

# Test Compute API
gcloud compute regions list
```

**If errors occur**:
- Verify service account permissions: `gcloud projects get-iam-policy $PROJECT_ID | grep crossplane`
- Check APIs are enabled: `gcloud services list --enabled`
- Verify credentials: `gcloud auth application-default print-access-token`

---

## Step 5: Install Crossplane GCP Provider

**Note**: Backend-First IDP setup script will handle this automatically in Q2 2026.

**Manual installation (preview)**:
```bash
# Install Crossplane GCP provider
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp
spec:
  package: upbound/provider-gcp:v0.38.0
EOF

# Wait for provider to be ready
kubectl wait --for=condition=Healthy provider/provider-gcp --timeout=300s

# Create secret from service account key
kubectl create secret generic gcp-credentials \
  -n crossplane-system \
  --from-file=credentials=crossplane-key.json

# Create ProviderConfig
cat <<EOF | kubectl apply -f -
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  projectID: $PROJECT_ID
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-credentials
      key: credentials
EOF
```

---

## Step 6: Verify Installation

### 6.1: Check Provider Health

```bash
# Wait for provider to be ready (takes ~2 minutes)
kubectl get providers

# Expected output:
NAME           INSTALLED   HEALTHY   PACKAGE                          AGE
provider-gcp   True        True      upbound/provider-gcp:v0.38.0     2m
```

**If not healthy**:
```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-gcp

# Common issues:
# - Credentials invalid: Re-check service account key
# - APIs not enabled: Run `gcloud services enable ...`
```

### 6.2: Test First Resource

Create a test Cloud SQL database:

```bash
# Apply test claim
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: test-gcp-setup
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 10
    version: "15"
  writeConnectionSecretToRef:
    name: test-gcp-connection
EOF

# Watch provisioning (takes ~5-10 minutes)
kubectl get postgresql test-gcp-setup -n dev --watch

# Expected progression:
# NAME              SYNCED   READY   AGE
# test-gcp-setup    False    False   10s
# test-gcp-setup    True     False   90s
# test-gcp-setup    True     True    7m
```

### 6.3: Verify in GCP Console

```bash
# List Cloud SQL instances via CLI
gcloud sql instances list

# Or check GCP Console:
# https://console.cloud.google.com/sql/instances
```

**You should see**:
- Cloud SQL instance named similar to "test-gcp-setup-xxxxx"
- Status: Runnable
- Database version: PostgreSQL 15

---

## Step 7: Production Hardening (Optional)

### 7.1: Enable Cloud KMS for Secrets

```bash
# Create KMS keyring
gcloud kms keyrings create crossplane-secrets \
  --location us-central1

# Create encryption key
gcloud kms keys create kubernetes-secrets \
  --location us-central1 \
  --keyring crossplane-secrets \
  --purpose encryption

# Configure GKE to use KMS
gcloud container clusters update backend-first-idp \
  --region us-central1 \
  --database-encryption-key projects/$PROJECT_ID/locations/us-central1/keyRings/crossplane-secrets/cryptoKeys/kubernetes-secrets
```

### 7.2: Enable Cloud Audit Logs

```bash
# Enable audit logs for all services
gcloud logging sinks create backend-first-idp-audit \
  storage.googleapis.com/backend-first-idp-audit-logs \
  --log-filter='protoPayload.serviceName="sqladmin.googleapis.com" OR protoPayload.serviceName="redis.googleapis.com"'
```

### 7.3: Set Up Budget Alerts

```bash
# Create budget alert (requires billing API)
gcloud billing budgets create \
  --billing-account=$BILLING_ACCOUNT_ID \
  --display-name="Backend-First IDP Budget" \
  --budget-amount=500 \
  --threshold-rule=percent=50 \
  --threshold-rule=percent=90
```

---

## Step 8: Multi-Region Setup (Optional)

To provision resources in multiple GCP regions:

### 8.1: Create Region-Specific ProviderConfigs

```yaml
# us-central1 (already default)
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: gcp-us-central1
spec:
  projectID: backend-first-idp
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-credentials
      key: credentials

---
# europe-west1
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: gcp-europe-west1
spec:
  projectID: backend-first-idp
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-credentials
      key: credentials
```

### 8.2: Use Region-Specific Configs

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: db-europe
  namespace: production
spec:
  parameters:
    size: large
    region: europe-west1  # Specify region
  providerConfigRef:
    name: gcp-europe-west1
```

---

## Troubleshooting

### Issue: Provider not becoming healthy

**Symptom**: `kubectl get providers` shows "Unknown" or "Unhealthy"

**Solution**:
```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-gcp

# Common issues:
# 1. Service account key invalid
gcloud iam service-accounts keys list --iam-account=$SA_EMAIL

# 2. APIs not enabled
gcloud services enable sqladmin.googleapis.com redis.googleapis.com

# 3. Provider installation failed
kubectl describe provider provider-gcp
```

### Issue: Cloud SQL instance stuck in creating

**Symptom**: PostgreSQL claim never reaches READY state

**Debug**:
```bash
# Check managed resources
kubectl get managed -o wide

# Check specific Cloud SQL instance
kubectl describe databaseinstances.sql.gcp.upbound.io <instance-name>

# Check GCP Operations logs
gcloud logging read "resource.type=cloudsql_database" --limit 50
```

### Issue: Permission denied errors

**Symptom**: "Permission denied" in provider logs

**Solution**:
```bash
# Check service account roles
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:$SA_EMAIL"

# Add missing role (example: Cloud SQL Admin)
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/cloudsql.admin"
```

---

## Cost Optimization

### Estimated Monthly Costs

**Development environment**:
- GKE cluster (Autopilot): $0 (pay per pod)
- 3x e2-standard-2 nodes (Standard): $130 (preemptible: $30)
- Cloud SQL (db-f1-micro): $8
- Memorystore Redis (M1): $30
- Cloud Storage (100 GB): $2
- **Total**: ~$170/month (Standard) or $70/month (preemptible)

**Production environment**:
- GKE cluster: $72 (Standard)
- 3x e2-standard-4 nodes: $250
- Cloud SQL HA (db-n1-standard-2): $180
- Memorystore Redis HA (M2): $100
- Cloud Storage (1 TB): $20
- **Total**: ~$622/month

### Cost Reduction Tips

**Use Preemptible VMs**:
```bash
gcloud container node-pools create preemptible-pool \
  --cluster backend-first-idp \
  --region us-central1 \
  --machine-type e2-standard-2 \
  --num-nodes 3 \
  --preemptible
# Saves ~70% vs standard VMs
```

**Use GKE Autopilot**:
```bash
# Create Autopilot cluster (pay-per-pod pricing)
gcloud container clusters create-auto backend-first-idp-auto \
  --region us-central1
# No node management, pay only for running pods
```

**Schedule non-production resources**:
```yaml
# Stop dev databases at night (via CronJob)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: stop-dev-dbs
spec:
  schedule: "0 18 * * 1-5"  # 6 PM weekdays
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: stop-dbs
            image: google/cloud-sdk
            command:
            - gcloud
            - sql
            - instances
            - patch
            - <instance-name>
            - --activation-policy=NEVER
```

---

## GCP-Specific Features

### Private IP for Cloud SQL

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: private-db
spec:
  parameters:
    size: small
    networkConfig:
      privateIP: true  # No public IP
      authorizedNetworks: []
```

### Custom Machine Types

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: custom-db
spec:
  parameters:
    machineType: db-custom-2-7680  # 2 vCPU, 7.5 GB RAM
```

### Cloud SQL Proxy for Local Development

```bash
# Download Cloud SQL Proxy
curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
chmod +x cloud_sql_proxy

# Connect to database
./cloud_sql_proxy -instances=PROJECT_ID:us-central1:INSTANCE_NAME=tcp:5432
```

---

## Next Steps

1. ✅ GCP setup complete!
2. 📖 Try the [Quick Start Guide](/docs/quickstart.md)
3. 🎓 Complete the [Tutorial](/TUTORIAL.md)
4. 🎬 Watch the [Demo](/docs/DEMO.md)

---

## Support

**Issues with GCP setup?**
- 💬 Slack: #backend-first-idp on [CNCF Slack](https://slack.cncf.io)
- 🐛 GitHub Issues: [Report bug](https://github.com/[ORG]/backend-first-idp/issues)
- 📧 Email: gcp-help@backend-first-idp.io

**GCP-specific questions?**
- GCP Support: https://console.cloud.google.com/support/
- Crossplane GCP Provider: https://marketplace.upbound.io/providers/upbound/provider-gcp

---

**Last Updated**: 2026-01-15 | **Status**: Preview (Q2 2026 release)

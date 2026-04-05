# Azure Setup Guide

**Complete Microsoft Azure configuration for Backend-First IDP**

This guide walks you through setting up Azure for use with the Backend-First IDP platform.

**Status**: 🔄 In Development (Q2 2026)
**Time required**: 15-20 minutes
**Cost**: ~$150-300/month (AKS cluster + managed infrastructure)

---

## Prerequisites

- Azure account with admin access
- Azure CLI (az) installed and configured
- kubectl installed
- Basic understanding of Azure services (IAM, VNet, VMs)

---

## Step 1: Create Service Principal for Crossplane

### 1.1: Login to Azure

```bash
# Login to Azure
az login

# Set subscription (if you have multiple)
az account list --output table
az account set --subscription "Your Subscription Name"

# Verify current subscription
az account show
```

### 1.2: Create Service Principal

```bash
# Create service principal with Contributor role
az ad sp create-for-rbac \
  --name crossplane-sp \
  --role Contributor \
  --scopes /subscriptions/$(az account show --query id -o tsv)

# Save the output (you'll need these values):
{
  "appId": "12345678-1234-1234-1234-123456789012",
  "displayName": "crossplane-sp",
  "password": "abc123xyz789~_-.EXAMPLE",
  "tenant": "87654321-4321-4321-4321-210987654321"
}
```

**Store credentials securely**:
```bash
# Set environment variables
export AZURE_CLIENT_ID="12345678-1234-1234-1234-123456789012"
export AZURE_CLIENT_SECRET="abc123xyz789~_-.EXAMPLE"
export AZURE_TENANT_ID="87654321-4321-4321-4321-210987654321"
export AZURE_SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
```

### 1.3: Grant Additional Permissions (if needed)

**Option A: Admin Access (for testing/dev)**:
```bash
# Service principal already has Contributor role (sufficient for testing)
```

**Option B: Custom Role (recommended for production)**:
```bash
# Create custom role with minimal permissions
cat > crossplane-role.json <<EOF
{
  "Name": "Crossplane Infrastructure Manager",
  "Description": "Custom role for Crossplane to manage Azure resources",
  "Actions": [
    "Microsoft.Sql/servers/*",
    "Microsoft.DBforPostgreSQL/servers/*",
    "Microsoft.Cache/redis/*",
    "Microsoft.Storage/storageAccounts/*",
    "Microsoft.Network/virtualNetworks/*",
    "Microsoft.Network/networkSecurityGroups/*",
    "Microsoft.Resources/deployments/*"
  ],
  "NotActions": [],
  "AssignableScopes": [
    "/subscriptions/$(az account show --query id -o tsv)"
  ]
}
EOF

# Create custom role
az role definition create --role-definition crossplane-role.json

# Assign custom role to service principal
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Crossplane Infrastructure Manager" \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID
```

---

## Step 2: Provision AKS Cluster

You need a Kubernetes cluster to run ArgoCD + Crossplane. Two options:

### Option A: Azure Kubernetes Service (Recommended)

**Using Azure CLI**:
```bash
# Create resource group
az group create \
  --name backend-first-idp-rg \
  --location eastus

# Create AKS cluster (takes ~5-7 minutes)
az aks create \
  --resource-group backend-first-idp-rg \
  --name backend-first-idp \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --enable-addons monitoring

# Get credentials
az aks get-credentials \
  --resource-group backend-first-idp-rg \
  --name backend-first-idp

# Verify cluster access
kubectl get nodes
# Expected: 3 nodes in Ready state
```

**Using Azure Portal**:
1. Navigate to: https://portal.azure.com
2. Search for "Kubernetes services"
3. Click "Create" → "Kubernetes cluster"
4. Settings:
   - **Resource group**: backend-first-idp-rg (create new)
   - **Cluster name**: backend-first-idp
   - **Region**: East US
   - **Kubernetes version**: Latest stable
   - **Node count**: 3
   - **Node size**: Standard_D2s_v3
5. Click "Review + create"
6. Wait ~5-7 minutes for provisioning
7. Click "Connect" and run the Azure CLI command shown

**Cost**: ~$200-250/month
- AKS control plane: Free
- 3x Standard_D2s_v3 nodes: $140-180/month (pay-as-you-go)
- Network egress: $10-20/month
- Azure Monitor (optional): $30-50/month

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

**Note**: KIND doesn't create real Azure resources (uses mock providers for testing).

---

## Step 3: Configure Virtual Network

### 3.1: Create or Use Existing VNet

```bash
# Option 1: Use AKS-created VNet (recommended)
export VNET_NAME=$(az network vnet list \
  --resource-group backend-first-idp-rg \
  --query "[0].name" -o tsv)

echo "VNet Name: $VNET_NAME"

# Option 2: Create new VNet for databases
az network vnet create \
  --resource-group backend-first-idp-rg \
  --name database-vnet \
  --address-prefix 10.1.0.0/16 \
  --subnet-name database-subnet \
  --subnet-prefix 10.1.0.0/24
```

### 3.2: Configure Network Security Group

```bash
# Create NSG for database subnet
az network nsg create \
  --resource-group backend-first-idp-rg \
  --name database-nsg

# Allow PostgreSQL traffic
az network nsg rule create \
  --resource-group backend-first-idp-rg \
  --nsg-name database-nsg \
  --name allow-postgres \
  --priority 100 \
  --source-address-prefixes VirtualNetwork \
  --destination-port-ranges 5432 \
  --access Allow \
  --protocol Tcp
```

---

## Step 4: Test Azure Connectivity

Before proceeding, verify Azure credentials work:

```bash
# Test Azure CLI authentication
az account show

# Expected output:
{
  "id": "12345678-1234-1234-1234-123456789012",
  "name": "Your Subscription",
  "tenantId": "87654321-4321-4321-4321-210987654321",
  "state": "Enabled"
}

# Test service principal authentication
az login --service-principal \
  --username $AZURE_CLIENT_ID \
  --password $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID

# Test resource access
az resource list --resource-group backend-first-idp-rg

# Test Azure SQL access
az sql server list
```

**If errors occur**:
- Verify service principal exists: `az ad sp show --id $AZURE_CLIENT_ID`
- Check role assignments: `az role assignment list --assignee $AZURE_CLIENT_ID`
- Verify subscription access: `az account list`

---

## Step 5: Install Crossplane Azure Provider

**Note**: Backend-First IDP setup script will handle this automatically in Q2 2026.

**Manual installation (preview)**:
```bash
# Install Crossplane Azure provider
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure
spec:
  package: upbound/provider-azure:v0.35.0
EOF

# Wait for provider to be ready
kubectl wait --for=condition=Healthy provider/provider-azure --timeout=300s

# Create secret with Azure credentials
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-literal=credentials=$(cat <<EOC
{
  "clientId": "$AZURE_CLIENT_ID",
  "clientSecret": "$AZURE_CLIENT_SECRET",
  "tenantId": "$AZURE_TENANT_ID",
  "subscriptionId": "$AZURE_SUBSCRIPTION_ID"
}
EOC
)

# Create ProviderConfig
cat <<EOF | kubectl apply -f -
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials
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
NAME             INSTALLED   HEALTHY   PACKAGE                            AGE
provider-azure   True        True      upbound/provider-azure:v0.35.0     2m
```

**If not healthy**:
```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure

# Common issues:
# - Credentials invalid: Re-check service principal credentials
# - Subscription not active: Verify subscription status
```

### 6.2: Test First Resource

Create a test Azure Database for PostgreSQL:

```bash
# Apply test claim
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: test-azure-setup
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 32
    version: "15"
  writeConnectionSecretToRef:
    name: test-azure-connection
EOF

# Watch provisioning (takes ~10-15 minutes for Azure)
kubectl get postgresql test-azure-setup -n dev --watch

# Expected progression:
# NAME                SYNCED   READY   AGE
# test-azure-setup    False    False   10s
# test-azure-setup    True     False   2m
# test-azure-setup    True     True    12m
```

### 6.3: Verify in Azure Portal

```bash
# List PostgreSQL servers via CLI
az postgres flexible-server list --output table

# Or check Azure Portal:
# https://portal.azure.com → Azure Database for PostgreSQL
```

**You should see**:
- PostgreSQL server named similar to "test-azure-setup-xxxxx"
- Status: Ready
- Version: PostgreSQL 15

---

## Step 7: Production Hardening (Optional)

### 7.1: Enable Encryption at Rest

```bash
# Create Azure Key Vault
az keyvault create \
  --name backend-first-idp-kv \
  --resource-group backend-first-idp-rg \
  --location eastus

# Create encryption key
az keyvault key create \
  --vault-name backend-first-idp-kv \
  --name kubernetes-secrets \
  --protection software

# Grant AKS access to Key Vault
az keyvault set-policy \
  --name backend-first-idp-kv \
  --object-id $(az aks show -g backend-first-idp-rg -n backend-first-idp --query identity.principalId -o tsv) \
  --key-permissions get unwrapKey wrapKey
```

### 7.2: Enable Azure Monitor

```bash
# Enable Container Insights
az aks enable-addons \
  --resource-group backend-first-idp-rg \
  --name backend-first-idp \
  --addons monitoring
```

### 7.3: Set Up Cost Alerts

```bash
# Create budget alert
az consumption budget create \
  --budget-name backend-first-idp-budget \
  --category cost \
  --amount 500 \
  --time-grain monthly \
  --start-date $(date +%Y-%m-01) \
  --end-date $(date -d "+1 year" +%Y-%m-01)
```

### 7.4: Enable Azure Policy

```bash
# Assign policy to enforce encryption
az policy assignment create \
  --name enforce-encryption \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/backend-first-idp-rg \
  --policy "Transparent Data Encryption on SQL databases should be enabled"
```

---

## Step 8: Multi-Region Setup (Optional)

To provision resources in multiple Azure regions:

### 8.1: Create Region-Specific ProviderConfigs

```yaml
# East US (already default)
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: azure-eastus
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials
      key: credentials

---
# West Europe
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: azure-westeurope
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-credentials
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
    region: westeurope  # Specify region
    resourceGroup: backend-first-idp-eu-rg
  providerConfigRef:
    name: azure-westeurope
```

---

## Troubleshooting

### Issue: Provider not becoming healthy

**Symptom**: `kubectl get providers` shows "Unknown" or "Unhealthy"

**Solution**:
```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure

# Common issues:
# 1. Service principal credentials invalid
az ad sp show --id $AZURE_CLIENT_ID

# 2. Subscription access denied
az account show

# 3. Provider installation failed
kubectl describe provider provider-azure
```

### Issue: PostgreSQL server stuck in creating

**Symptom**: PostgreSQL claim never reaches READY state

**Debug**:
```bash
# Check managed resources
kubectl get managed -o wide

# Check specific PostgreSQL server
kubectl describe flexibleservers.dbforpostgresql.azure.upbound.io <server-name>

# Check Azure Activity Log
az monitor activity-log list \
  --resource-group backend-first-idp-rg \
  --start-time $(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')
```

**Common causes**:
- VNet configuration issues
- NSG blocking connections
- Service principal permissions missing
- Resource quota exceeded

### Issue: Connection secret not created

**Symptom**: Secret missing after database is ready

**Solution**:
```bash
# Verify claim has writeConnectionSecretToRef
kubectl get postgresql <name> -n <namespace> -o yaml | grep -A 3 writeConnectionSecretToRef

# Check if secret exists but in different namespace
kubectl get secrets --all-namespaces | grep <name>

# Force reconcile
kubectl annotate postgresql <name> -n <namespace> crossplane.io/paused=false --overwrite
```

### Issue: Azure rate limiting

**Symptom**: "TooManyRequests" errors in logs

**Solution**:
```bash
# Increase Crossplane poll interval
kubectl edit deployment crossplane -n crossplane-system

# Add environment variable:
env:
- name: POLL_INTERVAL
  value: "120s"  # Increase from default 60s
```

---

## Cost Optimization

### Estimated Monthly Costs

**Development environment**:
- AKS cluster (control plane): $0 (free)
- 3x Standard_D2s_v3 nodes: $180 (pay-as-you-go)
- Azure Database PostgreSQL (B_Standard_B1ms): $12
- Azure Cache for Redis (Basic C0): $16
- Azure Storage (100 GB): $2
- **Total**: ~$210/month

**Production environment**:
- AKS cluster: $0
- 3x Standard_D4s_v3 nodes: $350
- Azure Database PostgreSQL HA (GP_Standard_D4s_v3): $350
- Azure Cache for Redis (Standard C1): $75
- Azure Storage (1 TB): $20
- **Total**: ~$795/month

### Cost Reduction Tips

**Use Spot VMs for dev**:
```bash
az aks nodepool add \
  --resource-group backend-first-idp-rg \
  --cluster-name backend-first-idp \
  --name spotpool \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --node-count 3 \
  --node-vm-size Standard_D2s_v3
# Saves ~70% vs pay-as-you-go
```

**Use Reserved Instances for production**:
```bash
# Purchase 1-year reservation (via Azure Portal)
# Savings: 30-40% vs pay-as-you-go
```

**Auto-shutdown dev resources**:
```bash
# Stop AKS nodes at night (via Azure Automation)
az aks stop \
  --resource-group backend-first-idp-rg \
  --name backend-first-idp

# Start in morning
az aks start \
  --resource-group backend-first-idp-rg \
  --name backend-first-idp
```

---

## Azure-Specific Features

### Private Endpoints

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: private-db
spec:
  parameters:
    size: small
    networkConfig:
      privateEndpoint: true  # Use private endpoint
      vnetName: backend-first-idp-vnet
      subnetName: database-subnet
```

### Azure AD Authentication

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: aad-db
spec:
  parameters:
    size: small
    authentication:
      type: AzureAD  # Use Azure AD instead of passwords
```

### Geo-Replication

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: geo-db
spec:
  parameters:
    size: large
    highAvailability: true
    geoRedundantBackup: true  # Geo-replicated backups
    replicaRegion: westeurope
```

---

## Next Steps

1. ✅ Azure setup complete!
2. 📖 Try the [Quick Start Guide](/docs/quickstart.md)
3. 🎓 Complete the [Tutorial](/TUTORIAL.md)
4. 🎬 Watch the [Demo](/docs/DEMO.md)

---

## Support

**Issues with Azure setup?**
- 💬 Slack: #backend-first-idp on [CNCF Slack](https://slack.cncf.io)
- 🐛 GitHub Issues: [Report bug](https://github.com/peopleforrester/2026_Kubecon_Europe_CNCF_Portal_Fatigue_IDP_Tutorial/issues)
- 📧 GitHub Issues: https://github.com/peopleforrester/2026_Kubecon_Europe_CNCF_Portal_Fatigue_IDP_Tutorial/issues

**Azure-specific questions?**
- Azure Support: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade
- Crossplane Azure Provider: https://marketplace.upbound.io/providers/upbound/provider-azure

---

**Last Updated**: 2026-01-15 | **Status**: Preview (Q2 2026 release)

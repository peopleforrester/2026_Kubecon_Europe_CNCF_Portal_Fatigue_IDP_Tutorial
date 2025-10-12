# Local Development Setup Guide

**Test Backend-First IDP locally without cloud costs**

This guide walks you through setting up a local development environment using KIND (Kubernetes in Docker) to test the Backend-First IDP platform without incurring cloud costs.

**Time required**: 10-15 minutes
**Cost**: $0 (runs entirely on your laptop)
**Use case**: Testing, learning, development, KubeCon tutorial

---

## Prerequisites

- **Docker Desktop** installed and running
  - macOS: https://docs.docker.com/desktop/install/mac-install/
  - Windows: https://docs.docker.com/desktop/install/windows-install/
  - Linux: https://docs.docker.com/desktop/install/linux-install/
- **kubectl** installed
- **Minimum system requirements**:
  - 8 GB RAM (16 GB recommended)
  - 20 GB free disk space
  - 4 CPU cores

---

## Step 1: Install KIND

**KIND** (Kubernetes in Docker) runs a Kubernetes cluster inside Docker containers.

### macOS

```bash
# Using Homebrew
brew install kind

# Or download binary
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-amd64
[ $(uname -m) = arm64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-darwin-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Linux

```bash
# Download binary
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Windows

```powershell
# Using Chocolatey
choco install kind

# Or download from: https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries
```

### Verify Installation

```bash
kind version
# Expected output: kind v0.20.0 go1.20.4 linux/amd64
```

---

## Step 2: Create KIND Cluster

### 2.1: Basic Cluster

**Quick start** (single node):
```bash
# Create cluster with default settings
kind create cluster --name backend-first-idp

# Verify cluster
kubectl cluster-info --context kind-backend-first-idp

# Expected output:
# Kubernetes control plane is running at https://127.0.0.1:xxxxx
```

### 2.2: Multi-Node Cluster (Recommended)

**For realistic testing** (3 nodes):
```bash
# Create cluster config
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: backend-first-idp
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
  - containerPort: 30443
    hostPort: 8443
    protocol: TCP
- role: worker
- role: worker
- role: worker
EOF

# Create cluster
kind create cluster --config kind-config.yaml

# Verify nodes
kubectl get nodes
# Expected: 1 control-plane, 3 workers (all Ready)
```

**Config explanation**:
- **control-plane**: Runs Kubernetes API server, scheduler, controller-manager
- **3 workers**: Run application workloads (ArgoCD, Crossplane, etc.)
- **Port mappings**: Access ArgoCD UI at localhost:8080

### 2.3: Cluster with Resource Limits (Optional)

For testing resource constraints:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: backend-first-idp
nodes:
- role: control-plane
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        system-reserved: memory=1Gi,cpu=500m
        kube-reserved: memory=1Gi,cpu=500m
```

---

## Step 3: Install Backend-First IDP

Now install ArgoCD + Crossplane on your local cluster:

### 3.1: Clone Repository

```bash
# Clone repo
git clone https://github.com/[ORG]/backend-first-idp.git
cd backend-first-idp
```

### 3.2: Run Setup Script

```bash
# Run setup (skip cloud provider)
./scripts/setup.sh
```

**Follow the prompts**:
```
Which cloud provider would you like to configure?
  1) AWS
  2) GCP (Coming soon)
  3) Azure (Coming soon)
  4) Skip for now
Enter choice [1-4]: 4

ℹ Skipping cloud provider configuration
✓ ArgoCD installed successfully
✓ Crossplane installed successfully
```

**Installation time**: ~5-7 minutes

---

## Step 4: Configure Mock Provider (Optional)

For testing without real cloud resources, use a mock provider:

### 4.1: Install Mock Provider

```bash
# Install Crossplane provider-kubernetes (creates K8s resources as "infrastructure")
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: crossplane-contrib/provider-kubernetes:v0.9.0
EOF

# Wait for provider
kubectl wait --for=condition=Healthy provider/provider-kubernetes --timeout=180s
```

### 4.2: Configure Provider

```bash
# Create ProviderConfig using in-cluster config
SA=$(kubectl -n crossplane-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|crossplane-system:|g')
kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"

cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: kubernetes-provider
spec:
  credentials:
    source: InjectedIdentity
EOF
```

### 4.3: Test Mock Resources

```bash
# Create test "database" (really a ConfigMap)
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: mock-db
  namespace: dev
spec:
  parameters:
    size: small
    mock: true  # Use mock provider
  writeConnectionSecretToRef:
    name: mock-db-connection
EOF

# Watch status
kubectl get postgresql mock-db -n dev --watch

# Expected: READY=True within 30 seconds (no real provisioning)
```

---

## Step 5: Access ArgoCD UI

### 5.1: Port Forward (if not using kind-config.yaml)

```bash
# Forward ArgoCD server
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Open browser to: https://localhost:8080
```

### 5.2: Get Admin Password

```bash
# Retrieve password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Expected output: abc123xyz789...
```

### 5.3: Login

1. Open browser: https://localhost:8080
2. Accept self-signed certificate warning
3. Login:
   - **Username**: admin
   - **Password**: (from step 5.2)

---

## Step 6: Test Complete Workflow

### 6.1: Create Test Database

```bash
# Create PostgreSQL claim
cat > environments/dev/test-local-db.yaml <<'EOF'
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: test-local-db
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 10
    version: "15"
    mock: true  # Use mock provider for local testing
  writeConnectionSecretToRef:
    name: test-local-db-connection
EOF

# Apply
kubectl apply -f environments/dev/test-local-db.yaml

# Watch status
kubectl get postgresql test-local-db -n dev --watch
```

### 6.2: Verify Secret Creation

```bash
# Check secret exists
kubectl get secret test-local-db-connection -n dev

# View secret contents
kubectl get secret test-local-db-connection -n dev -o yaml

# Expected: Contains mock connection details
```

### 6.3: Deploy Test Application

```bash
# Deploy simple app that uses database
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: app
        image: postgres:15-alpine
        command: ["sleep", "infinity"]
        env:
        - name: POSTGRES_HOST
          valueFrom:
            secretKeyRef:
              name: test-local-db-connection
              key: endpoint
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: test-local-db-connection
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: test-local-db-connection
              key: password
EOF

# Verify app is running
kubectl get pods -n dev -l app=test-app

# Check environment variables
kubectl exec -n dev deployment/test-app -- env | grep POSTGRES
```

---

## Step 7: Testing Features Locally

### 7.1: Test GitOps Workflow

```bash
# Make changes in Git
echo "# test change" >> environments/dev/test-local-db.yaml
git add environments/dev/test-local-db.yaml
git commit -m "test: Update database config"

# Watch ArgoCD sync (if configured)
argocd app get platform-dev --refresh
```

### 7.2: Test Policy Enforcement

```bash
# Try to create public database (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: public-db
  namespace: dev
spec:
  parameters:
    size: small
    networkConfig:
      publiclyAccessible: true  # Should be denied by policy
EOF

# Expected: Request denied by Kyverno policy
```

### 7.3: Test Multi-Environment

```bash
# Create staging namespace
kubectl create namespace staging

# Create same database in staging
sed 's/namespace: dev/namespace: staging/' environments/dev/test-local-db.yaml | kubectl apply -f -

# Verify both exist
kubectl get postgresql -A
```

---

## Step 8: Load Testing (Optional)

### 8.1: Stress Test Crossplane

```bash
# Create 10 databases simultaneously
for i in {1..10}; do
  cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: stress-test-db-$i
  namespace: dev
spec:
  parameters:
    size: small
    mock: true
EOF
done

# Watch Crossplane handle load
kubectl get postgresql -n dev --watch
```

### 8.2: Monitor Resource Usage

```bash
# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics-server for KIND
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# View resource usage
kubectl top nodes
kubectl top pods -n crossplane-system
```

---

## Troubleshooting

### Issue: KIND cluster won't start

**Symptom**: `kind create cluster` fails

**Solution**:
```bash
# Check Docker is running
docker ps

# If not running, start Docker Desktop

# Delete existing cluster
kind delete cluster --name backend-first-idp

# Try again
kind create cluster --name backend-first-idp
```

### Issue: Out of resources

**Symptom**: Pods stuck in Pending state

**Solution**:
```bash
# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Increase Docker Desktop resources:
# Docker Desktop → Settings → Resources
# - CPUs: 4 (minimum)
# - Memory: 8 GB (minimum)
# - Swap: 2 GB
# - Disk: 60 GB

# Restart Docker Desktop after changes
```

### Issue: ArgoCD not accessible

**Symptom**: https://localhost:8080 not reachable

**Solution**:
```bash
# Check port-forward is running
ps aux | grep "port-forward"

# If not, restart it
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Check ArgoCD pods are running
kubectl get pods -n argocd

# If pods are failing, check logs
kubectl logs -n argocd deployment/argocd-server
```

### Issue: Mock provider not working

**Symptom**: PostgreSQL claims stuck in Pending

**Solution**:
```bash
# Check provider-kubernetes is healthy
kubectl get providers

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-kubernetes

# Verify RBAC
kubectl get clusterrolebinding provider-kubernetes-admin-binding
```

---

## Limitations of Local Development

**What works locally**:
- ✅ GitOps workflows (ArgoCD)
- ✅ Resource provisioning (mock providers)
- ✅ Policy enforcement (Kyverno)
- ✅ Multi-environment testing
- ✅ Application deployment
- ✅ Secret management

**What doesn't work locally**:
- ❌ Real cloud resources (RDS, ElastiCache, etc.)
- ❌ Cloud-specific features (VPC peering, IAM roles)
- ❌ Multi-cluster scenarios
- ❌ Cloud cost estimation
- ❌ Production-scale load testing

**Recommendation**: Use local for learning/testing, cloud for production.

---

## Transitioning to Cloud

When ready to move to real cloud infrastructure:

### Step 1: Keep Local Cluster

Keep local cluster for testing changes before cloud deployment.

### Step 2: Add Cloud Provider

```bash
# Install AWS provider (example)
kubectl apply -f crossplane/providers/provider-aws.yaml

# Configure credentials
kubectl create secret generic aws-credentials \
  -n crossplane-system \
  --from-literal=credentials="[default]
aws_access_key_id = YOUR_KEY
aws_secret_access_key = YOUR_SECRET"
```

### Step 3: Update Compositions

```bash
# Change mock: true to mock: false
sed -i 's/mock: true/mock: false/' environments/dev/*.yaml

# Apply to cloud
kubectl apply -f environments/dev/
```

### Step 4: Verify

```bash
# Watch real cloud resources being created
kubectl get managed --watch

# Verify in cloud console (AWS, GCP, Azure)
```

---

## Tips for Local Development

### Use Octant for Visualization

```bash
# Install Octant (Kubernetes dashboard)
brew install octant  # macOS
# or download from: https://github.com/vmware-tanzu/octant/releases

# Run
octant

# Open browser to: http://localhost:7777
```

### Use k9s for Terminal UI

```bash
# Install k9s (terminal UI for Kubernetes)
brew install k9s  # macOS
# or download from: https://k9scli.io/topics/install/

# Run
k9s
```

### Use stern for Log Streaming

```bash
# Install stern
brew install stern  # macOS

# Stream logs from all Crossplane pods
stern -n crossplane-system .

# Stream logs from specific claim
stern postgresql
```

### Save Docker Images

```bash
# Export ArgoCD images (for offline use)
docker save $(docker images | grep argocd | awk '{print $1":"$2}') -o argocd-images.tar

# Load on another machine
docker load -i argocd-images.tar
```

---

## Cleanup

When done testing:

### Delete Resources

```bash
# Delete all PostgreSQL claims
kubectl delete postgresql --all -A

# Delete test applications
kubectl delete deployment test-app -n dev
```

### Delete Cluster

```bash
# Delete KIND cluster
kind delete cluster --name backend-first-idp

# Verify deletion
kind get clusters
# Expected: No clusters found
```

### Cleanup Docker

```bash
# Remove dangling images
docker image prune -a

# Check disk space reclaimed
docker system df
```

---

## Cost Comparison

| Setup | Monthly Cost | Best For |
|-------|-------------|----------|
| **Local (KIND)** | $0 | Learning, testing, tutorials |
| **AWS** | $200-300 | Production, real workloads |
| **GCP** | $150-250 | Production, real workloads |
| **Azure** | $200-300 | Production, real workloads |

**Recommendation**: Start local for KubeCon tutorial, move to cloud for production.

---

## Next Steps

1. ✅ Local setup complete!
2. 📖 Try the [Quick Start Guide](/docs/quickstart.md)
3. 🎓 Complete the [Tutorial](/TUTORIAL.md) - designed for local testing!
4. 🎬 Watch the [Demo](/docs/DEMO.md)
5. ☁️ When ready: [AWS Setup](/docs/cloud-setup/AWS.md)

---

## Support

**Issues with local setup?**
- 💬 Slack: #backend-first-idp on [CNCF Slack](https://slack.cncf.io)
- 🐛 GitHub Issues: [Report bug](https://github.com/[ORG]/backend-first-idp/issues)
- 📧 Email: local-help@backend-first-idp.io

**KIND-specific questions?**
- KIND Docs: https://kind.sigs.k8s.io/docs/user/quick-start/
- KIND GitHub: https://github.com/kubernetes-sigs/kind

---

**Last Updated**: 2026-01-15

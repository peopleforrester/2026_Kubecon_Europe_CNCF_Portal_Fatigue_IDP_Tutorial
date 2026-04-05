# Quick Start Guide

**Get running in 15-20 minutes**

This guide will have you provisioning infrastructure via GitOps in 3 paths:
1. **Local (KIND)** - Test without cloud costs
2. **Cloud (AWS/GCP/Azure)** - Production-ready setup
3. **Sandbox** - Pre-configured KubeCon environment

---

## Prerequisites

### Required Tools

```bash
# Verify you have these installed
kubectl version --client    # v1.28 or higher
helm version               # v3.12 or higher
git --version             # Any recent version
```

**Installation guides**:
- **kubectl**: https://kubernetes.io/docs/tasks/tools/
- **helm**: https://helm.sh/docs/intro/install/
- **git**: https://git-scm.com/downloads

### Kubernetes Cluster

**Option 1: Local KIND cluster** (recommended for testing)
```bash
# Install KIND
brew install kind  # macOS
# or: curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64

# Create cluster
kind create cluster --name backend-first-idp
```

**Option 2: Cloud cluster** (for production)
- EKS (AWS): Requires 3+ nodes, t3.medium or larger
- GKE (Google): Requires 3+ nodes, e2-standard-2 or larger
- AKS (Azure): Requires 3+ nodes, Standard_D2s_v3 or larger

**Option 3: Sandbox** (KubeCon attendees)
- Pre-configured cluster provided
- Credentials distributed during session
- No setup required

### Cloud Credentials (if using Option 2)

**AWS**:
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```
See: [AWS Setup Guide](/docs/cloud-setup/AWS.md)

**GCP**: See [GCP Setup Guide](/docs/cloud-setup/GCP.md)
**Azure**: See [Azure Setup Guide](/docs/cloud-setup/AZURE.md)

---

## Installation

### Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/[ORG]/backend-first-idp.git
cd backend-first-idp

# Verify you're in the right place
ls -la
# Expected: argocd/, crossplane/, bin/, docs/, etc.
```

### Step 2: Pre-flight Checks

```bash
# Run the setup script (it will verify prerequisites first)
./scripts/setup.sh
```

**What the script checks**:
- ✅ kubectl installed and configured
- ✅ Helm installed
- ✅ Git installed
- ✅ Cluster accessible
- ✅ Sufficient cluster resources

**If checks fail**:
- Install missing tools (see Prerequisites above)
- Verify kubectl can access cluster: `kubectl cluster-info`
- Check cluster has nodes: `kubectl get nodes`

### Step 3: Run Installation

The setup script will install:
1. **ArgoCD** (GitOps engine) - ~2 minutes
2. **Crossplane** (Infrastructure provisioning) - ~3 minutes
3. **Cloud provider** (AWS/GCP/Azure) - ~2 minutes
4. **Platform config** (namespaces, apps) - ~1 minute

**Total time**: ~8-10 minutes

```bash
# Continue with setup (after pre-flight checks pass)
# The script will prompt for:
#   - Cloud provider choice (AWS/GCP/Azure/Skip)
#   - AWS credentials (if AWS selected)
#   - Confirmation to proceed

# Follow the prompts
```

**Expected output**:
```
╔═══════════════════════════════════════════════════════╗
║                                                       ║
║       Backend-First IDP Setup                         ║
║       Production Infrastructure Control Plane         ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝

This script will install:
  • ArgoCD (GitOps engine)
  • Crossplane (Infrastructure provisioning)
  • Platform configuration

Continue with installation? [y/N] y

ℹ Running pre-flight checks...
✓ All required commands found
✓ Kubernetes cluster accessible
✓ Cluster has 3 node(s)

ℹ Installing ArgoCD v3.3.6...
✓ Created namespace argocd
✓ ArgoCD installed successfully

ArgoCD Admin Credentials:
  URL:      https://localhost:8080
  Username: admin
  Password: abc123xyz789...

ℹ Installing Crossplane 2.2.0...
✓ Added Crossplane Helm repository
✓ Created namespace crossplane-system
✓ Crossplane installed successfully

ℹ Cloud provider configuration
Which cloud provider would you like to configure?
  1) AWS
  2) GCP (Coming soon)
  3) Azure (Coming soon)
  4) Skip for now
Enter choice [1-4]: 1

ℹ Configuring AWS Provider...
AWS Access Key ID: AKIA...
AWS Secret Access Key: ****
✓ Created AWS credentials secret
✓ AWS provider configured successfully

╔═══════════════════════════════════════════════════════╗
║                                                       ║
║   Backend-First IDP Installation Complete! 🎉        ║
║                                                       ║
╚═══════════════════════════════════════════════════════╝
```

### Step 4: Verify Installation

```bash
# Check ArgoCD is running
kubectl get pods -n argocd
# Expected: All pods in Running state

# Check Crossplane is running
kubectl get pods -n crossplane-system
# Expected: crossplane pod Running

# Check provider is healthy (if configured)
kubectl get providers
# Expected: provider-aws INSTALLED=True, HEALTHY=True
```

**Success criteria**:
- ✅ All ArgoCD pods are Running (5-7 pods)
- ✅ Crossplane pod is Running
- ✅ Provider shows Healthy (if cloud configured)

### Step 5: Access ArgoCD UI (Optional)

```bash
# Port-forward to ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Open browser to: https://localhost:8080
# Login: admin / <password-from-above>
```

### Step 6: Deploy First Infrastructure

Now the exciting part - provision real infrastructure via Git commit!

#### 6.1: Create Database Claim

```bash
# Create a PostgreSQL database in dev
cat > environments/dev/my-first-db.yaml <<'EOF'
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-first-db
  namespace: dev
spec:
  parameters:
    size: small              # t3.micro (~$85/month)
    storageGB: 20            # 20GB storage
    version: "15"            # PostgreSQL 15
    highAvailability: false  # Single instance
  writeConnectionSecretToRef:
    name: my-first-db-connection
EOF
```

#### 6.2: Commit to Git

```bash
# Add and commit
git add environments/dev/my-first-db.yaml
git commit -m "feat: Add my first PostgreSQL database"

# Push to trigger GitOps (if you have remote configured)
git push origin main
# If no remote, ArgoCD will sync local changes
```

#### 6.3: Watch Provisioning

```bash
# Watch claim status
kubectl get postgresql my-first-db -n dev --watch

# Expected progression:
# NAME           SYNCED   READY   AGE
# my-first-db    False    False   10s
# my-first-db    True     False   90s   # Synced to cluster
# my-first-db    True     True    5m    # Cloud resource ready
```

**Timing**:
- KIND (local): ~30 seconds (mocked resources)
- AWS/Cloud: ~5-10 minutes (real RDS instance)

#### 6.4: Verify Connection Secret

```bash
# Check secret was created
kubectl get secret my-first-db-connection -n dev

# View secret contents (base64 encoded)
kubectl get secret my-first-db-connection -n dev -o yaml

# Decode to see actual values
kubectl get secret my-first-db-connection -n dev \
  -o jsonpath='{.data.endpoint}' | base64 -d
# Output: my-first-db.xxxx.us-west-2.rds.amazonaws.com
```

**Secret contains**:
- `endpoint` - Database hostname
- `port` - Database port (5432)
- `username` - Admin username
- `password` - Admin password
- `database` - Database name

---

## Success Checklist

You've successfully set up the Backend-First IDP if:

- ✅ ArgoCD UI accessible at https://localhost:8080
- ✅ Crossplane provider shows "Healthy"
- ✅ PostgreSQL claim shows "READY=True"
- ✅ Connection secret exists with credentials
- ✅ (Cloud only) Real RDS instance visible in AWS console

---

## Troubleshooting

### Setup script fails

**Symptom**: Script exits with errors

**Common causes**:
1. **Missing kubectl**: Install from https://kubernetes.io/docs/tasks/tools/
2. **No cluster access**: Run `kubectl cluster-info` to verify
3. **Insufficient permissions**: Check RBAC with `kubectl auth can-i create pods`

**Solution**:
```bash
# Check kubectl config
kubectl config current-context
kubectl config get-contexts

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

### ArgoCD pods not starting

**Symptom**: Pods in CrashLoopBackOff or Pending

**Cause**: Insufficient cluster resources

**Solution**:
```bash
# Check node resources
kubectl top nodes
kubectl describe nodes

# Check pod status
kubectl describe pod -n argocd argocd-server-xxx

# If resource constrained, increase node size or count
```

### Provider not healthy

**Symptom**: `kubectl get providers` shows "Unknown" or "Unhealthy"

**Cause**: Invalid credentials or provider installation issue

**Solution**:
```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws

# Verify credentials secret
kubectl get secret aws-credentials -n crossplane-system
kubectl describe secret aws-credentials -n crossplane-system

# Re-apply provider config
kubectl apply -f crossplane/providers/aws-provider-config.yaml
```

### Claim stuck in Pending

**Symptom**: PostgreSQL claim doesn't reach READY state

**Debugging**:
```bash
# Check claim status
kubectl describe postgresql my-first-db -n dev

# Check managed resources
kubectl get managed -o wide

# Check Crossplane logs
kubectl logs -n crossplane-system -l app=crossplane

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws
```

**Common issues**:
- **Credentials invalid**: Verify AWS credentials work
- **No internet access**: Cluster can't reach cloud APIs
- **Composition not found**: Check Composition exists: `kubectl get compositions`

### Connection secret not created

**Symptom**: Secret missing after claim is READY

**Solution**:
```bash
# Verify claim has writeConnectionSecretToRef
kubectl get postgresql my-first-db -n dev -o yaml | grep -A 3 writeConnectionSecretToRef

# Check if secret exists but in different namespace
kubectl get secrets --all-namespaces | grep my-first-db

# Force reconcile
kubectl annotate postgresql my-first-db -n dev \
  crossplane.io/paused=false --overwrite
```

### Cloud resources not appearing

**Symptom**: Claim is READY but no AWS resource

**Verification**:
```bash
# Check managed resources
kubectl get managed

# Look for RDS instance
kubectl get dbinstances.rds.aws.upbound.io

# Verify in AWS console
# https://console.aws.amazon.com/rds/
```

**If missing**:
- Check provider has correct credentials
- Verify AWS region in ProviderConfig
- Check IAM permissions for RDS

---

## What's Next?

### Explore Examples

```bash
# Deploy full application stack
kubectl apply -f examples/simple-api-application.yaml

# Try other resource types
kubectl apply -f environments/dev/redis-claim.yaml
kubectl apply -f environments/dev/s3bucket-claim.yaml
```

### Customize for Your Environment

1. **Add custom Compositions**: See `/crossplane/compositions/`
2. **Configure policies**: See `/kyverno/policies/`
3. **Set up multi-environment**: See `/environments/`
4. **Enable monitoring**: See Phase 2 roadmap

### Learn More

- **Tutorial**: [TUTORIAL.md](/TUTORIAL.md) - 75-minute hands-on lab
- **FAQ**: [docs/FAQ.md](/docs/FAQ.md) - Common questions
- **API Reference**: [docs/API_REFERENCE.md](/docs/API_REFERENCE.md) - All resource types
- **Use Cases**: [docs/USE_CASES.md](/docs/USE_CASES.md) - Real-world patterns
- **Video Guide**: [docs/VIDEO_GUIDE.md](/docs/VIDEO_GUIDE.md) - Walkthroughs

### Join the Community

- **GitHub Discussions**: Ask questions, share ideas
- **Slack**: `#backend-first-idp` on CNCF Slack (https://slack.cncf.io)
- **Office Hours**: First Tuesday monthly, 10 AM ET
- **Issues**: Report bugs, request features

---

## Cleanup

When you're done testing:

```bash
# Delete all claims
kubectl delete postgresql --all -n dev

# Uninstall Crossplane (optional)
helm uninstall crossplane -n crossplane-system

# Uninstall ArgoCD (optional)
kubectl delete namespace argocd

# Delete KIND cluster (if using KIND)
kind delete cluster --name backend-first-idp
```

---

**Questions?** See [FAQ.md](/docs/FAQ.md) or join us on Slack!

**Next**: Try the full [Tutorial](/TUTORIAL.md) for a deeper dive.

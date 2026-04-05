# Contributing to Backend-First IDP

First off, thank you for considering contributing to the Backend-First IDP! It's people like you who make this project possible.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project adheres to the CNCF Code of Conduct. By participating, you are expected to uphold this code.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples**
- **Describe the behavior you observed** and **what you expected**
- **Include logs** and error messages
- **Include your environment** (Kubernetes version, cloud provider, etc.)

**Bug Report Template:**
```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce:
1. Apply claim '...'
2. Run command '...'
3. See error

**Expected behavior**
What you expected to happen.

**Environment**
- Kubernetes version: [e.g. 1.28]
- Cloud provider: [e.g. AWS]
- Crossplane version: [e.g. 2.2.0]
- ArgoCD version: [e.g. 3.3.6]

**Additional context**
Any other context about the problem.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List some examples** of how it would be used

### Adding New Features

Before working on a new feature:

1. **Open an issue** to discuss the feature
2. **Wait for approval** from maintainers
3. **Create a feature branch** from `main`
4. **Develop the feature** following our guidelines
5. **Write tests** for the new feature
6. **Update documentation**
7. **Submit a pull request**

## Development Setup

### Prerequisites

- **Kubernetes cluster** (kind, k3s, or cloud provider)
- **kubectl** v1.28+
- **git** v2.40+
- **bash** v4.0+
- **Python** 3.9+ (for tests)
- **yq** v4.0+ (for YAML processing)

### Fork and Clone

```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/backend-first-idp.git
cd backend-first-idp

# Add upstream remote
git remote add upstream https://github.com/ORIGINAL_OWNER/backend-first-idp.git

# Verify remotes
git remote -v
```

### Complete Development Environment Setup

#### Option 1: Local Development with KIND

This is the recommended option for contributing without cloud costs.

```bash
# 1. Install KIND (if not already installed)
# macOS
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 2. Create local Kubernetes cluster
kind create cluster --name idp-dev --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 8080
    protocol: TCP
  - containerPort: 30443
    hostPort: 8443
    protocol: TCP
EOF

# 3. Verify cluster
kubectl cluster-info --context kind-idp-dev
kubectl get nodes

# 4. Install platform components
./scripts/setup.sh

# 5. Verify installations
kubectl get pods -n argocd
kubectl get pods -n crossplane-system
kubectl get pods -n kyverno
```

**Time to complete**: ~15 minutes
**Cost**: $0

#### Option 2: Cloud Development (AWS Example)

For testing real cloud resource provisioning:

```bash
# 1. Create EKS cluster
eksctl create cluster \
  --name idp-dev \
  --region us-east-1 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# 2. Configure kubectl
aws eks update-kubeconfig --name idp-dev --region us-east-1

# 3. Install platform components
./scripts/setup.sh

# 4. Configure AWS provider for Crossplane
kubectl create secret generic aws-creds \
  -n crossplane-system \
  --from-file=credentials=~/.aws/credentials

kubectl apply -f crossplane/providers/aws/provider-config.yaml
```

**Time to complete**: ~20-30 minutes
**Cost**: ~$100-150/month

#### Option 3: Minikube (Alternative Local)

```bash
# 1. Install Minikube
# macOS
brew install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# 2. Start cluster with extra resources
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=50g \
  --kubernetes-version=v1.28.0

# 3. Enable addons
minikube addons enable metrics-server
minikube addons enable ingress

# 4. Install platform components
./scripts/setup.sh
```

### Install Development Dependencies

```bash
# Install test framework
pip install pytest pyyaml kubernetes

# Install YAML linter
pip install yamllint

# Install shellcheck (for bash scripts)
# macOS
brew install shellcheck

# Linux
apt-get install shellcheck

# Install Kubernetes validation tools
# kubeval - Validate Kubernetes YAML
brew install kubeval  # macOS
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz  # Linux
tar xf kubeval-linux-amd64.tar.gz
sudo mv kubeval /usr/local/bin

# kubeconform - Another validation option
go install github.com/yannh/kubeconform/cmd/kubeconform@latest

# Install Kyverno CLI (for policy testing)
brew install kyverno  # macOS
# Linux
wget https://github.com/kyverno/kyverno/releases/download/v1.17.1/kyverno-cli_v1.17.1_linux_x86_64.tar.gz
tar -xvf kyverno-cli_v1.17.1_linux_x86_64.tar.gz
sudo mv kyverno /usr/local/bin/

# Install ArgoCD CLI (for testing GitOps workflows)
brew install argocd  # macOS
# Linux
curl -sSL -o argocd https://github.com/argoproj/argocd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

### Development Workflow

#### Daily Development Loop

```bash
# 1. Start your day by syncing with upstream
git checkout main
git fetch upstream
git merge upstream/main
git push origin main

# 2. Create feature branch
git checkout -b feature/my-contribution

# 3. Make changes to files
# Edit: crossplane/compositions/composition-postgresql-aws.yaml

# 4. Validate changes locally
yamllint crossplane/compositions/composition-postgresql-aws.yaml
kubeval crossplane/compositions/composition-postgresql-aws.yaml

# 5. Test in local cluster
kubectl apply -f crossplane/compositions/composition-postgresql-aws.yaml
kubectl apply -f examples/postgresql-claim-dev.yaml

# 6. Watch for resource creation
kubectl get composite -w
kubectl get managed -w

# 7. Check logs if issues occur
kubectl logs -n crossplane-system -l app=crossplane --tail=100

# 8. Commit and push when working
git add crossplane/compositions/composition-postgresql-aws.yaml
git commit -m "feat(crossplane): Improve PostgreSQL composition performance"
git push origin feature/my-contribution

# 9. Create pull request on GitHub
```

#### Testing Changes End-to-End

```bash
# 1. Deploy your changes via ArgoCD
kubectl apply -f argocd/applications/platform-compositions.yaml

# 2. Verify ArgoCD sees the changes
argocd app get platform-compositions

# 3. Sync the application
argocd app sync platform-compositions

# 4. Watch the sync
argocd app wait platform-compositions --sync

# 5. Test with real claim
kubectl apply -f environments/dev/postgresql-claim.yaml

# 6. Verify provisioning
kubectl describe postgresql app-database -n dev
kubectl get secrets -n dev

# 7. Cleanup when done
kubectl delete -f environments/dev/postgresql-claim.yaml
```

### Run Tests Locally

```bash
# Lint YAML files
yamllint crossplane/ environments/ kyverno/

# Validate Kubernetes manifests
kubeval crossplane/**/*.yaml
kubeconform -strict crossplane/

# Lint bash scripts
shellcheck scripts/*.sh

# Test Kyverno policies
kyverno test kyverno/policies/

# Run unit tests
pytest tests/unit/ -v

# Run integration tests (requires cluster)
pytest tests/integration/ -v --cluster-context=kind-idp-dev

# Run E2E tests (requires cluster + cloud credentials)
pytest tests/e2e/ -v --cloud-provider=aws
```

### Troubleshooting Development Environment

#### Issue: Crossplane Provider Not Installing

**Symptoms:**
```
kubectl get providers
NAME            INSTALLED   HEALTHY   AGE
provider-aws    Unknown     Unknown   2m
```

**Solution:**
```bash
# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws

# Common fixes:
# 1. Verify internet connectivity
# 2. Check for ImagePullBackOff
kubectl describe provider provider-aws

# 3. Manually pull and verify image
docker pull xpkg.upbound.io/crossplane-contrib/provider-aws:v0.47.0
```

#### Issue: ArgoCD Not Syncing Changes

**Symptoms:** Your changes aren't appearing in the cluster

**Solution:**
```bash
# 1. Verify ArgoCD can reach Git repo
argocd app get platform-compositions

# 2. Force refresh
argocd app get platform-compositions --refresh

# 3. Check for sync errors
kubectl describe application platform-compositions -n argocd

# 4. Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

#### Issue: KIND Cluster Out of Resources

**Symptoms:** Pods stuck in Pending state

**Solution:**
```bash
# Check node resources
kubectl top nodes
kubectl describe node kind-idp-dev-control-plane

# Delete and recreate with more resources
kind delete cluster --name idp-dev
kind create cluster --name idp-dev --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /var/run/docker.sock
    containerPath: /var/run/docker.sock
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        system-reserved: memory=2Gi
EOF
```

## Pull Request Process

### 1. Create a Feature Branch

```bash
# Update your main branch
git checkout main
git pull upstream main

# Create feature branch
git checkout -b feature/my-new-feature
```

### 2. Make Your Changes

- Follow our [Coding Standards](#coding-standards)
- Write [Tests](#testing)
- Update [Documentation](#documentation)

### 3. Commit Your Changes

We use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format
<type>(<scope>): <subject>

# Examples
feat(cli): Add cost comparison command
fix(kyverno): Prevent policy bypass via annotations
docs(readme): Update installation instructions
test(compositions): Add PostgreSQL composition tests
chore(deps): Update Crossplane to v1.17.0
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `ci`: CI/CD changes

### 4. Push to Your Fork

```bash
git push origin feature/my-new-feature
```

### 5. Create Pull Request

- **Title**: Clear and descriptive (using conventional commits format)
- **Description**: Explain what and why (not how - that's in the code)
- **Link issues**: Use "Fixes #123" or "Closes #456"
- **Add labels**: bug, enhancement, documentation, etc.
- **Request review**: Tag relevant maintainers

**Pull Request Template:**
```markdown
## Description
Brief description of the changes.

## Motivation
Why is this change needed? What problem does it solve?

## Changes
- Change 1
- Change 2
- Change 3

## Testing
How have you tested this? Please describe.

## Screenshots (if applicable)
Add screenshots for UI changes.

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code where necessary
- [ ] I have updated the documentation
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing tests pass locally
- [ ] Any dependent changes have been merged
```

### 6. Code Review Process

- Maintainers will review your PR
- Address feedback by pushing new commits
- Once approved, maintainers will merge

## Coding Standards

### Bash Scripts (CLI Tools)

```bash
#!/usr/bin/env bash
# ABOUTME: Brief description of what this script does
# ABOUTME: Second line of description if needed

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Helper functions
error() {
    echo -e "${RED}✗${NC} $1" >&2
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Main function
main() {
    # Validate inputs
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    # Do work
    # ...
}

# Call main
main "$@"
```

**Guidelines:**
- Always use `set -euo pipefail`
- Validate ALL user inputs
- Use `shellcheck` to lint
- Add comments for complex logic
- Use helper functions for output
- Handle errors gracefully

### YAML Files

```yaml
# ABOUTME: Brief description of this resource
# ABOUTME: Second line if needed

apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: example-db
  namespace: dev
  labels:
    app: example
    environment: dev
  annotations:
    description: "Example database for documentation"
spec:
  # Group related fields
  parameters:
    # Comment inline for clarity
    size: small
    storageGB: 20
```

**Guidelines:**
- Add ABOUTME header to every file
- Use 2-space indentation
- Group related fields
- Add inline comments for non-obvious settings
- Use `yamllint` to check formatting

### Crossplane Compositions

```yaml
# Composition naming: composition-<resource>-<provider>.yaml
# XRD naming: xrd-<resource>.yaml

# Always include:
- type: FromCompositeFieldPath
  fromFieldPath: spec.parameters.size
  toFieldPath: spec.forProvider.instanceClass
  transforms:
    - type: map
      map:
        small: db.t3.micro
        medium: db.t3.small
        large: db.t3.medium
```

**Guidelines:**
- Use descriptive resource names
- Add transforms for human-friendly values
- Include status patches (ToCompositeFieldPath)
- Document required provider setup

#### Step-by-Step: Adding a New Crossplane Composition

This guide walks through creating a new Redis composition from scratch.

**Step 1: Define the XRD (Composite Resource Definition)**

Create `crossplane/xrds/xrd-redis.yaml`:

```yaml
# ABOUTME: Defines the Redis API for platform users
# ABOUTME: Users create Redis claims that reference this XRD

apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xredis.platform.example.io
spec:
  group: platform.example.io
  names:
    kind: XRedis
    plural: xredis
  claimNames:
    kind: Redis
    plural: redis
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              parameters:
                type: object
                properties:
                  size:
                    type: string
                    enum: ["small", "medium", "large"]
                    description: "Size of the Redis instance"
                  version:
                    type: string
                    default: "7.0"
                    description: "Redis version"
                  highAvailability:
                    type: boolean
                    default: false
                    description: "Enable Redis cluster mode"
                required:
                  - size
              environment:
                type: string
                enum: ["dev", "staging", "prod"]
                description: "Target environment"
              region:
                type: string
                default: "us-east-1"
                description: "Cloud region"
            required:
              - parameters
              - environment
          status:
            type: object
            properties:
              endpoint:
                type: string
              port:
                type: integer
              ready:
                type: boolean
```

**Step 2: Create the Composition**

Create `crossplane/compositions/composition-redis-aws.yaml`:

```yaml
# ABOUTME: AWS implementation of Redis using ElastiCache
# ABOUTME: Maps user-friendly parameters to AWS-specific configuration

apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: redis-aws
  labels:
    provider: aws
    service: redis
spec:
  compositeTypeRef:
    apiVersion: platform.example.io/v1alpha1
    kind: XRedis

  resources:
  # ElastiCache Subnet Group
  - name: subnet-group
    base:
      apiVersion: elasticache.aws.crossplane.io/v1alpha1
      kind: CacheSubnetGroup
      spec:
        forProvider:
          description: Redis subnet group
          subnetIdSelector:
            matchLabels:
              type: private
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: metadata.name
      toFieldPath: metadata.name
      transforms:
      - type: string
        string:
          fmt: "%s-subnet-group"
    - type: FromCompositeFieldPath
      fromFieldPath: spec.region
      toFieldPath: spec.forProvider.region

  # ElastiCache Replication Group
  - name: replication-group
    base:
      apiVersion: elasticache.aws.crossplane.io/v1beta1
      kind: ReplicationGroup
      spec:
        forProvider:
          atRestEncryptionEnabled: true
          transitEncryptionEnabled: true
          automaticFailoverEnabled: false
          engine: redis
          cacheSubnetGroupNameSelector:
            matchControllerRef: true
    patches:
    # Map size to instance class
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.size
      toFieldPath: spec.forProvider.cacheNodeType
      transforms:
      - type: map
        map:
          small: cache.t3.micro
          medium: cache.t3.small
          large: cache.r6g.large

    # Map size to number of nodes
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.size
      toFieldPath: spec.forProvider.numCacheClusters
      transforms:
      - type: map
        map:
          small: 1
          medium: 2
          large: 3

    # Set Redis version
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.version
      toFieldPath: spec.forProvider.engineVersion

    # Enable HA if requested
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.highAvailability
      toFieldPath: spec.forProvider.automaticFailoverEnabled

    # Environment-based settings
    - type: FromCompositeFieldPath
      fromFieldPath: spec.environment
      toFieldPath: spec.forProvider.snapshotRetentionLimit
      transforms:
      - type: map
        map:
          dev: 1
          staging: 3
          prod: 7

    # Status patches - send info back to user
    - type: ToCompositeFieldPath
      fromFieldPath: status.atProvider.configurationEndpoint.address
      toFieldPath: status.endpoint
    - type: ToCompositeFieldPath
      fromFieldPath: status.atProvider.configurationEndpoint.port
      toFieldPath: status.port
    - type: ToCompositeFieldPath
      fromFieldPath: status.conditions[?(@.type=='Ready')].status
      toFieldPath: status.ready
      transforms:
      - type: map
        map:
          "True": true
          "False": false

  # Connection Secret
  - name: connection-secret
    base:
      apiVersion: v1
      kind: Secret
      metadata:
        namespace: default
      data: {}
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: metadata.name
      toFieldPath: metadata.name
      transforms:
      - type: string
        string:
          fmt: "%s-connection"
    - type: FromCompositeFieldPath
      fromFieldPath: status.endpoint
      toFieldPath: data.endpoint
      transforms:
      - type: string
        string:
          type: Convert
          convert: ToBase64
    - type: FromCompositeFieldPath
      fromFieldPath: status.port
      toFieldPath: data.port
      transforms:
      - type: string
        string:
          type: Convert
          convert: ToBase64
```

**Step 3: Create Example Claims**

Create `environments/dev/redis-claim.yaml`:

```yaml
# ABOUTME: Example Redis claim for development environment
# ABOUTME: This is what platform users will create

apiVersion: platform.example.io/v1alpha1
kind: Redis
metadata:
  name: app-cache
  namespace: dev
spec:
  parameters:
    size: small
    version: "7.0"
    highAvailability: false
  environment: dev
  region: us-east-1
```

**Step 4: Test the Composition**

```bash
# 1. Apply the XRD
kubectl apply -f crossplane/xrds/xrd-redis.yaml

# 2. Verify XRD is established
kubectl get xrd xredis.platform.example.io
kubectl describe xrd xredis.platform.example.io

# 3. Apply the composition
kubectl apply -f crossplane/compositions/composition-redis-aws.yaml

# 4. Verify composition
kubectl get composition redis-aws
kubectl describe composition redis-aws

# 5. Create a test claim
kubectl apply -f environments/dev/redis-claim.yaml

# 6. Watch the provisioning
kubectl get redis -n dev
kubectl describe redis app-cache -n dev

# 7. Check composite resource
kubectl get composite

# 8. Check managed resources (actual AWS resources)
kubectl get managed

# 9. Verify connection secret created
kubectl get secret app-cache-connection -n dev
kubectl get secret app-cache-connection -n dev -o yaml

# 10. Check Crossplane logs if issues
kubectl logs -n crossplane-system -l app=crossplane --tail=50

# 11. Cleanup when done
kubectl delete redis app-cache -n dev
```

**Step 5: Add Documentation**

Update `docs/API_REFERENCE.md` to include the new Redis resource:

```markdown
### Redis

Managed Redis cache instances with automatic clustering and failover.

**API Group**: `platform.example.io/v1alpha1`
**Kind**: `Redis`

#### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| size | string | Yes | - | Instance size: small, medium, large |
| version | string | No | "7.0" | Redis version |
| highAvailability | boolean | No | false | Enable clustering and failover |

[... rest of documentation]
```

**Step 6: Add to ArgoCD**

Update `argocd/applicationsets/platform-resources.yaml` to include Redis compositions:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-resources
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - resource: postgresql
      - resource: redis  # Add this
  template:
    metadata:
      name: 'platform-{{resource}}'
    spec:
      project: platform
      source:
        repoURL: https://github.com/your-org/backend-first-idp
        targetRevision: main
        path: 'crossplane/compositions'
      destination:
        server: https://kubernetes.default.svc
```

### Kyverno Policies

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: descriptive-policy-name
  annotations:
    policies.kyverno.io/title: Human Readable Title
    policies.kyverno.io/category: Security|Compliance|Cost
    policies.kyverno.io/severity: low|medium|high|critical
    policies.kyverno.io/description: >-
      Detailed description of what this policy does and why.
```

**Guidelines:**
- Use clear policy names
- Always add annotations
- Set appropriate severity
- Test policies before committing

#### Step-by-Step: Adding a New Kyverno Policy

This guide walks through creating a cost control policy.

**Step 1: Define the Policy Problem**

Let's create a policy that prevents expensive database instances in dev environments.

**Problem**: Developers accidentally request "xlarge" databases in dev, causing unnecessary costs.

**Solution**: Block any PostgreSQL claim in dev/staging with size > "medium".

**Step 2: Write the Policy**

Create `kyverno/policies/cost-control/block-expensive-dev-databases.yaml`:

```yaml
# ABOUTME: Prevents expensive database instances in non-production environments
# ABOUTME: Enforces cost controls by blocking large instance sizes in dev/staging

apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: block-expensive-dev-databases
  annotations:
    policies.kyverno.io/title: Block Expensive Dev Databases
    policies.kyverno.io/category: Cost
    policies.kyverno.io/severity: medium
    policies.kyverno.io/subject: PostgreSQL, Redis
    policies.kyverno.io/description: >-
      Prevents creation of large or xlarge database instances in dev and staging
      environments to control costs. Production environments are exempt.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: check-postgres-size-in-nonprod
    match:
      any:
      - resources:
          kinds:
          - PostgreSQL
          namespaces:
          - dev
          - staging
    validate:
      message: >-
        Large and xlarge database instances are not allowed in dev/staging.
        Allowed sizes: small, medium.
        For larger instances, use production environment or request approval.
      pattern:
        spec:
          parameters:
            size: "small | medium"

  - name: check-redis-size-in-nonprod
    match:
      any:
      - resources:
          kinds:
          - Redis
          namespaces:
          - dev
          - staging
    validate:
      message: >-
        Large Redis instances are not allowed in dev/staging.
        Allowed sizes: small, medium.
      pattern:
        spec:
          parameters:
            size: "small | medium"
```

**Step 3: Add Policy Tests**

Create `kyverno/policies/cost-control/test-block-expensive-dev-databases.yaml`:

```yaml
# ABOUTME: Test cases for expensive dev database blocking policy
# ABOUTME: Validates that policy correctly allows/blocks based on environment and size

apiVersion: cli.kyverno.io/v1alpha1
kind: Test
metadata:
  name: block-expensive-dev-databases-tests
policies:
  - block-expensive-dev-databases.yaml
resources:
  - resources.yaml
results:
- policy: block-expensive-dev-databases
  rule: check-postgres-size-in-nonprod
  resource: dev-small-postgres
  kind: PostgreSQL
  result: pass

- policy: block-expensive-dev-databases
  rule: check-postgres-size-in-nonprod
  resource: dev-large-postgres
  kind: PostgreSQL
  result: fail

- policy: block-expensive-dev-databases
  rule: check-postgres-size-in-nonprod
  resource: prod-large-postgres
  kind: PostgreSQL
  result: skip

- policy: block-expensive-dev-databases
  rule: check-redis-size-in-nonprod
  resource: staging-xlarge-redis
  kind: Redis
  result: fail
```

Create `kyverno/policies/cost-control/resources.yaml`:

```yaml
# Test resources for policy validation

---
# Should PASS - small in dev is allowed
apiVersion: platform.example.io/v1alpha1
kind: PostgreSQL
metadata:
  name: dev-small-postgres
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 20

---
# Should FAIL - large in dev is blocked
apiVersion: platform.example.io/v1alpha1
kind: PostgreSQL
metadata:
  name: dev-large-postgres
  namespace: dev
spec:
  parameters:
    size: large
    storageGB: 100

---
# Should SKIP - policy doesn't apply to prod
apiVersion: platform.example.io/v1alpha1
kind: PostgreSQL
metadata:
  name: prod-large-postgres
  namespace: prod
spec:
  parameters:
    size: large
    storageGB: 500

---
# Should FAIL - xlarge Redis in staging
apiVersion: platform.example.io/v1alpha1
kind: Redis
metadata:
  name: staging-xlarge-redis
  namespace: staging
spec:
  parameters:
    size: xlarge
```

**Step 4: Test the Policy Locally**

```bash
# 1. Test with Kyverno CLI (dry-run, no cluster needed)
kyverno test kyverno/policies/cost-control/

# Expected output:
# Executing test-block-expensive-dev-databases.yaml...
#
# Test Summary: 4 tests passed and 0 tests failed
#
# Test passed: dev-small-postgres passes check-postgres-size-in-nonprod
# Test passed: dev-large-postgres fails check-postgres-size-in-nonprod
# Test passed: prod-large-postgres skips check-postgres-size-in-nonprod
# Test passed: staging-xlarge-redis fails check-redis-size-in-nonprod

# 2. Apply policy to cluster
kubectl apply -f kyverno/policies/cost-control/block-expensive-dev-databases.yaml

# 3. Verify policy is active
kubectl get clusterpolicy block-expensive-dev-databases
kubectl describe clusterpolicy block-expensive-dev-databases

# 4. Test with actual resources
# This should succeed
kubectl apply -f - <<EOF
apiVersion: platform.example.io/v1alpha1
kind: PostgreSQL
metadata:
  name: test-small-db
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 20
EOF

# This should fail with policy violation
kubectl apply -f - <<EOF
apiVersion: platform.example.io/v1alpha1
kind: PostgreSQL
metadata:
  name: test-large-db
  namespace: dev
spec:
  parameters:
    size: large
    storageGB: 100
EOF
# Error from server: admission webhook denied the request:
# Large and xlarge database instances are not allowed in dev/staging.

# 5. Check policy reports
kubectl get policyreports -A
kubectl describe policyreport -n dev

# 6. Cleanup
kubectl delete postgresql test-small-db -n dev
kubectl delete clusterpolicy block-expensive-dev-databases
```

**Step 5: Add Documentation**

Update `docs/policies/COST_CONTROLS.md`:

```markdown
## Block Expensive Dev Databases

**Policy**: `block-expensive-dev-databases`
**Category**: Cost
**Severity**: Medium
**Action**: Enforce

### What It Does

Prevents creation of large or xlarge database instances in dev and staging
environments to control costs. Production environments are exempt from this policy.

### Affected Resources

- PostgreSQL (sizes: large, xlarge)
- Redis (sizes: large, xlarge)

### Allowed Values

**Dev/Staging**:
- `small` - Allowed ✓
- `medium` - Allowed ✓
- `large` - Blocked ✗
- `xlarge` - Blocked ✗

**Production**:
- All sizes allowed (policy not applied)

### Example Error

When trying to create a large database in dev:

```
Error from server: admission webhook denied the request:
Large and xlarge database instances are not allowed in dev/staging.
Allowed sizes: small, medium.
For larger instances, use production environment or request approval.
```

### Override Process

If you need a large instance in dev/staging:

1. Open a ticket with platform team
2. Provide business justification
3. Platform team can add annotation to bypass:
   ```yaml
   annotations:
     policies.kyverno.io/exclude: "block-expensive-dev-databases"
   ```

### Testing

Run policy tests:
```bash
kyverno test kyverno/policies/cost-control/
```
```

**Step 6: Add to ArgoCD**

Policies are automatically deployed via ArgoCD applicationset:

```yaml
# argocd/applicationsets/platform-policies.yaml already includes all policies
# Just commit your new policy and it will be synced automatically
```

## Testing

### Test Structure

```
tests/
├── unit/                  # Fast, isolated tests
│   ├── cli/
│   ├── compositions/
│   └── policies/
├── integration/           # Tests requiring cluster
│   ├── argocd/
│   ├── crossplane/
│   └── kyverno/
└── e2e/                   # Full workflow tests
    ├── application_lifecycle/
    └── environment_promotion/
```

### Writing Tests

**Unit Test Example (Python):**
```python
# tests/unit/compositions/test_postgres_composition.py
import yaml
import pytest

def test_postgres_small_maps_to_micro():
    with open("crossplane/compositions/composition-postgresql-aws.yaml") as f:
        composition = yaml.safe_load(f)

    size_transform = find_transform(composition, "size")
    assert size_transform["map"]["small"] == "db.t3.micro"
```

**Integration Test Example (Bash):**
```bash
# tests/integration/test_claim_provisioning.sh
#!/bin/bash
set -e

# Create claim
kubectl apply -f environments/dev/postgresql-claim.yaml

# Wait for ready
kubectl wait --for=condition=Ready \
  postgresql/app-database -n dev \
  --timeout=600s

# Verify secret created
kubectl get secret app-database-connection -n dev

# Cleanup
kubectl delete -f environments/dev/postgresql-claim.yaml
```

### Running Tests

```bash
# Lint
make lint

# Unit tests
make test-unit

# Integration tests (requires cluster)
make test-integration

# E2E tests (requires cluster + cloud credentials)
make test-e2e

# All tests
make test-all
```

## Documentation

### When to Update Documentation

Update documentation when you:
- Add a new feature
- Change existing behavior
- Fix a bug that users might encounter
- Add new configuration options
- Change CLI commands or flags

### Documentation Structure

```
docs/
├── getting-started/
│   ├── installation.md
│   └── quick-start.md
├── user-guide/
│   ├── creating-claims.md
│   ├── using-cli.md
│   └── troubleshooting.md
├── architecture/
│   ├── overview.md
│   ├── compositions.md
│   └── policies.md
├── security/
│   ├── rbac.md
│   ├── secrets.md
│   └── compliance.md
└── reference/
    ├── api.md
    ├── cli.md
    └── policies.md
```

### Documentation Standards

- Use clear, concise language
- Include code examples
- Add screenshots where helpful
- Link to related documentation
- Update table of contents
- Test all commands before documenting

### Example Documentation Format

```markdown
# Feature Name

## Overview
Brief 1-2 sentence description.

## Prerequisites
- Requirement 1
- Requirement 2

## Quick Start
```bash
# Simplest possible example
command --flag value
```

## Detailed Usage

### Example 1: Common Use Case
Description of what this does.

```bash
command --detailed example
```

Expected output:
```
output here
```

### Example 2: Advanced Use Case
...

## Troubleshooting

### Issue: Common Problem
**Symptoms**: What the user sees
**Cause**: Why it happens
**Solution**: How to fix it

## Related Documentation
- [Link to related doc](path/to/doc.md)
```

## Release Process

1. **Update Version**: Update version in relevant files
2. **Update Changelog**: Add entry to CHANGELOG.md
3. **Create Tag**: `git tag v1.x.0`
4. **Push Tag**: `git push origin v1.x.0`
5. **Create Release**: GitHub release with notes
6. **Announce**: Post to discussions/slack

## Questions?

- **GitHub Discussions**: For questions and ideas
- **Slack**: #backend-first-idp (CNCF Slack)
- **Email**: platform-team@example.com

## Recognition

Contributors will be:
- Added to README contributors section
- Mentioned in release notes
- Credited in changelogs

Thank you for contributing! 🎉

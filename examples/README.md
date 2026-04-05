# Application CRD Examples

> **The Ultimate Abstraction: One Resource = Full Stack**
> Provision infrastructure + deployment + service + ingress with a single YAML file

## What is the Application CRD?

The Application CRD is the **highest level of abstraction** in the Backend-First IDP. Instead of managing individual infrastructure pieces (PostgreSQL, Redis, S3) and manually wiring them to deployments, you declare your application's needs in one place and the platform handles everything.

### The Evolution

**Phase 4: Crossplane Compositions**
```yaml
# 3 separate files:
# 1. postgres-claim.yaml
# 2. redis-claim.yaml
# 3. deployment.yaml (with manual secret wiring)
```

**Phase 6: CLI**
```bash
# 3 separate commands:
platform create postgres my-db --env=dev
platform create redis my-cache --env=dev
kubectl apply -f deployment.yaml  # Still manual
```

**Phase 8: Application CRD** ⭐
```yaml
# 1 file, everything automated:
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: my-app
spec:
  dependencies:
    database: {enabled: true, size: small}
    cache: {enabled: true, size: small}
  deployment:
    image: my-app:v1.0
    replicas: 3
# → Platform creates PostgreSQL + Redis + Deployment with auto-wired secrets!
```

## How It Works

### Architecture

```
┌─────────────────────────────────────────┐
│      Application Resource              │
│  (Developer writes ONE file)            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│    Application Composition              │
│  (Platform orchestrates)                │
├─────────────────────────────────────────┤
│ 1. Create PostgreSQL if enabled         │
│ 2. Create Redis if enabled              │
│ 3. Create S3 if enabled                 │
│ 4. Wait for all to be Ready             │
│ 5. Create Deployment with auto-wired    │
│    connection secrets                   │
│ 6. Create Service                       │
│ 7. Create Ingress (optional)            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│    Full Application Stack               │
│  • Infrastructure (RDS, ElastiCache, S3)│
│  • Kubernetes Resources (Deploy, Svc)   │
│  • Auto-wired connection secrets        │
│  • Ready to serve traffic               │
└─────────────────────────────────────────┘
```

### What Gets Created

When you apply an Application resource, the platform automatically:

1. **Provisions Infrastructure** (based on dependencies.*.enabled):
   - PostgreSQL database with connection secret
   - Redis cache with connection secret
   - S3 bucket with connection secret

2. **Creates Deployment** with:
   - Auto-wired environment variables from connection secrets:
     - `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
     - `REDIS_HOST`, `REDIS_PORT`, `REDIS_AUTH_TOKEN`
     - `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`
   - Custom environment variables from `spec.env`
   - Health checks
   - Resource limits
   - Auto-scaling (if enabled)

3. **Creates Service**:
   - ClusterIP / LoadBalancer / NodePort
   - Routes to your application pods

4. **Creates Ingress** (if enabled):
   - Public hostname
   - TLS certificate (auto-provisioned)
   - Custom annotations

## Examples

### 1. Simple API with Database

**File**: `simple-api-application.yaml`

```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: simple-api
  namespace: dev
spec:
  application:
    name: simple-api
    team: backend-team

  dependencies:
    database:
      enabled: true
      size: small

  deployment:
    image: mycompany/simple-api
    tag: v1.0.0
    replicas: 2
    port: 8080
```

**What it creates:**
- ✅ PostgreSQL small (~$15/mo)
- ✅ Deployment with 2 replicas
- ✅ Auto-wired DB connection
- ✅ ClusterIP Service

**Time**: ~8 minutes
**Cost**: ~$15/month

### 2. Full-Stack Application

**File**: `fullstack-application.yaml`

```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: fullstack-app
  namespace: staging
spec:
  application:
    name: fullstack-app
    team: platform-team

  dependencies:
    database:
      enabled: true
      size: medium
      highAvailability: true
    cache:
      enabled: true
      size: medium
      highAvailability: true
    storage:
      enabled: true
      versioning: true

  deployment:
    image: mycompany/fullstack-app
    tag: v2.1.0
    replicas: 3
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 10

  service:
    type: LoadBalancer

  ingress:
    enabled: true
    host: fullstack-staging.example.com
    tls: true
```

**What it creates:**
- ✅ PostgreSQL medium Multi-AZ (~$60/mo)
- ✅ Redis 2-node cluster (~$50/mo)
- ✅ S3 bucket with versioning (~$3/mo)
- ✅ Deployment 3-10 replicas (HPA)
- ✅ LoadBalancer Service
- ✅ Ingress with TLS

**Time**: ~10 minutes
**Cost**: ~$110-125/month

### 3. Stateless Service

**File**: `stateless-service-application.yaml`

```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: api-gateway
  namespace: production
spec:
  application:
    name: api-gateway

  dependencies:
    # All disabled (stateless)
    database: {enabled: false}
    cache: {enabled: false}
    storage: {enabled: false}

  deployment:
    image: mycompany/api-gateway
    tag: v3.5.2
    replicas: 5
    autoscaling:
      enabled: true
      maxReplicas: 50

  ingress:
    enabled: true
    host: api.example.com
    tls: true
```

**What it creates:**
- ✅ Deployment 5-50 replicas (aggressive HPA)
- ✅ LoadBalancer Service
- ✅ Public ingress with TLS
- ❌ No infrastructure (stateless)

**Time**: ~2 minutes (no infra to provision)
**Cost**: ~$15-50/month (load balancer + compute)

## Quick Start

### 1. Deploy Simple Application

```bash
# Apply the Application resource
kubectl apply -f examples/simple-api-application.yaml

# Watch provisioning
kubectl get application simple-api -n dev --watch

# Check status
kubectl describe application simple-api -n dev

# View all created resources
kubectl get all -l app=simple-api -n dev
```

### 2. Monitor Progress

```bash
# Application status
kubectl get application simple-api -n dev -o yaml

# Check infrastructure provisioning
kubectl get postgresql simple-api-db -n dev
kubectl get secret simple-api-db-connection -n dev

# Check deployment
kubectl get pods -l app=simple-api -n dev
kubectl logs -l app=simple-api -n dev
```

### 3. Access Application

```bash
# Get service URL
kubectl get service simple-api -n dev

# Port-forward for testing
kubectl port-forward svc/simple-api 8080:80 -n dev

# Test
curl http://localhost:8080/health
```

### 4. Update Application

```bash
# Edit the Application resource
kubectl edit application simple-api -n dev

# Or update from file
kubectl apply -f examples/simple-api-application.yaml

# Changes propagate automatically:
# - Deployment updates → Rolling update
# - Dependency changes → Infrastructure updates
# - Service changes → Service reconfiguration
```

### 5. Delete Application

```bash
# Delete entire stack
kubectl delete application simple-api -n dev

# This removes:
# ✓ All infrastructure (PostgreSQL, Redis, S3)
# ✓ Kubernetes Deployment
# ✓ Kubernetes Service
# ✓ Connection secrets
# ✓ Ingress (if created)

# Confirmation prompt (if deletion protection enabled)
```

## Application Spec Reference

### Core Fields

```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: my-app           # Application name
  namespace: dev         # Environment

spec:
  # Application metadata
  application:
    name: my-app         # Display name
    team: backend-team   # Owning team
    tier: standard       # Tier: free, standard, premium, enterprise

  # Infrastructure dependencies
  dependencies:
    database:
      enabled: true/false
      type: postgres|mysql
      size: small|medium|large
      storageGB: 20-1000
      highAvailability: true/false

    cache:
      enabled: true/false
      type: redis|memcached
      size: small|medium|large
      highAvailability: true/false

    storage:
      enabled: true/false
      type: s3|gcs|azure-blob
      versioning: true/false
      lifecycle: true/false

  # Deployment configuration
  deployment:
    image: registry/image    # Container image
    tag: v1.0.0             # Image tag
    replicas: 3             # Pod count
    port: 8080              # Container port

    resources:
      cpu: "100m"           # CPU request
      memory: "128Mi"       # Memory request

    healthCheck:
      enabled: true
      path: "/health"
      initialDelaySeconds: 30

    autoscaling:
      enabled: true/false
      minReplicas: 2
      maxReplicas: 10
      targetCPU: 80

    env:                    # Custom env vars
      - name: LOG_LEVEL
        value: info

  # Service configuration
  service:
    enabled: true
    type: ClusterIP|LoadBalancer|NodePort
    annotations: {}

  # Ingress configuration
  ingress:
    enabled: true/false
    host: app.example.com
    tls: true
    annotations: {}

  # Provider
  provider: aws|gcp|azure
  region: eu-west-1
```

### Auto-Wired Environment Variables

The platform automatically injects these environment variables based on enabled dependencies:

**PostgreSQL** (when `dependencies.database.enabled: true`):
```
DB_HOST=<endpoint>
DB_PORT=5432
DB_USER=<username>
DB_PASSWORD=<password>
DB_NAME=<database>
DATABASE_URL=postgresql://<user>:<pass>@<host>:<port>/<db>
```

**Redis** (when `dependencies.cache.enabled: true`):
```
REDIS_HOST=<endpoint>
REDIS_PORT=6379
REDIS_AUTH_TOKEN=<token>
REDIS_URL=redis://:<token>@<host>:<port>
```

**S3** (when `dependencies.storage.enabled: true`):
```
S3_BUCKET=<bucket-name>
S3_REGION=<region>
S3_ENDPOINT=<endpoint>
AWS_ACCESS_KEY_ID=<key>       # If using IAM user
AWS_SECRET_ACCESS_KEY=<secret> # If using IAM user
```

### Status Fields

```yaml
status:
  # Current phase
  phase: Pending|Provisioning|Ready|Failed

  # Dependency status
  dependencies:
    database:
      ready: true
      endpoint: my-app-db.abc123.eu-west-1.rds.amazonaws.com
    cache:
      ready: true
      endpoint: my-app-cache.abc123.cache.amazonaws.com
    storage:
      ready: true
      bucket: my-app-storage-abc123

  # Deployment status
  deploymentStatus:
    ready: true
    availableReplicas: 3
    desiredReplicas: 3

  # Access URLs
  access:
    serviceUrl: http://my-app.dev.svc.cluster.local
    ingressUrl: https://my-app.example.com

  # Cost estimate
  estimatedCost:
    monthly: "$110-125"
    breakdown:
      database: "$60"
      cache: "$50"
      storage: "$3"
      loadBalancer: "$15"
```

## Comparison: Before vs After

### Before Application CRD (Phases 1-7)

**Developer workflow:**
```bash
# 1. Create PostgreSQL claim
cat > db.yaml <<EOF
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
...
EOF
kubectl apply -f db.yaml

# 2. Wait for database
kubectl wait --for=condition=Ready postgresql/my-db

# 3. Create Redis claim
cat > cache.yaml <<EOF
apiVersion: platform.io/v1alpha1
kind: Redis
...
EOF
kubectl apply -f cache.yaml

# 4. Wait for cache
kubectl wait --for=condition=Ready redis/my-cache

# 5. Create deployment with manual secret wiring
cat > deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
...
env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: my-db-connection
        key: endpoint
  - name: DB_PORT
    valueFrom:
      secretKeyRef:
        name: my-db-connection
        key: port
  # ... repeat for all connection fields ...
  # ... repeat for Redis ...
EOF
kubectl apply -f deployment.yaml

# 6. Create service
kubectl apply -f service.yaml

# 7. Create ingress (optional)
kubectl apply -f ingress.yaml

# Total: 7 files, ~30 minutes of work
```

### After Application CRD (Phase 8)

**Developer workflow:**
```bash
# 1. Apply one file
kubectl apply -f my-application.yaml

# Total: 1 file, 10 seconds of work
# Platform handles everything automatically
```

**Time saved**: 99.4% reduction
**Complexity reduced**: 7 files → 1 file
**Error potential**: Manual wiring → Automatic

## Advanced Patterns

### Multi-Tier Application

```yaml
# Production tier with premium resources
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: api-prod
  namespace: production
spec:
  application:
    tier: enterprise  # Affects resource sizing

  dependencies:
    database:
      enabled: true
      size: large      # Auto-selects based on tier
      highAvailability: true
    cache:
      enabled: true
      size: large
      highAvailability: true

  deployment:
    replicas: 10
    autoscaling:
      enabled: true
      minReplicas: 10
      maxReplicas: 100   # Scale to 100 pods
```

### Blue-Green Deployments

```yaml
# Blue deployment
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: api-blue
  namespace: production
spec:
  application:
    name: api
  dependencies:
    database:
      enabled: true
      # Points to shared production database
  deployment:
    image: myapp:v1.0
    # ...

---
# Green deployment (new version)
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: api-green
  namespace: production
spec:
  application:
    name: api
  dependencies:
    database:
      enabled: true
      # Points to same shared production database
  deployment:
    image: myapp:v2.0  # New version
    # ...
```

### Development → Staging → Production

```bash
# Dev (minimal resources)
cp my-app.yaml dev/
sed -i 's/size: .*/size: small/' dev/my-app.yaml
sed -i 's/replicas: .*/replicas: 1/' dev/my-app.yaml
kubectl apply -f dev/my-app.yaml

# Staging (medium resources)
cp my-app.yaml staging/
sed -i 's/size: .*/size: medium/' staging/my-app.yaml
sed -i 's/replicas: .*/replicas: 3/' staging/my-app.yaml
sed -i 's/highAvailability: .*/highAvailability: true/' staging/my-app.yaml
kubectl apply -f staging/my-app.yaml

# Production (large resources)
cp my-app.yaml production/
sed -i 's/size: .*/size: large/' production/my-app.yaml
sed -i 's/replicas: .*/replicas: 10/' production/my-app.yaml
sed -i 's/highAvailability: .*/highAvailability: true/' production/my-app.yaml
kubectl apply -f production/my-app.yaml
```

## Troubleshooting

### Application Stuck in Provisioning

```bash
# Check Application status
kubectl describe application my-app -n dev

# Check infrastructure provisioning
kubectl get postgresql,redis,s3bucket -n dev
kubectl describe postgresql my-app-db -n dev

# Check Crossplane logs
kubectl logs -n crossplane-system -l app=crossplane

# Common issues:
# - Infrastructure claim rejected by Kyverno (check policies)
# - AWS credentials missing or invalid
# - Resource quotas exceeded
```

### Deployment Not Starting

```bash
# Check deployment status
kubectl get deployment my-app -n dev
kubectl describe deployment my-app -n dev

# Check pod errors
kubectl get pods -l app=my-app -n dev
kubectl logs -l app=my-app -n dev

# Check connection secrets
kubectl get secrets | grep connection
kubectl describe secret my-app-db-connection -n dev

# Common issues:
# - Image pull errors (check image name/tag)
# - Connection secrets not ready (wait for infrastructure)
# - Resource limits too low (check pod events)
```

### Connection Issues

```bash
# Verify connection secrets exist
kubectl get secret my-app-db-connection -n dev -o yaml

# Test database connection from pod
kubectl exec -it my-app-xxx -n dev -- sh
# Inside pod:
echo $DB_HOST
echo $DB_PORT
nc -zv $DB_HOST $DB_PORT  # Test connectivity

# Check security groups / network policies
```

## Integration with CLI

The Application CRD works great with the Platform CLI:

```bash
# Estimate costs before creating
platform cost application examples/fullstack-application.yaml
# → PostgreSQL medium Multi-AZ: ~$60/mo
# → Redis 2-node: ~$50/mo
# → S3 with lifecycle: ~$3/mo
# → Total: ~$113/month

# Validate before applying
platform validate examples/fullstack-application.yaml
# ✓ Dependencies configured correctly
# ✓ Resource limits appropriate
# ✓ Security settings compliant

# Create application
kubectl apply -f examples/fullstack-application.yaml

# Monitor status
platform status application fullstack-app --env=staging --watch

# Get connection details (shows all dependencies)
platform connect application fullstack-app --env=staging
```

## Migration Guide

### From Individual Claims

If you have existing infrastructure claims:

```bash
# Before: 3 separate claims
# - my-db.yaml (PostgreSQL)
# - my-cache.yaml (Redis)
# - my-deployment.yaml (Deployment)

# After: 1 Application resource
# Extract configuration from existing claims
grep "size:" my-db.yaml        # size: medium
grep "numNodes:" my-cache.yaml  # numNodes: 2

# Create Application manifest
cat > my-application.yaml <<EOF
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: my-app
spec:
  dependencies:
    database:
      enabled: true
      size: medium  # From my-db.yaml
    cache:
      enabled: true
      size: medium
      highAvailability: true  # From numNodes: 2
  deployment:
    # From my-deployment.yaml
    image: my-app:v1.0
    replicas: 3
EOF

# Delete old resources
kubectl delete -f my-db.yaml
kubectl delete -f my-cache.yaml
kubectl delete -f my-deployment.yaml

# Apply new Application
kubectl apply -f my-application.yaml
```

## What's Next

The Application CRD is the **ultimate abstraction** for the Backend-First IDP. Next enhancements could include:

1. **Multi-tenancy**: Namespace-level quotas and policies
2. **Cost budgets**: Auto-stop apps exceeding budget
3. **Automated testing**: Pre-deployment validation
4. **Canary deployments**: Gradual rollout automation
5. **Disaster recovery**: Auto-backup and restore
6. **Observability**: Integrated metrics and tracing

---

**Application CRD** - The fastest path from code to production. One file, full stack, automatic wiring.

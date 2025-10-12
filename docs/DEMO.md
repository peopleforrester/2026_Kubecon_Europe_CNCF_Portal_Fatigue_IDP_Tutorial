# Live Demo Script

**For Presenters**: This is a rehearsed demo script with expected outputs. Practice 3-5 times before presenting.

**Total Duration**: ~18 minutes
**Demos**: 3 progressive demonstrations
**Format**: Live coding with narration

---

## Setup (Before Demo)

**Pre-demo checklist** (10 minutes before session):

```bash
# 1. Clear terminal history
history -c && clear

# 2. Set up demo environment
export DEMO_ENV=demo
export PS1='\[\e[32m\]backend-first-idp\[\e[0m\]:\w\$ '

# 3. Verify cluster access
kubectl cluster-info
kubectl get nodes

# 4. Ensure ArgoCD is running
kubectl get pods -n argocd

# 5. Have browser tabs ready
# - ArgoCD UI (localhost:8080)
# - AWS Console (optional)
# - This script in another window
```

---

## Demo 1: GitOps Infrastructure Provisioning (10 min)

**Goal**: Show end-to-end database provisioning via Git commit

### Narration

> "Let's see how developers provision infrastructure using pure GitOps. No portals, no forms, just Git commits. I'm going to create a PostgreSQL database for our demo application."

### Step 1.1: Show Current State

```bash
# Terminal: Show what we have now
kubectl get claims -A
```

**Expected Output**:
```
No resources found
```

**Narration**:
> "We have a clean cluster. No infrastructure provisioned yet. Let's change that."

### Step 1.2: Create Database Claim

```bash
# Create claim file
cat > environments/demo/demo-db.yaml <<'EOF'
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: demo-db
  namespace: demo
spec:
  parameters:
    size: small              # t3.micro - perfect for dev
    storageGB: 20           # 20GB storage
    version: "15"           # PostgreSQL 15
    highAvailability: false # Single instance for demo
  writeConnectionSecretToRef:
    name: demo-db-connection
EOF

# Show what we created
cat environments/demo/demo-db.yaml
```

**Narration**:
> "This YAML is the developer experience. Simple, declarative, Kubernetes-native. The developer specifies what they need - a small PostgreSQL database with 20GB storage. Crossplane will handle the how."

### Step 1.3: Commit to Git

```bash
# Check git status
git status

# Stage the file
git add environments/demo/demo-db.yaml

# Commit
git commit -m "feat: Add PostgreSQL database for demo app"

# Push to trigger GitOps
git push origin main
```

**Expected Output**:
```
[main abc1234] feat: Add PostgreSQL database for demo app
 1 file changed, 15 insertions(+)
 create mode 100644 environments/demo/demo-db.yaml
Enumerating objects: 7, done.
To github.com:org/backend-first-idp.git
   def5678..abc1234  main -> main
```

**Narration**:
> "And that's it! The developer's job is done. They committed a YAML file to Git. Now watch the magic happen..."

### Step 1.4: Watch ArgoCD Sync

```bash
# Watch ArgoCD detect and sync
argocd app get platform-demo --refresh
```

**Expected Output** (within 30 seconds):
```
Name:               platform-demo
...
Sync Status:        Synced
Health Status:      Progressing
...
Resources:
  - kind: PostgreSQL
    name: demo-db
    status: Synced
```

**Narration**:
> "ArgoCD detected the Git commit within 30 seconds. It's now syncing that manifest to the cluster. Let's watch Crossplane provision the actual database..."

### Step 1.5: Watch Crossplane Provision

```bash
# Watch claim status (this will take ~5 minutes in real demo)
kubectl get postgresql demo-db -n demo --watch
```

**Expected Output Progression**:
```
# At 0:10
NAME      SYNCED   READY   COMPOSITION              AGE
demo-db   False    False   xpostgresqls.aws.platform.io   10s

# At 1:30
demo-db   True     False   xpostgresqls.aws.platform.io   90s

# At 5:00
demo-db   True     True    xpostgresqls.aws.platform.io   5m
```

**Narration** (while waiting):
> "Crossplane is now talking to AWS APIs. It's creating:
> - VPC security group
> - DB subnet group
> - RDS instance with our specifications
> - Connection secrets
>
> In production, this takes 5-10 minutes. For this demo, I've pre-provisioned one so we can see the result..."

*(Switch to pre-provisioned database for demo flow)*

### Step 1.6: Verify Connection Secret

```bash
# Show secret was created
kubectl get secret demo-db-connection -n demo

# Show secret contents (masked)
kubectl get secret demo-db-connection -n demo -o yaml | grep -A 5 "data:"
```

**Expected Output**:
```
NAME                    TYPE     DATA   AGE
demo-db-connection      Opaque   5      5m

data:
  endpoint: ZGVtby1kYi54eHh4LnVzLXdlc3QtMi5yZHMuYW1hem9uYXdzLmNvbQ==
  port: NTQzMg==
  username: cG9zdGdyZXM=
  password: <base64-encoded>
  database: ZGVtb2Ri
```

**Narration**:
> "Perfect! Crossplane created the database AND automatically created a Kubernetes secret with all the connection details. Applications can consume this immediately. Let's do exactly that in Demo 2."

---

## Demo 2: Full Application Deployment (5 min)

**Goal**: Deploy complete application with auto-wired infrastructure

### Narration

> "Now let's deploy an application. Watch how the Application CRD provisions infrastructure AND the application in one resource."

### Step 2.1: Show Application CRD

```bash
# Show the Application manifest
cat examples/simple-api-application.yaml
```

**Expected Output**:
```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: simple-api
  namespace: demo
spec:
  infrastructure:
    database:
      type: PostgreSQL
      size: small
    cache:
      type: Redis
      size: small
  application:
    image: ghcr.io/backend-first-idp/simple-api:v1.0
    port: 8080
    replicas: 2
    env:
      - name: LOG_LEVEL
        value: info
```

**Narration**:
> "This ONE resource defines everything:
> - PostgreSQL database (small)
> - Redis cache (small)
> - The application deployment
> - Auto-wiring of connection secrets
>
> No scripts, no Helm complexity, no portal clicks. Just declarative YAML."

### Step 2.2: Apply Application

```bash
# Apply the Application CRD
kubectl apply -f examples/simple-api-application.yaml

# Watch resources being created
kubectl get all,postgresql,redis -n demo
```

**Expected Output** (within 60 seconds):
```
NAME                              READY   STATUS    RESTARTS   AGE
pod/simple-api-7d9f8b5c4d-abc12   1/1     Running   0          45s
pod/simple-api-7d9f8b5c4d-def34   1/1     Running   0          45s

NAME                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/simple-api   ClusterIP   10.100.200.50   <none>        8080/TCP   45s

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/simple-api   2/2     2            2           45s

NAME                         SYNCED   READY   AGE
postgresql.platform.io/simple-api-db   True     True    45s

NAME                    SYNCED   READY   AGE
redis.platform.io/simple-api-cache     True     True    45s
```

**Narration**:
> "In 45 seconds, we have a complete stack running! Let's verify the application can connect to its infrastructure..."

### Step 2.3: Test Application

```bash
# Port-forward to application
kubectl port-forward -n demo deployment/simple-api 8080:8080 >/dev/null 2>&1 &

# Test health endpoint
curl -s http://localhost:8080/health | jq .
```

**Expected Output**:
```json
{
  "status": "healthy",
  "database": "connected",
  "cache": "connected",
  "version": "1.0.0"
}
```

**Narration**:
> "Perfect! The application is healthy and connected to both database and cache. The secrets were auto-wired by the Application controller. Zero manual configuration."

### Step 2.4: Show Secret Wiring

```bash
# Show how secrets are wired
kubectl get deployment simple-api -n demo -o yaml | grep -A 30 "env:"
```

**Expected Output**:
```yaml
env:
- name: LOG_LEVEL
  value: info
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: simple-api-db-connection
      key: endpoint
- name: DB_PORT
  valueFrom:
    secretKeyRef:
      name: simple-api-db-connection
      key: port
- name: REDIS_HOST
  valueFrom:
    secretKeyRef:
      name: simple-api-cache-connection
      key: endpoint
```

**Narration**:
> "See how the Application controller automatically wired the connection secrets as environment variables? The developer never touched these secrets. This is infrastructure automation done right."

---

## Demo 3: Policy Enforcement (3 min)

**Goal**: Show automatic security and cost controls

### Narration

> "Let's test the platform's safety guardrails. I'm going to try something a developer shouldn't do - create a publicly accessible database in dev."

### Step 3.1: Attempt Policy Violation

```bash
# Try to create public database in dev
cat <<'EOF' | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: bad-idea-db
  namespace: demo
spec:
  parameters:
    size: small
    networkConfig:
      publiclyAccessible: true  # ← Violates security policy!
EOF
```

**Expected Output** (immediate rejection):
```
Error from server: admission webhook "validate.kyverno.svc" denied the request:

policy PostgreSQL/demo/bad-idea-db for resource violation:

postgres-security-defaults:
  block-public-access: validation error: Database cannot be publicly accessible in dev/staging. Rule block-public-access failed at path /spec/parameters/networkConfig/publiclyAccessible/
```

**Narration**:
> "Blocked! Kyverno policy enforcement prevents developers from creating public databases in dev. These policies are:
> - Enforced automatically
> - Cannot be bypassed
> - Audited in Git
>
> This is security by default, not security as an afterthought."

### Step 3.2: Show Cost Control

```bash
# Try to create xlarge database in dev
cat <<'EOF' | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: expensive-db
  namespace: demo
spec:
  parameters:
    size: xlarge  # ← Too expensive for dev!
EOF
```

**Expected Output**:
```
Error from server: admission webhook "validate.kyverno.svc" denied the request:

policy PostgreSQL/demo/expensive-db for resource violation:

cost-controls:
  dev-size-limits: validation error: Dev environment limited to small/medium sizes. xlarge requires approval. Rule dev-size-limits failed at path /spec/parameters/size/
```

**Narration**:
> "Another block! Cost controls prevent expensive resources in dev. In production, xlarge is allowed - but it requires explicit approval. This prevents the dreaded 'I accidentally left a huge database running' scenario."

### Step 3.3: Show Allowed Request

```bash
# Create properly scoped database
cat <<'EOF' | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: proper-db
  namespace: demo
spec:
  parameters:
    size: small  # ✓ Allowed in dev
    networkConfig:
      publiclyAccessible: false  # ✓ Secure by default
EOF
```

**Expected Output**:
```
postgresql.platform.io/proper-db created
```

**Narration**:
> "This one works! Small size, private access - exactly what dev should use. The platform guides developers towards best practices while preventing costly mistakes."

---

## Wrap-Up (1 min)

### Narration

> "Let's recap what we just saw:
>
> **Demo 1**: GitOps infrastructure - PostgreSQL provisioned via Git commit
> **Demo 2**: Application CRD - full stack (db + cache + app) in one resource
> **Demo 3**: Policy enforcement - automatic security and cost controls
>
> All of this using just 3 CNCF projects:
> - ArgoCD (Graduated)
> - Crossplane (Incubating)
> - Kyverno (Incubating)
>
> No portal needed. No custom UI. Just Git, YAML, and battle-tested tools.
>
> That's the backend-first approach. Build robust orchestration first. Add portals later if you actually need them.
>
> Questions?"

---

## Cleanup (After Demo)

```bash
# Clean up demo resources
kubectl delete application simple-api -n demo
kubectl delete postgresql demo-db,proper-db -n demo
kubectl delete namespace demo

# Stop port-forwarding
pkill -f "port-forward"
```

---

## Demo Tips

### Before Presenting

1. **Practice 3-5 times** - know the timing
2. **Pre-provision slow resources** - database takes 5-10 min
3. **Test on demo cluster** - avoid surprises
4. **Prepare backup slides** - in case demo fails
5. **Have error scenarios ready** - to show policy enforcement

### During Presentation

1. **Explain before typing** - narrate what you're doing
2. **Pause after outputs** - let audience absorb
3. **Highlight key parts** - use `grep`, `jq` for clarity
4. **Embrace failures** - they make policy demos more powerful
5. **Watch the clock** - stay within 18 minutes

### If Demo Breaks

**Backup Plan A**: Switch to pre-recorded screen recording
**Backup Plan B**: Use screenshots with narration
**Backup Plan C**: Show architecture diagrams and explain conceptually

**Common issues**:
- **Slow network**: Use local KIND cluster instead of cloud
- **Cloud API errors**: Have pre-provisioned resources ready
- **ArgoCD sync delay**: Manually sync with `argocd app sync`

---

## Screen Layout Recommendation

**Terminal** (70% of screen):
- Large font (18-20pt) for visibility
- Clear PS1 prompt
- Syntax highlighting for YAML

**Browser** (30% of screen, minimize when not in use):
- ArgoCD UI for visual confirmation
- AWS console for "look, real resources!"

**Backup window**:
- This script open in editor
- For quick reference during demo

---

## Expected Questions After Demo

**Q: How long does database provisioning really take?**
A: 5-10 minutes for RDS. In demo we use pre-provisioned or local testing.

**Q: What if developer needs database not in catalog?**
A: They can request new Composition via GitHub issue, or create custom XRD.

**Q: How do you handle secrets in GitOps?**
A: Secrets are never in Git. Only references. Use sealed-secrets or External Secrets Operator.

**Q: Does this work with existing infrastructure?**
A: Yes! Crossplane can import existing resources with `crossplane import`.

**Q: What's the cost difference vs managed platforms?**
A: ~10x cheaper. Backend-First IDP is OSS. Managed platforms charge per resource.

---

**Good luck with your demo! 🎬**

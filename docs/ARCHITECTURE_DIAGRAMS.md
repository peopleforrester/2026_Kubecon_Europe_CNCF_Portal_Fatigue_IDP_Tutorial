# Architecture Diagrams

Visual reference for understanding the Backend-First IDP architecture.

---

## 1. High-Level Architecture

```mermaid
graph TB
    subgraph "Developer Experience"
        DEV[Developer]
        GIT[Git Repository]
    end

    subgraph "GitOps Control Plane"
        ARGOCD[ArgoCD<br/>GitOps Engine]
        CROSSPLANE[Crossplane<br/>Infrastructure Provisioning]
    end

    subgraph "Kubernetes Cluster"
        K8S[Kubernetes API]
        KYVERNO[Kyverno<br/>Policy Engine]
    end

    subgraph "Cloud Providers"
        AWS[AWS]
        GCP[GCP]
        AZURE[Azure]
    end

    DEV -->|Git Commit| GIT
    GIT -->|Sync| ARGOCD
    ARGOCD -->|Apply| K8S
    K8S -->|Validate| KYVERNO
    K8S -->|Create Claims| CROSSPLANE
    CROSSPLANE -->|Provision| AWS
    CROSSPLANE -->|Provision| GCP
    CROSSPLANE -->|Provision| AZURE
    AWS -->|Connection Secrets| K8S
    GCP -->|Connection Secrets| K8S
    AZURE -->|Connection Secrets| K8S

    style DEV fill:#e1f5fe
    style GIT fill:#fff9c4
    style ARGOCD fill:#c8e6c9
    style CROSSPLANE fill:#f8bbd0
    style KYVERNO fill:#d1c4e9
    style K8S fill:#bbdefb
    style AWS fill:#ffe0b2
    style GCP fill:#ffe0b2
    style AZURE fill:#ffe0b2
```

**Key Components**:
- **Developer**: Writes YAML, commits to Git
- **ArgoCD**: Detects changes, syncs to cluster
- **Crossplane**: Provisions cloud infrastructure
- **Kyverno**: Enforces security and cost policies
- **Cloud Providers**: Create actual resources

---

## 2. Data Flow - PostgreSQL Provisioning

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as Git Repo
    participant ArgoCD as ArgoCD
    participant K8s as Kubernetes
    participant Kyverno as Kyverno
    participant XP as Crossplane
    participant AWS as AWS API

    Dev->>Git: 1. Commit PostgreSQL claim
    Git->>ArgoCD: 2. Webhook triggers sync
    ArgoCD->>K8s: 3. Apply claim YAML
    K8s->>Kyverno: 4. Validate against policies
    Kyverno-->>K8s: 5. Approved (or denied)
    K8s->>XP: 6. Create PostgreSQL resource
    XP->>AWS: 7. API call: Create RDS instance
    AWS-->>XP: 8. Instance provisioning...
    AWS-->>XP: 9. Instance ready!
    XP->>K8s: 10. Create connection secret
    K8s-->>Dev: 11. Secret available for apps
```

**Timeline**:
- Steps 1-6: ~30 seconds (GitOps)
- Steps 7-9: ~5-10 minutes (Cloud provisioning)
- Step 10-11: ~10 seconds (Secret creation)

---

## 3. Multi-Environment Flow

```mermaid
graph LR
    subgraph "Development"
        DEV_GIT[Git: dev/]
        DEV_ARGOCD[ArgoCD: platform-dev]
        DEV_KYVERNO[Kyverno<br/>Relaxed Policies]
        DEV_INFRA[Small Instances<br/>No Public Access]
    end

    subgraph "Staging"
        STAGE_GIT[Git: staging/]
        STAGE_ARGOCD[ArgoCD: platform-staging]
        STAGE_KYVERNO[Kyverno<br/>Stricter Policies]
        STAGE_INFRA[Medium Instances<br/>Encrypted]
    end

    subgraph "Production"
        PROD_GIT[Git: production/]
        PROD_ARGOCD[ArgoCD: platform-production]
        PROD_KYVERNO[Kyverno<br/>Strictest Policies]
        PROD_INFRA[HA Instances<br/>Multi-AZ]
    end

    DEV_GIT -->|Promote| STAGE_GIT
    STAGE_GIT -->|Promote| PROD_GIT

    DEV_ARGOCD --> DEV_KYVERNO
    DEV_KYVERNO --> DEV_INFRA

    STAGE_ARGOCD --> STAGE_KYVERNO
    STAGE_KYVERNO --> STAGE_INFRA

    PROD_ARGOCD --> PROD_KYVERNO
    PROD_KYVERNO --> PROD_INFRA

    style DEV_INFRA fill:#c8e6c9
    style STAGE_INFRA fill:#fff9c4
    style PROD_INFRA fill:#ffccbc
```

**Policy Differences**:
- **Dev**: Small sizes only, no delete protection, relaxed access
- **Staging**: Medium sizes, backup required, encrypted
- **Production**: HA required, multi-AZ, strict RBAC, audit logging

---

## 4. Application CRD Flow

```mermaid
graph TD
    APP[Application CRD] --> INFRA[Infrastructure Provisioning]
    APP --> DEPLOY[Application Deployment]

    INFRA --> DB[PostgreSQL Claim]
    INFRA --> CACHE[Redis Claim]
    INFRA --> STORAGE[S3Bucket Claim]

    DB --> DB_SECRET[DB Connection Secret]
    CACHE --> CACHE_SECRET[Cache Connection Secret]
    STORAGE --> STORAGE_SECRET[S3 Credentials Secret]

    DEPLOY --> POD[Pod Deployment]
    DB_SECRET --> POD
    CACHE_SECRET --> POD
    STORAGE_SECRET --> POD

    POD --> RUNNING[Application Running]

    style APP fill:#e1f5fe
    style INFRA fill:#f8bbd0
    style DEPLOY fill:#c8e6c9
    style RUNNING fill:#c5e1a5
```

**Magic of Application CRD**:
1. **ONE resource** defines entire stack
2. **Automatic secret wiring** - no manual env vars
3. **Dependency management** - infrastructure before app
4. **Cleanup coordination** - delete app deletes infrastructure

---

## 5. Portal-First vs Backend-First Comparison

```mermaid
gantt
    title Platform Development Timeline
    dateFormat YYYY-MM
    section Portal-First
    Portal UI Development      :p1, 2024-01, 6M
    Template Development       :p2, after p1, 3M
    Backend Integration (fragile) :p3, after p2, 3M
    Debugging & Fixes          :p4, after p3, 6M
    Production Ready           :milestone, p5, after p4, 0d
    section Backend-First
    ArgoCD Setup               :b1, 2024-01, 2w
    Crossplane Setup           :b2, after b1, 2w
    First Composition          :b3, after b2, 1w
    Production Ready           :milestone, b4, after b3, 0d
    Portal (Optional)          :b5, after b4, 2M
```

**Key Insight**: Backend-First reaches production in 1-2 months vs 12-18 months for portal-first.

---

## 6. Crossplane Composition Architecture

```mermaid
graph TB
    subgraph "Developer Interface"
        CLAIM[PostgreSQL Claim<br/>Simple Developer API]
    end

    subgraph "Platform Abstraction"
        XRD[Composite Resource Definition<br/>XPostgreSQL]
        COMP[Composition<br/>Implementation Logic]
    end

    subgraph "Cloud Resources"
        SG[Security Group]
        SUBNET[DB Subnet Group]
        RDS[RDS Instance]
        SECRET[Connection Secret]
    end

    CLAIM -->|Creates| XRD
    XRD -->|Uses| COMP
    COMP -->|Provisions| SG
    COMP -->|Provisions| SUBNET
    COMP -->|Provisions| RDS
    COMP -->|Creates| SECRET

    style CLAIM fill:#e1f5fe
    style XRD fill:#c8e6c9
    style COMP fill:#fff9c4
    style RDS fill:#ffccbc
```

**Abstraction Levels**:
1. **Claim**: What developer writes (5 lines of YAML)
2. **XRD**: Platform API definition (portable)
3. **Composition**: Cloud-specific implementation (AWS/GCP/Azure)
4. **Managed Resources**: Actual cloud resources (100+ resources created)

---

## 7. Policy Enforcement Flow

```mermaid
graph LR
    CLAIM[PostgreSQL Claim] --> ADMISSION[Admission Webhook]

    ADMISSION --> CHECK1{Public Access?}
    CHECK1 -->|Yes| DENY1[❌ Deny: Security Policy]
    CHECK1 -->|No| CHECK2{Size xlarge in dev?}

    CHECK2 -->|Yes| DENY2[❌ Deny: Cost Policy]
    CHECK2 -->|No| CHECK3{Encryption enabled?}

    CHECK3 -->|No| MUTATE[✏️ Mutate: Add encryption]
    CHECK3 -->|Yes| APPROVE

    MUTATE --> APPROVE[✅ Approve & Apply]
    APPROVE --> CROSSPLANE[Crossplane Processes]

    style DENY1 fill:#ffcdd2
    style DENY2 fill:#ffcdd2
    style APPROVE fill:#c8e6c9
    style MUTATE fill:#fff9c4
```

**Kyverno Policy Types**:
- **Validation**: Deny requests that violate rules (security, cost)
- **Mutation**: Auto-fix requests to add security defaults
- **Generation**: Auto-create supporting resources (network policies)

---

## 8. Secret Management Flow

```mermaid
sequenceDiagram
    participant XP as Crossplane
    participant AWS as AWS RDS
    participant K8s as Kubernetes
    participant App as Application Pod

    XP->>AWS: 1. Create RDS instance
    AWS-->>XP: 2. Instance details + credentials
    XP->>K8s: 3. Create Secret (encrypted at rest)
    K8s->>K8s: 4. Encrypt with AES-256
    App->>K8s: 5. Request secret (via env vars)
    K8s->>App: 6. Inject decrypted values
    App->>AWS: 7. Connect to database
```

**Security Layers**:
1. **Encryption at rest**: etcd encrypted with AES-256
2. **RBAC**: Only authorized pods access secrets
3. **Namespace isolation**: Secrets scoped to namespace
4. **Rotation**: External Secrets Operator (optional)

---

## 9. Cost Control Architecture

```mermaid
graph TB
    subgraph "Developer Request"
        REQ[Request: xlarge database]
    end

    subgraph "Policy Evaluation"
        ENV{Environment?}
    end

    subgraph "Outcomes"
        DEV_DENY[❌ Deny in dev<br/>xlarge not allowed]
        STAGE_WARN[⚠️ Warn in staging<br/>requires approval]
        PROD_APPROVE[✅ Allow in production<br/>within budget]
    end

    REQ --> ENV
    ENV -->|dev| DEV_DENY
    ENV -->|staging| STAGE_WARN
    ENV -->|production| PROD_APPROVE

    style DEV_DENY fill:#ffcdd2
    style STAGE_WARN fill:#fff9c4
    style PROD_APPROVE fill:#c8e6c9
```

**Cost Policy Rules**:
- **Dev**: small/medium only ($85-320/month limit)
- **Staging**: up to large ($640/month, requires approval)
- **Production**: any size (budget tracking, alerts)

---

## 10. Disaster Recovery Flow

```mermaid
graph LR
    subgraph "Normal Operation"
        GIT[Git: Single source of truth]
        CLUSTER1[Production Cluster]
    end

    subgraph "Disaster Scenario"
        DISASTER[💥 Cluster Failure]
    end

    subgraph "Recovery"
        CLUSTER2[New Cluster]
        ARGOCD2[ArgoCD Install]
        CROSSPLANE2[Crossplane Install]
        SYNC[Sync from Git]
        RESTORE[Infrastructure Restored]
    end

    GIT --> CLUSTER1
    CLUSTER1 -.->|Failure| DISASTER
    DISASTER --> CLUSTER2
    CLUSTER2 --> ARGOCD2
    ARGOCD2 --> CROSSPLANE2
    CROSSPLANE2 --> SYNC
    SYNC --> GIT
    SYNC --> RESTORE

    style DISASTER fill:#ffcdd2
    style RESTORE fill:#c8e6c9
```

**Recovery Steps**:
1. Provision new Kubernetes cluster (15 min)
2. Install ArgoCD + Crossplane (10 min)
3. Point ArgoCD to Git repository (2 min)
4. ArgoCD syncs all resources (5 min)
5. Crossplane recreates infrastructure (10-20 min)
**Total**: ~45-60 minutes to full recovery

---

## Diagram Export

These diagrams are written in **Mermaid**, which renders automatically on GitHub, GitLab, and many documentation platforms.

### Rendering Locally

```bash
# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Generate PNG
mmdc -i docs/ARCHITECTURE_DIAGRAMS.md -o docs/images/architecture.png

# Generate SVG
mmdc -i docs/ARCHITECTURE_DIAGRAMS.md -o docs/images/architecture.svg
```

### Tools that Render Mermaid

- **GitHub**: Automatic rendering in markdown
- **GitLab**: Automatic rendering
- **VS Code**: Install "Markdown Preview Mermaid Support" extension
- **IntelliJ/WebStorm**: Built-in support
- **Obsidian**: Built-in support
- **MkDocs**: Via mermaid2 plugin

### Online Editors

- https://mermaid.live/ - Live editor
- https://mermaid.js.org/ - Official documentation

---

## Additional Diagrams

For more specific diagrams, see:
- **Network Architecture**: `/docs/networking.md` (TODO)
- **Security Architecture**: `/docs/security-architecture.md` (TODO)
- **Scalability Patterns**: `/docs/scaling.md` (TODO)

---

**Questions about architecture?** See [FAQ.md](/docs/FAQ.md) or ask on Slack!

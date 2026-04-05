# API Reference

**Complete reference for Backend-First IDP platform APIs**

This document describes all Custom Resource Definitions (CRDs) available to developers for infrastructure provisioning.

**Version**: v1alpha1
**Last Updated**: 2026-01-15

---

## Table of Contents

1. [PostgreSQL](#postgresql)
2. [Redis](#redis)
3. [S3Bucket](#s3bucket)
4. [SQSQueue](#sqsqueue)
5. [Application](#application)
6. [Common Parameters](#common-parameters)
7. [Connection Secrets](#connection-secrets)

---

## PostgreSQL

**Provisions a managed PostgreSQL database**

Supported clouds:
- ✅ AWS (RDS PostgreSQL)
- 🔄 GCP (Cloud SQL for PostgreSQL) - Q2 2026
- 🔄 Azure (Azure Database for PostgreSQL) - Q2 2026

### Basic Example

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-database
  namespace: production
spec:
  parameters:
    size: medium
    storageGB: 100
    version: "15"
  writeConnectionSecretToRef:
    name: my-database-connection
```

### API Specification

```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: string                    # Required: Database name
  namespace: string                # Required: Namespace
  annotations:
    crossplane.io/external-name: string  # Optional: AWS RDS ID (for importing)
    description: string            # Optional: Human-readable description

spec:
  parameters:
    # Core parameters
    size: enum                     # Required: small | medium | large | xlarge
    storageGB: integer             # Required: Storage size (20-65536 GB)
    version: string                # Required: PostgreSQL version ("13" | "14" | "15" | "16")

    # High availability
    highAvailability: boolean      # Optional: Enable multi-AZ (default: false)
    readReplicas: integer          # Optional: Number of read replicas (0-5, default: 0)

    # Backup configuration
    backupRetentionDays: integer   # Optional: Backup retention (1-35 days, default: 7)
    backupWindow: string           # Optional: Backup window (default: "03:00-04:00")
    maintenanceWindow: string      # Optional: Maintenance window (default: "sun:04:00-sun:05:00")

    # Network configuration
    networkConfig:
      publiclyAccessible: boolean  # Optional: Allow public access (default: false)
      vpcId: string                # Optional: VPC ID (uses default if not specified)
      subnetIds: []string          # Optional: Subnet IDs for RDS
      allowedCIDRs: []string       # Optional: CIDR blocks for security group

    # Performance
    instanceClass: string          # Optional: Override size mapping (advanced)
    iops: integer                  # Optional: Provisioned IOPS (only for io1 storage)
    storageType: enum              # Optional: gp2 | gp3 | io1 (default: gp3)

    # Advanced
    parameterGroupFamily: string   # Optional: Parameter group (default: postgres15)
    extensions: []string           # Optional: PostgreSQL extensions to enable

  # Connection secret (required)
  writeConnectionSecretToRef:
    name: string                   # Required: Secret name
    namespace: string              # Optional: Secret namespace (defaults to claim namespace)

  # Composition selection (optional)
  compositionSelector:
    matchLabels:
      provider: string             # Optional: aws | gcp | azure (default: aws)
      environment: string          # Optional: dev | staging | production

  # Deletion policy (optional)
  deletionPolicy: enum             # Optional: Delete | Orphan (default: Delete)
```

### Size Mappings

| Size | AWS Instance Class | vCPU | Memory | Monthly Cost (approx) |
|------|-------------------|------|--------|----------------------|
| **small** | db.t3.micro | 2 | 1 GB | $85 |
| **medium** | db.t3.large | 2 | 8 GB | $320 |
| **large** | db.t3.xlarge | 4 | 16 GB | $640 |
| **xlarge** | db.m5.2xlarge | 8 | 32 GB | $1280 |

*Prices based on eu-west-1, on-demand, approximate as of Jan 2026*

### Version Support

| Version | Status | End of Life |
|---------|--------|-------------|
| **16** | ✅ Supported | Feb 2028 |
| **15** | ✅ Supported | Nov 2027 |
| **14** | ✅ Supported | Nov 2026 |
| **13** | ⚠️ End of Life Soon | Nov 2025 |
| **12** | ❌ Not Supported | Nov 2024 |

### Connection Secret

The `writeConnectionSecretToRef` creates a Kubernetes Secret with these keys:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-database-connection
  namespace: production
type: Opaque
data:
  endpoint: <base64>    # Database hostname
  port: <base64>        # Database port (5432)
  username: <base64>    # Admin username (postgres)
  password: <base64>    # Admin password (auto-generated)
  database: <base64>    # Database name (postgres)
```

**Usage in Pod**:
```yaml
env:
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: my-database-connection
      key: endpoint
- name: DB_PORT
  valueFrom:
    secretKeyRef:
      name: my-database-connection
      key: port
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: my-database-connection
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-database-connection
      key: password
```

### Examples

**Production database with HA**:
```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: customer-db
  namespace: production
spec:
  parameters:
    size: xlarge
    storageGB: 500
    version: "15"
    highAvailability: true
    readReplicas: 2
    backupRetentionDays: 30
    networkConfig:
      publiclyAccessible: false
      allowedCIDRs:
        - 10.0.0.0/8  # Private VPC only
  writeConnectionSecretToRef:
    name: customer-db-connection
```

**Development database**:
```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: dev-db
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 20
    version: "15"
    highAvailability: false
    backupRetentionDays: 1  # Minimal backups for dev
  writeConnectionSecretToRef:
    name: dev-db-connection
```

---

## Redis

**Provisions a managed Redis cache**

Supported clouds:
- ✅ AWS (ElastiCache Redis)
- 🔄 GCP (Memorystore for Redis) - Q2 2026
- 🔄 Azure (Azure Cache for Redis) - Q2 2026

### Basic Example

```yaml
apiVersion: platform.io/v1alpha1
kind: Redis
metadata:
  name: session-cache
  namespace: production
spec:
  parameters:
    size: medium
    version: "7.0"
  writeConnectionSecretToRef:
    name: session-cache-connection
```

### API Specification

```yaml
apiVersion: platform.io/v1alpha1
kind: Redis
metadata:
  name: string
  namespace: string

spec:
  parameters:
    # Core parameters
    size: enum                     # Required: small | medium | large
    version: string                # Required: Redis version ("6.2" | "7.0")

    # High availability
    clusterMode: boolean           # Optional: Enable cluster mode (default: false)
    numShards: integer             # Optional: Number of shards (cluster mode only, 1-90)
    replicasPerShard: integer      # Optional: Replicas per shard (0-5, default: 1)

    # Backup
    snapshotRetentionLimit: integer  # Optional: Snapshots to retain (0-35, default: 5)
    snapshotWindow: string         # Optional: Backup window (default: "03:00-05:00")

    # Network
    networkConfig:
      transitEncryption: boolean   # Optional: Enable TLS (default: true)
      authToken: boolean           # Optional: Require password (default: true)

  writeConnectionSecretToRef:
    name: string
```

### Size Mappings

| Size | AWS Node Type | vCPU | Memory | Monthly Cost (approx) |
|------|--------------|------|--------|----------------------|
| **small** | cache.t3.micro | 2 | 0.5 GB | $42 |
| **medium** | cache.m5.large | 2 | 6.4 GB | $226 |
| **large** | cache.m5.xlarge | 4 | 12.9 GB | $452 |

### Connection Secret

```yaml
apiVersion: v1
kind: Secret
data:
  endpoint: <base64>    # Redis endpoint
  port: <base64>        # Redis port (6379)
  password: <base64>    # Auth token (if authToken: true)
```

### Examples

**Session cache (non-persistent)**:
```yaml
apiVersion: platform.io/v1alpha1
kind: Redis
metadata:
  name: session-cache
  namespace: production
spec:
  parameters:
    size: medium
    version: "7.0"
    clusterMode: false
    replicasPerShard: 1
    snapshotRetentionLimit: 0  # No persistence needed for sessions
  writeConnectionSecretToRef:
    name: session-cache-connection
```

**Application cache (clustered)**:
```yaml
apiVersion: platform.io/v1alpha1
kind: Redis
metadata:
  name: app-cache
  namespace: production
spec:
  parameters:
    size: large
    version: "7.0"
    clusterMode: true
    numShards: 3
    replicasPerShard: 2
    snapshotRetentionLimit: 7
  writeConnectionSecretToRef:
    name: app-cache-connection
```

---

## S3Bucket

**Provisions an object storage bucket**

Supported clouds:
- ✅ AWS (S3)
- 🔄 GCP (Cloud Storage) - Q2 2026
- 🔄 Azure (Blob Storage) - Q2 2026

### Basic Example

```yaml
apiVersion: platform.io/v1alpha1
kind: S3Bucket
metadata:
  name: uploads-bucket
  namespace: production
spec:
  parameters:
    acl: private
    versioning: true
  writeConnectionSecretToRef:
    name: uploads-bucket-credentials
```

### API Specification

```yaml
apiVersion: platform.io/v1alpha1
kind: S3Bucket
metadata:
  name: string

spec:
  parameters:
    # Access control
    acl: enum                      # Required: private | public-read | public-read-write

    # Data protection
    versioning: boolean            # Optional: Enable versioning (default: false)
    encryption: boolean            # Optional: Enable encryption at rest (default: true)
    encryptionKeyId: string        # Optional: KMS key ID (uses AWS-managed if not specified)

    # Lifecycle
    lifecycleRules:
      - name: string
        enabled: boolean
        prefix: string             # Optional: Object prefix filter
        transitions:
          - days: integer
            storageClass: enum     # STANDARD_IA | GLACIER | DEEP_ARCHIVE
        expiration:
          days: integer            # Delete after N days

    # Compliance
    objectLock: boolean            # Optional: Enable object lock (WORM)

    # Website hosting
    website:
      enabled: boolean
      indexDocument: string        # Default: index.html
      errorDocument: string        # Default: error.html

    # CORS
    corsRules:
      - allowedOrigins: []string
        allowedMethods: []string   # GET | PUT | POST | DELETE | HEAD
        allowedHeaders: []string
        maxAgeSeconds: integer

  writeConnectionSecretToRef:
    name: string
```

### Connection Secret

```yaml
apiVersion: v1
kind: Secret
data:
  bucketName: <base64>       # S3 bucket name
  region: <base64>           # AWS region
  accessKeyId: <base64>      # IAM user access key
  secretAccessKey: <base64>  # IAM user secret key
  endpoint: <base64>         # S3 endpoint URL
```

### Examples

**File uploads bucket**:
```yaml
apiVersion: platform.io/v1alpha1
kind: S3Bucket
metadata:
  name: user-uploads
  namespace: production
spec:
  parameters:
    acl: private
    versioning: true
    encryption: true
    lifecycleRules:
      - name: archive-old-uploads
        enabled: true
        transitions:
          - days: 90
            storageClass: GLACIER
        expiration:
          days: 365
    corsRules:
      - allowedOrigins: ["https://app.example.com"]
        allowedMethods: ["GET", "PUT", "POST"]
        allowedHeaders: ["*"]
        maxAgeSeconds: 3600
  writeConnectionSecretToRef:
    name: user-uploads-credentials
```

**Static website hosting**:
```yaml
apiVersion: platform.io/v1alpha1
kind: S3Bucket
metadata:
  name: company-website
  namespace: production
spec:
  parameters:
    acl: public-read
    versioning: false
    website:
      enabled: true
      indexDocument: index.html
      errorDocument: 404.html
  writeConnectionSecretToRef:
    name: company-website-credentials
```

---

## SQSQueue

**Provisions a message queue**

Supported clouds:
- ✅ AWS (SQS)
- 🔄 GCP (Pub/Sub) - Q2 2026
- 🔄 Azure (Queue Storage) - Q2 2026

### Basic Example

```yaml
apiVersion: platform.io/v1alpha1
kind: SQSQueue
metadata:
  name: order-processing
  namespace: production
spec:
  parameters:
    fifo: false
    retentionPeriod: 345600  # 4 days
  writeConnectionSecretToRef:
    name: order-processing-queue-credentials
```

### API Specification

```yaml
apiVersion: platform.io/v1alpha1
kind: SQSQueue
metadata:
  name: string

spec:
  parameters:
    # Queue type
    fifo: boolean                  # Optional: FIFO queue (default: false)
    contentBasedDeduplication: boolean  # Optional: For FIFO queues (default: false)

    # Message configuration
    visibilityTimeout: integer     # Optional: Seconds (0-43200, default: 30)
    messageRetentionPeriod: integer  # Optional: Seconds (60-1209600, default: 345600)
    maxMessageSize: integer        # Optional: Bytes (1024-262144, default: 262144)
    delaySeconds: integer          # Optional: Seconds (0-900, default: 0)

    # Dead letter queue
    deadLetterQueue:
      enabled: boolean
      maxReceiveCount: integer     # Messages before moving to DLQ

    # Encryption
    encryption: boolean            # Optional: Enable encryption (default: true)
    encryptionKeyId: string        # Optional: KMS key ID

  writeConnectionSecretToRef:
    name: string
```

### Connection Secret

```yaml
apiVersion: v1
kind: Secret
data:
  queueUrl: <base64>         # SQS queue URL
  queueArn: <base64>         # SQS queue ARN
  region: <base64>           # AWS region
  accessKeyId: <base64>      # IAM user access key
  secretAccessKey: <base64>  # IAM user secret key
```

### Examples

**Standard queue**:
```yaml
apiVersion: platform.io/v1alpha1
kind: SQSQueue
metadata:
  name: email-notifications
  namespace: production
spec:
  parameters:
    fifo: false
    visibilityTimeout: 300  # 5 minutes for processing
    messageRetentionPeriod: 604800  # 7 days
    deadLetterQueue:
      enabled: true
      maxReceiveCount: 3
  writeConnectionSecretToRef:
    name: email-notifications-credentials
```

**FIFO queue (ordered)**:
```yaml
apiVersion: platform.io/v1alpha1
kind: SQSQueue
metadata:
  name: payment-processing
  namespace: production
spec:
  parameters:
    fifo: true
    contentBasedDeduplication: true
    visibilityTimeout: 600  # 10 minutes
    deadLetterQueue:
      enabled: true
      maxReceiveCount: 1  # Fail fast for payments
  writeConnectionSecretToRef:
    name: payment-processing-credentials
```

---

## Application

**Provisions complete application stack (infrastructure + deployment)**

### Basic Example

```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: api-service
  namespace: production
spec:
  infrastructure:
    database:
      type: PostgreSQL
      size: large
    cache:
      type: Redis
      size: medium
  application:
    image: company/api-service:v1.2.3
    port: 8080
    replicas: 3
```

### API Specification

```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: string

spec:
  # Infrastructure dependencies
  infrastructure:
    database:
      type: enum                   # PostgreSQL | MySQL (future)
      size: enum                   # small | medium | large
      version: string              # Optional: Database version
      highAvailability: boolean    # Optional: Enable HA (default: false)

    cache:
      type: enum                   # Redis | Memcached (future)
      size: enum                   # small | medium | large

    storage:
      type: enum                   # S3Bucket | GCSBucket (future)
      acl: enum                    # private | public-read
      versioning: boolean

    queue:
      type: enum                   # SQSQueue | PubSub (future)
      fifo: boolean

  # Application deployment
  application:
    image: string                  # Required: Docker image
    port: integer                  # Required: Container port
    replicas: integer              # Required: Number of pods

    # Resources
    resources:
      cpu: string                  # Optional: CPU request (e.g., "1", "500m")
      memory: string               # Optional: Memory request (e.g., "2Gi", "512Mi")

    # Health checks
    healthCheck:
      path: string                 # Optional: Health check path (default: /health)
      initialDelaySeconds: integer # Optional: Delay before first check (default: 30)
      periodSeconds: integer       # Optional: Check interval (default: 10)

    # Environment variables
    env:
      - name: string
        value: string

    # Auto-scaling
    autoscaling:
      enabled: boolean
      minReplicas: integer
      maxReplicas: integer
      targetCPUUtilization: integer  # Percentage

  # Monitoring
  monitoring:
    enabled: boolean               # Optional: Enable monitoring (default: true)
    alerts:
      - type: enum                 # HighCPU | HighMemory | HighLatency
        threshold: number
```

### Auto-Wiring

The Application CRD automatically wires connection secrets as environment variables:

**Database secrets → env vars**:
- `DB_HOST` ← `database-connection` secret's `endpoint`
- `DB_PORT` ← `database-connection` secret's `port`
- `DB_USER` ← `database-connection` secret's `username`
- `DB_PASSWORD` ← `database-connection` secret's `password`

**Cache secrets → env vars**:
- `REDIS_HOST` ← `cache-connection` secret's `endpoint`
- `REDIS_PORT` ← `cache-connection` secret's `port`
- `REDIS_PASSWORD` ← `cache-connection` secret's `password`

### Examples

**Microservice with database and cache**:
```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: user-service
  namespace: production
spec:
  infrastructure:
    database:
      type: PostgreSQL
      size: large
      version: "15"
      highAvailability: true
    cache:
      type: Redis
      size: medium

  application:
    image: company/user-service:v2.1.0
    port: 8080
    replicas: 5

    resources:
      cpu: "2"
      memory: "4Gi"

    healthCheck:
      path: /health
      initialDelaySeconds: 60
      periodSeconds: 10

    env:
      - name: LOG_LEVEL
        value: info
      - name: ENVIRONMENT
        value: production

    autoscaling:
      enabled: true
      minReplicas: 5
      maxReplicas: 20
      targetCPUUtilization: 70

  monitoring:
    enabled: true
    alerts:
      - type: HighCPU
        threshold: 80
      - type: HighMemory
        threshold: 85
      - type: HighLatency
        threshold: 500  # milliseconds
```

---

## Common Parameters

### Labels and Annotations

**Recommended labels**:
```yaml
metadata:
  labels:
    app.kubernetes.io/name: string          # Application name
    app.kubernetes.io/instance: string      # Unique instance name
    app.kubernetes.io/version: string       # Application version
    app.kubernetes.io/component: string     # Component type (database, cache, etc.)
    app.kubernetes.io/part-of: string       # Application group
    app.kubernetes.io/managed-by: string    # Should be "crossplane"
```

**Useful annotations**:
```yaml
metadata:
  annotations:
    description: string                     # Human-readable description
    owner: string                           # Team or person responsible
    cost-center: string                     # For billing/chargeback
    compliance.platform.io/soc2: "true"     # SOC 2 compliance requirement
    compliance.platform.io/hipaa: "true"    # HIPAA compliance requirement
```

### Resource Status

All resources expose status information:

```yaml
status:
  conditions:
    - type: Ready
      status: "True"
      reason: Available
      lastTransitionTime: "2026-01-15T10:30:00Z"
    - type: Synced
      status: "True"
      reason: ReconcileSuccess
      lastTransitionTime: "2026-01-15T10:30:00Z"

  connectionDetails:
    lastPublishedTime: "2026-01-15T10:30:00Z"
```

**Check resource status**:
```bash
kubectl get postgresql my-database -n production

# Output:
NAME           SYNCED   READY   COMPOSITION              AGE
my-database    True     True    xpostgresqls.aws.platform.io   5m
```

---

## Connection Secrets

### Secret Format

All infrastructure resources create connection secrets with consistent format:

**Secret metadata**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <claim-name>-connection
  namespace: <claim-namespace>
  labels:
    crossplane.io/claim-name: <claim-name>
    crossplane.io/claim-namespace: <claim-namespace>
type: Opaque
```

### Using Secrets in Pods

**Direct injection**:
```yaml
env:
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: my-database-connection
      key: endpoint
```

**Volume mount**:
```yaml
volumes:
- name: db-credentials
  secret:
    secretName: my-database-connection

volumeMounts:
- name: db-credentials
  mountPath: /etc/secrets/db
  readOnly: true
```

**envFrom (all keys)**:
```yaml
envFrom:
- secretRef:
    name: my-database-connection
    prefix: DB_  # All keys prefixed with DB_
```

---

## API Versions

### Current: v1alpha1

- **Status**: Alpha (subject to breaking changes)
- **Stability**: Suitable for testing and development
- **Support**: Community support via Slack/GitHub

### Upcoming: v1beta1 (Q3 2026)

- **Changes**: Backward-incompatible changes frozen
- **Migration**: Provided migration guide
- **Support**: Extended support window

### Future: v1 (Q4 2026)

- **Changes**: API stable, no breaking changes
- **Support**: Long-term support (2+ years)

---

## Deprecation Policy

When APIs are deprecated:
1. **Announcement**: 3 months before removal
2. **Warning**: Kubectl shows deprecation warning
3. **Migration guide**: Published with alternatives
4. **Removal**: After 6-month deprecation period

---

## Getting Help

**API questions?**
- 💬 Slack: #backend-first-idp on [CNCF Slack](https://slack.cncf.io)
- 📖 Examples: `/examples/` directory
- 🐛 Issues: [GitHub Issues](https://github.com/peopleforrester/2026_Kubecon_Europe_CNCF_Portal_Fatigue_IDP_Tutorial/issues)
- 📧 GitHub Issues: https://github.com/peopleforrester/2026_Kubecon_Europe_CNCF_Portal_Fatigue_IDP_Tutorial/issues

**Request new APIs**:
- Open GitHub Issue with "API Request" label
- Describe use case and requirements
- Community votes on priority

---

**Last Updated**: 2026-01-15 | **Version**: v1alpha1

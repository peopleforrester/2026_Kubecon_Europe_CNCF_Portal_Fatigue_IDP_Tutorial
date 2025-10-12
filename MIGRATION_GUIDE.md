# Migration Guide

**Migrating to Backend-First IDP from existing infrastructure tools**

This guide helps teams migrate from Terraform, CloudFormation, Pulumi, or manual processes to the Backend-First IDP approach.

**Estimated time**: 2-8 weeks depending on scale
**Risk level**: Low (phased approach with rollback)

---

## Table of Contents

1. [Migration Overview](#migration-overview)
2. [From Terraform](#from-terraform)
3. [From CloudFormation](#from-cloudformation)
4. [From Pulumi](#from-pulumi)
5. [From Manual Processes](#from-manual-processes)
6. [Hybrid Approach](#hybrid-approach)
7. [Rollback Strategy](#rollback-strategy)

---

## Migration Overview

### When to Migrate

**Good reasons to migrate**:
- ✅ Terraform state management issues
- ✅ Lack of drift detection/correction
- ✅ Need GitOps workflows
- ✅ Multi-cloud portability requirements
- ✅ Current tool causing friction
- ✅ Want Kubernetes-native approach

**Bad reasons to migrate**:
- ❌ Current tool works well (if it ain't broke...)
- ❌ Team loves Terraform (stick with what works)
- ❌ No pain points (migration has cost)

**Decision framework**:
```
Pain Level = (State Issues × 10) + (Drift Incidents × 5) + (Manual Work Hours × 2)

If Pain Level > 50: Migrate
If Pain Level 20-50: Consider migrating
If Pain Level < 20: Stay with current tool
```

### Migration Phases

**Phase 1: Setup** (Week 1-2)
- Install Backend-First IDP alongside existing tools
- Create initial Compositions
- Test with non-critical resources

**Phase 2: Pilot** (Week 3-4)
- Migrate 1-2 applications
- Validate workflows
- Train team
- Gather feedback

**Phase 3: Gradual Rollout** (Week 5-8)
- Migrate 20% of infrastructure
- Expand Compositions as needed
- Monitor for issues
- Refine processes

**Phase 4: Full Migration** (Week 9-12)
- Migrate remaining 80%
- Deprecate old tools
- Clean up legacy code
- Document new processes

---

## From Terraform

### Assessment

**Inventory your Terraform**:
```bash
# Count resources
find . -name "*.tf" -exec grep -h "^resource" {} \; | wc -l

# List resource types
find . -name "*.tf" -exec grep -h "^resource" {} \; | \
  awk '{print $2}' | sort | uniq -c | sort -rn

# Example output:
#  45 aws_db_instance
#  23 aws_elasticache_cluster
#  18 aws_s3_bucket
#  12 aws_sqs_queue
```

### Strategy Selection

**Strategy 1: Lift and Shift (Fastest)**
- Use Crossplane Terraform Provider
- Wrap existing Terraform in Crossplane
- Minimal rewrite

**Strategy 2: Replatform (Recommended)**
- Convert Terraform to Crossplane Compositions
- Use native Crossplane providers
- Better abstraction, more work

**Strategy 3: Hybrid (Pragmatic)**
- Convert common resources (DB, cache, storage)
- Keep edge cases in Terraform
- Gradual transition

### Lift and Shift Migration

**Step 1**: Install Terraform Provider
```bash
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-terraform
spec:
  package: upbound/provider-terraform:v0.8.0
EOF
```

**Step 2**: Wrap Terraform in Crossplane
```yaml
# Before (Terraform):
# main.tf
resource "aws_db_instance" "example" {
  identifier          = "my-database"
  engine              = "postgres"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  username            = "admin"
  password            = var.db_password
}

# After (Crossplane Terraform Provider):
apiVersion: tf.upbound.io/v1beta1
kind: Workspace
metadata:
  name: my-database
spec:
  forProvider:
    source: Inline
    module: |
      resource "aws_db_instance" "example" {
        identifier          = "my-database"
        engine              = "postgres"
        instance_class      = "db.t3.micro"
        allocated_storage   = 20
        username            = "admin"
        password            = var.db_password
      }
  providerConfigRef:
    name: terraform-provider
```

**Pros**: Fast migration, no rewrite
**Cons**: Doesn't leverage Crossplane abstractions

### Replatform Migration

**Step 1**: Analyze Terraform module
```hcl
# Terraform module: modules/postgres/main.tf
resource "aws_db_instance" "this" {
  identifier             = var.name
  engine                 = "postgres"
  engine_version         = var.version
  instance_class         = var.instance_class
  allocated_storage      = var.storage_gb
  storage_encrypted      = true
  publicly_accessible    = false

  # 40+ more parameters...
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }
}
```

**Step 2**: Create equivalent Crossplane Composition
```yaml
# crossplane/compositions/postgresql-aws.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgresql-aws
spec:
  compositeTypeRef:
    apiVersion: platform.io/v1alpha1
    kind: XPostgreSQL

  resources:
    # DB Subnet Group
    - name: subnet-group
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: SubnetGroup
        spec:
          forProvider:
            region: us-west-2
            subnetIds:
              - subnet-abc123
              - subnet-def456
      patches:
        - fromFieldPath: "metadata.name"
          toFieldPath: "metadata.name"

    # Security Group
    - name: security-group
      base:
        apiVersion: ec2.aws.upbound.io/v1beta1
        kind: SecurityGroup
        spec:
          forProvider:
            region: us-west-2
            vpcId: vpc-12345
            ingress:
              - fromPort: 5432
                toPort: 5432
                protocol: tcp
                cidrBlocks:
                  - 10.0.0.0/8

    # RDS Instance
    - name: rds-instance
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        spec:
          forProvider:
            region: us-west-2
            engine: postgres
            engineVersion: "15"
            instanceClass: db.t3.micro
            allocatedStorage: 20
            storageEncrypted: true
            publiclyAccessible: false
          writeConnectionSecretToRef:
            namespace: crossplane-system
      patches:
        - fromFieldPath: "metadata.name"
          toFieldPath: "metadata.name"
        - fromFieldPath: "spec.parameters.size"
          toFieldPath: "spec.forProvider.instanceClass"
          transforms:
            - type: map
              map:
                small: db.t3.micro
                medium: db.t3.large
                large: db.t3.xlarge
        - fromFieldPath: "spec.parameters.version"
          toFieldPath: "spec.forProvider.engineVersion"
        - fromFieldPath: "spec.parameters.storageGB"
          toFieldPath: "spec.forProvider.allocatedStorage"
```

**Step 3**: Create developer-facing claim
```yaml
# Before (Terraform variables):
# terraform.tfvars
name           = "my-database"
version        = "15"
instance_class = "db.t3.micro"
storage_gb     = 20
subnet_ids     = ["subnet-abc123", "subnet-def456"]
vpc_id         = "vpc-12345"

# After (Crossplane claim):
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-database
  namespace: production
spec:
  parameters:
    size: small      # Abstracted: small/medium/large
    version: "15"
    storageGB: 20
  writeConnectionSecretToRef:
    name: my-database-connection
```

**Benefit**: 50+ parameters → 3 parameters (94% simplification)

### Import Existing Resources

Don't delete and recreate! Import existing Terraform-managed resources:

```bash
# Step 1: Get Terraform resource ID
cd terraform/
terraform show | grep "aws_db_instance.example"
# Output: id = "my-database"

# Step 2: Create Crossplane claim (same name)
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-database
  namespace: production
  annotations:
    crossplane.io/external-name: my-database  # Match Terraform ID
spec:
  parameters:
    size: small
    version: "15"
    storageGB: 20
EOF

# Step 3: Crossplane adopts existing resource (no recreation)
kubectl get postgresql my-database -n production
# SYNCED=True, READY=True (within 60 seconds)

# Step 4: Verify no changes in AWS
aws rds describe-db-instances --db-instance-identifier my-database
# CreationDate unchanged (not recreated)

# Step 5: Remove from Terraform state
cd terraform/
terraform state rm aws_db_instance.example

# Step 6: Verify Terraform no longer manages it
terraform plan
# No changes (Crossplane now manages)
```

### Migration Checklist

**Pre-migration**:
- [ ] Inventory all Terraform resources
- [ ] Identify dependencies between resources
- [ ] Back up Terraform state files
- [ ] Test Crossplane in non-production
- [ ] Create rollback plan

**During migration**:
- [ ] Install Backend-First IDP
- [ ] Create Compositions for common resources
- [ ] Import existing resources (no recreation)
- [ ] Verify resources healthy in Crossplane
- [ ] Remove from Terraform state
- [ ] Test application connectivity
- [ ] Update documentation

**Post-migration**:
- [ ] Deprecate Terraform code
- [ ] Archive Terraform state (7-year retention)
- [ ] Train team on Crossplane workflows
- [ ] Update CI/CD pipelines
- [ ] Monitor for drift

---

## From CloudFormation

### Assessment

**Inventory your stacks**:
```bash
# List all CloudFormation stacks
aws cloudformation list-stacks \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
  --query 'StackSummaries[*].[StackName,TemplateDescription]' \
  --output table

# Count resources per stack
aws cloudformation describe-stack-resources \
  --stack-name my-stack \
  --query 'StackResources[*].ResourceType' | \
  jq -r '.[]' | sort | uniq -c
```

### Migration Strategy

CloudFormation is AWS-specific, so migration requires replatforming:

**Step 1**: Analyze CloudFormation template
```yaml
# Before (CloudFormation):
# database-stack.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: PostgreSQL RDS instance

Parameters:
  DatabaseName:
    Type: String
  InstanceClass:
    Type: String
    Default: db.t3.micro
  AllocatedStorage:
    Type: Number
    Default: 20

Resources:
  DBSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupName: !Sub ${DatabaseName}-subnet-group
      SubnetIds:
        - subnet-abc123
        - subnet-def456

  DBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub ${DatabaseName}-sg
      VpcId: vpc-12345
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 5432
          ToPort: 5432
          CidrIp: 10.0.0.0/8

  Database:
    Type: AWS::RDS::DBInstance
    Properties:
      DBInstanceIdentifier: !Ref DatabaseName
      Engine: postgres
      EngineVersion: '15'
      DBInstanceClass: !Ref InstanceClass
      AllocatedStorage: !Ref AllocatedStorage
      StorageEncrypted: true
      PubliclyAccessible: false
      DBSubnetGroupName: !Ref DBSubnetGroup
      VPCSecurityGroups:
        - !Ref DBSecurityGroup

Outputs:
  Endpoint:
    Value: !GetAtt Database.Endpoint.Address
  Port:
    Value: !GetAtt Database.Endpoint.Port
```

**Step 2**: Create equivalent Crossplane Composition (see Terraform section above - same structure)

**Step 3**: Import existing resources
```bash
# Get CloudFormation stack resource IDs
aws cloudformation describe-stack-resources \
  --stack-name my-database-stack \
  --query 'StackResources[?ResourceType==`AWS::RDS::DBInstance`].PhysicalResourceId' \
  --output text
# Output: my-database

# Create Crossplane claim with external-name
kubectl apply -f - <<EOF
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-database
  namespace: production
  annotations:
    crossplane.io/external-name: my-database  # Import existing
spec:
  parameters:
    size: small
    version: "15"
    storageGB: 20
EOF

# Wait for Crossplane to adopt resource
kubectl wait --for=condition=Ready postgresql/my-database -n production

# Delete CloudFormation stack (Crossplane now manages resources)
aws cloudformation delete-stack --stack-name my-database-stack
# Add: --retain-resources Database  # Don't delete RDS instance
```

### Nested Stacks

If using nested CloudFormation stacks:

```bash
# Analyze nested stack hierarchy
aws cloudformation describe-stack-resources \
  --stack-name root-stack \
  --query 'StackResources[?ResourceType==`AWS::CloudFormation::Stack`]'

# Strategy: Migrate leaf stacks first, then parent stacks
# 1. Migrate database stack (no dependencies)
# 2. Migrate cache stack (no dependencies)
# 3. Migrate application stack (depends on db + cache)
```

---

## From Pulumi

### Assessment

**Inventory Pulumi stacks**:
```bash
# List all Pulumi stacks
pulumi stack ls

# Get resource count per stack
pulumi stack --stack my-stack export | jq '.deployment.resources | length'

# List resource types
pulumi stack --stack my-stack export | \
  jq -r '.deployment.resources[].type' | sort | uniq -c
```

### Migration Strategy

Pulumi is multi-cloud, so consider hybrid approach:

**Option 1: Keep Pulumi for edge cases**
```bash
# Use Crossplane for common resources (DB, cache, storage)
# Keep Pulumi for complex orchestration
```

**Option 2: Full migration**
```bash
# Convert Pulumi code to Crossplane Compositions
# More work, but full Kubernetes-native
```

**Step 1**: Analyze Pulumi code
```typescript
// Before (Pulumi TypeScript):
import * as aws from "@pulumi/aws";

const db = new aws.rds.Instance("my-database", {
  engine: "postgres",
  engineVersion: "15",
  instanceClass: "db.t3.micro",
  allocatedStorage: 20,
  storageEncrypted: true,
  publiclyAccessible: false,
  // ... 30+ more parameters
});

export const endpoint = db.endpoint;
export const port = db.port;
```

**Step 2**: Create Crossplane equivalent (see Terraform section - same Composition)

**Step 3**: Import and migrate
```bash
# Export Pulumi state
pulumi stack export > pulumi-state.json

# Get resource IDs
jq -r '.deployment.resources[] | select(.type=="aws:rds/instance:Instance") | .id' pulumi-state.json

# Import to Crossplane (same as Terraform/CloudFormation)
# Create claim with crossplane.io/external-name annotation

# Remove from Pulumi
pulumi state delete 'urn:pulumi:prod::my-app::aws:rds/instance:Instance::my-database'
```

---

## From Manual Processes

### Common Manual Patterns

**Pattern 1: AWS Console Clicking**
- Developers create resources via web console
- No infrastructure-as-code
- No documentation
- Configuration drift

**Pattern 2: Bash Scripts**
- `aws` CLI commands in shell scripts
- Hard to maintain
- No state tracking
- Error-prone

**Pattern 3: Mix of Everything**
- Some Terraform, some CloudFormation, some manual
- Complete chaos
- Audit nightmare

### Migration Strategy

**Good news**: Starting from zero is sometimes easier!

**Step 1**: Inventory existing resources
```bash
# Discover all RDS databases
aws rds describe-db-instances \
  --query 'DBInstances[*].[DBInstanceIdentifier,Engine,DBInstanceClass]' \
  --output table

# Discover all ElastiCache clusters
aws elasticache describe-cache-clusters \
  --query 'CacheClusters[*].[CacheClusterId,Engine,CacheNodeType]' \
  --output table

# Discover all S3 buckets
aws s3 ls

# Export inventory
cat > inventory.csv <<EOF
ResourceType,Name,Owner,Environment
RDS,customer-db,team-a,production
RDS,analytics-db,team-b,production
ElastiCache,session-cache,team-a,production
S3,uploads-bucket,team-c,production
EOF
```

**Step 2**: Install Backend-First IDP
```bash
# Fresh start with proper automation
./scripts/setup.sh
```

**Step 3**: Import resources one by one
```bash
# For each resource in inventory:
# 1. Create Crossplane claim with external-name
# 2. Verify Crossplane adopted resource
# 3. Tag resource with "ManagedBy: Crossplane"
# 4. Document in Git

# Example: Import customer-db
kubectl apply -f - <<EOF
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: customer-db
  namespace: production
  annotations:
    crossplane.io/external-name: customer-db
    owner: team-a
    discovered-date: "2026-01-15"
spec:
  parameters:
    size: large
    version: "15"
    highAvailability: true
EOF

# Tag in AWS
aws rds add-tags-to-resource \
  --resource-name arn:aws:rds:us-west-2:123456789012:db:customer-db \
  --tags Key=ManagedBy,Value=Crossplane Key=GitRepo,Value=platform-iac
```

**Step 4**: Establish governance
```bash
# Deploy Kyverno policies
kubectl apply -f kyverno/policies/

# Prevent manual resource creation (detection policy)
# Policy alerts when resources lack "ManagedBy: Crossplane" tag
```

---

## Hybrid Approach

**When to use hybrid**:
- Large, complex infrastructure (1000+ resources)
- Team has deep Terraform expertise
- Migration risk is high
- Need gradual transition

**Pattern**: Crossplane for new, Terraform for legacy

```yaml
# Architecture:
┌─────────────────────────────────────┐
│  New Resources (Crossplane)         │
│  - Developer self-service            │
│  - GitOps workflows                  │
│  - Policy enforcement                │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Legacy Resources (Terraform)        │
│  - Complex existing infrastructure   │
│  - Gradual migration                 │
│  - Maintain until replaced           │
└─────────────────────────────────────┘
```

**Implementation**:
```bash
# Directory structure:
.
├── crossplane/           # New Crossplane resources
│   ├── compositions/
│   └── claims/
├── terraform/            # Legacy Terraform (deprecating)
│   ├── databases/
│   └── legacy/
└── docs/
    └── migration-plan.md  # Track migration progress
```

**Migration tracker**:
```markdown
# migration-plan.md

## Resources by Status

### Migrated to Crossplane (25%)
- [x] customer-db (PostgreSQL)
- [x] session-cache (Redis)
- [x] uploads-bucket (S3)

### In Progress (10%)
- [ ] analytics-db (PostgreSQL) - Importing...
- [ ] api-cache (Redis) - Testing...

### Legacy Terraform (65%)
- [ ] networking (complex VPC setup)
- [ ] legacy-app-db (needs refactoring)
- [ ] 50+ other resources...

## Target: 100% migrated by Q4 2026
```

---

## Rollback Strategy

**Always have a rollback plan!**

### Rollback Scenarios

**Scenario 1: Crossplane not working**
```bash
# Rollback: Keep Terraform/CloudFormation state
# Don't delete old IaC until migration proven successful

# Timeline:
# Week 1-4: Keep both Terraform + Crossplane
# Week 5-8: Remove Terraform state (but keep code)
# Week 9-12: Archive Terraform code
```

**Scenario 2: Production incident**
```bash
# Emergency rollback process:

# 1. Stop Crossplane reconciliation
kubectl scale deployment crossplane -n crossplane-system --replicas=0

# 2. Restore Terraform state
cd terraform/
terraform init -backend-config=backup/terraform.tfstate

# 3. Terraform takes over management
terraform import aws_db_instance.example my-database

# 4. Resume normal operations with Terraform
terraform plan
terraform apply
```

**Scenario 3: Resource recreation**
```bash
# If Crossplane recreates resource (data loss risk):

# 1. Immediately delete Crossplane claim
kubectl delete postgresql my-database -n production

# 2. Import back to Terraform
cd terraform/
terraform import aws_db_instance.example my-database

# 3. Investigate why recreation occurred
kubectl logs -n crossplane-system -l app=crossplane

# 4. Fix issue before retrying migration
```

### Rollback Checklist

**Before migration**:
- [ ] Back up all Terraform/CloudFormation state
- [ ] Export current resource configurations
- [ ] Test rollback process in dev
- [ ] Document rollback steps
- [ ] Set rollback decision criteria

**During migration**:
- [ ] Monitor for unexpected changes
- [ ] Verify no resources recreated
- [ ] Check application connectivity
- [ ] Watch for drift
- [ ] Keep old IaC code available

**Rollback triggers**:
- [ ] Production outage related to migration
- [ ] Data loss or corruption
- [ ] Unable to provision new resources
- [ ] Team unable to operate new system
- [ ] Cost increase >20%

---

## Migration Tools

### Import Helper Script

```bash
#!/bin/bash
# scripts/import-resource.sh

RESOURCE_TYPE=$1  # postgresql, redis, s3bucket
RESOURCE_ID=$2     # AWS resource ID
NAMESPACE=$3       # production, staging, dev

# Get resource details from cloud provider
case $RESOURCE_TYPE in
  postgresql)
    DETAILS=$(aws rds describe-db-instances --db-instance-identifier $RESOURCE_ID)
    ENGINE_VERSION=$(echo $DETAILS | jq -r '.DBInstances[0].EngineVersion')
    INSTANCE_CLASS=$(echo $DETAILS | jq -r '.DBInstances[0].DBInstanceClass')
    STORAGE=$(echo $DETAILS | jq -r '.DBInstances[0].AllocatedStorage')
    ;;
esac

# Map instance class to size
case $INSTANCE_CLASS in
  db.t3.micro)  SIZE=small ;;
  db.t3.large)  SIZE=medium ;;
  db.t3.xlarge) SIZE=large ;;
esac

# Generate Crossplane claim
cat <<EOF | kubectl apply -f -
apiVersion: platform.io/v1alpha1
kind: $(tr '[:lower:]' '[:upper:]' <<< ${RESOURCE_TYPE:0:1})${RESOURCE_TYPE:1}
metadata:
  name: $RESOURCE_ID
  namespace: $NAMESPACE
  annotations:
    crossplane.io/external-name: $RESOURCE_ID
    migration.platform.io/imported: "true"
    migration.platform.io/date: "$(date -I)"
spec:
  parameters:
    size: $SIZE
    version: "$ENGINE_VERSION"
    storageGB: $STORAGE
EOF

echo "Imported $RESOURCE_TYPE/$RESOURCE_ID to namespace $NAMESPACE"
```

**Usage**:
```bash
./scripts/import-resource.sh postgresql customer-db production
# Output: Imported postgresql/customer-db to namespace production

kubectl get postgresql customer-db -n production
# NAME          SYNCED   READY   AGE
# customer-db   True     True    30s
```

---

## Support During Migration

**Need help migrating?**

- 💬 **Slack**: #backend-first-idp on [CNCF Slack](https://slack.cncf.io)
- 📧 **Email**: migration-help@backend-first-idp.io
- 🗓️ **Office Hours**: First Tuesday, 10 AM ET
- 📖 **Docs**: [FAQ](/docs/FAQ.md), [Comparison](/COMPARISON.md)

**Professional services available**:
- Migration assessment (free)
- Hands-on migration support (paid)
- Training and workshops (paid)

---

**Last Updated**: 2026-01-15

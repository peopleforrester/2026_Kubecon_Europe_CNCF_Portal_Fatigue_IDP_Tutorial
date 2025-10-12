# Kubernetes Secrets Encryption at Rest

## Overview

This directory contains configuration and tools for enabling encryption of Kubernetes secrets at rest in etcd.

**Security Impact**: CRITICAL
**Status**: Required for production deployment

## Why Encrypt Secrets?

Without encryption at rest:
- ❌ Secrets stored as **base64-encoded** plain text in etcd
- ❌ Anyone with etcd access can read all secrets
- ❌ Backup files contain unencrypted secrets
- ❌ Non-compliant with SOC 2, HIPAA, PCI-DSS

With encryption enabled:
- ✅ Secrets encrypted with AES-CBC 256-bit encryption
- ✅ Encryption keys stored separately from data
- ✅ Backup files contain encrypted data
- ✅ Compliance-ready

## Quick Start

### 1. Generate Encryption Configuration

```bash
cd security/encryption
./setup-encryption.sh --generate-key
```

This creates:
- `encryption-config-generated.yaml` - Encryption configuration
- `.encryption-key.txt` - The encryption key (chmod 600)

**⚠️ CRITICAL**: Back up `.encryption-key.txt` to a secure location!

### 2. Apply to Cluster

```bash
./setup-encryption.sh --apply
```

Follow the instructions for your cluster type (KIND, Minikube, EKS, etc.)

### 3. Verify Encryption

```bash
./setup-encryption.sh --verify
```

### 4. Re-Encrypt Existing Secrets

After enabling encryption, re-encrypt all existing secrets:

```bash
# Re-encrypt all secrets in all namespaces
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Verify a secret is encrypted
kubectl get secret <name> -n <namespace> -o yaml
```

## Configuration Details

### Encryption Providers

The configuration uses two providers:

1. **aescbc** (Primary)
   - AES-CBC encryption with 256-bit keys
   - Industry-standard encryption algorithm
   - All new secrets encrypted with this provider

2. **identity** (Fallback)
   - No encryption (plain text)
   - Allows reading old unencrypted secrets
   - Used during migration period

### Migration Strategy

```
Phase 1: Enable encryption (aescbc + identity)
   ↓
New secrets: Encrypted
Old secrets: Still plain text (readable via identity provider)
   ↓
Phase 2: Re-encrypt all secrets
   ↓
All secrets: Encrypted
   ↓
Phase 3: Remove identity provider (optional)
```

## Cluster-Specific Instructions

### KIND (Kubernetes in Docker)

1. Create encryption directory on control plane:
```bash
docker exec kind-control-plane mkdir -p /etc/kubernetes/enc
```

2. Copy config to control plane:
```bash
docker cp encryption-config-generated.yaml kind-control-plane:/etc/kubernetes/enc/
```

3. Edit kube-apiserver manifest:
```bash
docker exec -it kind-control-plane vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

4. Add encryption configuration:
```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    - --encryption-provider-config=/etc/kubernetes/enc/encryption-config-generated.yaml
    volumeMounts:
    - name: enc
      mountPath: /etc/kubernetes/enc
      readOnly: true
  volumes:
  - name: enc
    hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
```

5. Wait for kube-apiserver to restart (30-60 seconds)

### Minikube

1. Copy config:
```bash
minikube ssh "sudo mkdir -p /etc/kubernetes/enc"
minikube cp encryption-config-generated.yaml /etc/kubernetes/enc/
```

2. Edit API server:
```bash
minikube ssh "sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml"
```

3. Add flag:
```yaml
- --encryption-provider-config=/etc/kubernetes/enc/encryption-config-generated.yaml
```

### Amazon EKS

Encryption must be enabled during cluster creation:

```bash
# Create KMS key
aws kms create-key \
  --description "EKS secrets encryption" \
  --region us-west-2

# Enable encryption on new cluster
eksctl create cluster \
  --name my-cluster \
  --region us-west-2 \
  --encryption-config resources=secrets,provider={keyArn=arn:aws:kms:...}
```

For existing clusters:
```bash
aws eks associate-encryption-config \
  --cluster-name <cluster> \
  --encryption-config '[
    {
      "resources": ["secrets"],
      "provider": {
        "keyArn": "arn:aws:kms:region:account:key/key-id"
      }
    }
  ]'
```

### Google GKE

```bash
gcloud container clusters create my-cluster \
  --region us-central1 \
  --database-encryption-key projects/PROJECT_ID/locations/REGION/keyRings/RING/cryptoKeys/KEY
```

### Azure AKS

```bash
az aks create \
  --resource-group myResourceGroup \
  --name myAKSCluster \
  --enable-encryption-at-host
```

## Verification

### Test Secret Creation

```bash
# Create test secret
kubectl create secret generic test-encryption \
  --from-literal=test=hello-world \
  -n default

# Verify it's readable
kubectl get secret test-encryption -n default -o jsonpath='{.data.test}' | base64 -d

# Clean up
kubectl delete secret test-encryption -n default
```

### Check etcd Directly

On the API server node:

```bash
# List secrets in etcd
ETCDCTL_API=3 etcdctl get /registry/secrets/default/ \
  --prefix \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# View specific secret
ETCDCTL_API=3 etcdctl get /registry/secrets/default/test-encryption \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**Expected output for encrypted secret:**
- Starts with `k8s:enc:aescbc:v1:key1:`
- Followed by binary/encrypted data
- **Does NOT** contain plain text secret values

**Output for unencrypted secret:**
- Plain YAML/JSON structure
- Secret values visible in plain text

## Key Rotation

Rotate encryption keys every 90 days for compliance:

### Step 1: Generate New Config

```bash
./setup-encryption.sh --rotate
```

This creates `encryption-config-rotated.yaml` with:
- New key (key2) as primary
- Old key (key1) for reading existing secrets

### Step 2: Apply Rotated Config

```bash
# Follow apply instructions for your cluster
./setup-encryption.sh --apply
```

### Step 3: Re-Encrypt All Secrets

```bash
# This writes all secrets back, forcing encryption with new key
kubectl get secrets --all-namespaces -o json | kubectl replace -f -
```

### Step 4: Remove Old Key (After 24 hours)

After confirming all secrets are re-encrypted:

```yaml
# Edit encryption-config-rotated.yaml
# Remove old key section:
# - aescbc:
#     keys:
#       - name: key1
#         secret: OLD_KEY
```

## Security Best Practices

### Key Management

1. **Never commit encryption keys to Git**
   ```bash
   # Already in .gitignore:
   *-key.txt
   encryption-config-generated.yaml
   encryption-config-rotated.yaml
   ```

2. **Store keys in secure location**
   - AWS Secrets Manager
   - HashiCorp Vault
   - Azure Key Vault
   - Google Secret Manager
   - Encrypted USB drive in physical safe

3. **Back up keys before rotation**
   ```bash
   # Create dated backup
   cp .encryption-key.txt .encryption-key-backup-$(date +%Y%m%d).txt
   ```

### Access Control

1. **Restrict etcd access**
   - Only API server should access etcd
   - Use TLS client certificates
   - Enable etcd authentication

2. **Protect API server node**
   - Limit SSH access
   - Use bastion hosts
   - Enable audit logging

### Monitoring

1. **Alert on encryption failures**
   ```yaml
   # Monitor kube-apiserver logs for:
   - "error decrypting secret"
   - "failed to read encryption config"
   ```

2. **Verify encryption periodically**
   ```bash
   # Monthly verification check
   ./setup-encryption.sh --verify
   ```

## Troubleshooting

### API Server Won't Start

**Symptom**: kube-apiserver crash loop after enabling encryption

**Solutions**:
1. Check encryption config syntax:
   ```bash
   cat encryption-config-generated.yaml
   ```

2. Verify file permissions:
   ```bash
   ls -la /etc/kubernetes/enc/
   ```

3. Check API server logs:
   ```bash
   kubectl logs -n kube-system kube-apiserver-<node> --previous
   ```

4. Validate base64 encoding:
   ```bash
   # Key should decode to exactly 32 bytes
   echo "YOUR_KEY" | base64 -d | wc -c
   ```

### Secrets Not Encrypted

**Symptom**: New secrets still plain text in etcd

**Solutions**:
1. Verify encryption provider config is loaded:
   ```bash
   kubectl get --raw /logs/kube-apiserver.log | grep encryption
   ```

2. Check encryption providers order (aescbc should be first)

3. Restart API server to reload config

### Cannot Read Existing Secrets

**Symptom**: "failed to decrypt" errors

**Solutions**:
1. Ensure `identity` provider is present in config
2. Add old encryption key as secondary provider
3. Verify key hasn't been corrupted

## Compliance Requirements

### SOC 2 Type II

- ✅ Encryption at rest enabled
- ✅ Encryption keys rotated every 90 days
- ✅ Access to keys restricted and logged
- ✅ Key backup and recovery procedure documented

### HIPAA

- ✅ Data encrypted at rest (§164.312(a)(2)(iv))
- ✅ Encryption keys managed separately
- ✅ Access controls on encryption keys
- ✅ Audit trail for key access

### PCI-DSS

- ✅ Strong cryptography (AES-256)
- ✅ Key rotation procedure
- ✅ Secure key storage
- ✅ Cryptographic key management (Requirement 3.5)

## References

- [Kubernetes Encryption at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
- [KMS Plugin](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/)
- [etcd Security](https://etcd.io/docs/v3.5/op-guide/security/)
- [NIST Encryption Standards](https://csrc.nist.gov/projects/cryptographic-standards-and-guidelines)

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review Kubernetes documentation
3. Check cluster-specific documentation (EKS, GKE, AKS)
4. Open issue in repository

---

**Security Note**: This encryption protects data at rest in etcd. It does NOT:
- Encrypt data in transit (use TLS for that)
- Encrypt data in memory
- Protect against compromised API server
- Protect against stolen etcd backups (if encryption keys are also stolen)

For complete security, implement defense in depth:
- TLS for all communication
- RBAC for API access
- Network policies for pod isolation
- Regular security audits
- Incident response plan

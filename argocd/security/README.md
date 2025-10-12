# ArgoCD Security Configuration

Comprehensive security hardening for ArgoCD following production best practices.

## Quick Start

```bash
cd argocd/security
./setup-argocd-security.sh all
```

## Security Issues Fixed

### 1. Default Admin Password (CRITICAL) ✅

**Issue**: Default admin password is well-known and publicly documented
**Impact**: Unauthorized access to entire GitOps platform
**Solution**: Automated password change with strong hashing

**Fix**:
```bash
./setup-argocd-security.sh change-password
```

### 2. Permissive RBAC (HIGH) ✅

**Issue**: Developers had full access to all namespaces
**Impact**: Accidental or malicious changes to production
**Solution**: Namespace-based role restrictions

**Fix**:
```bash
./setup-argocd-security.sh configure-rbac
```

### 3. No TLS Configuration (MEDIUM) ✅

**Issue**: ArgoCD server running with `--insecure` flag
**Impact**: Credentials transmitted in plain text
**Solution**: TLS configuration with cert-manager

**Fix**:
```bash
./setup-argocd-security.sh enable-tls
```

### 4. Git Credentials Exposure (HIGH) ✅

**Issue**: No guidance on secure credential management
**Impact**: Repository credentials at risk
**Solution**: SSH keys and token management documentation

**Fix**:
```bash
./setup-argocd-security.sh setup-git-creds
```

## Detailed Configuration

### Change Admin Password

The default ArgoCD admin password is stored in the cluster and can be retrieved by anyone with access. **Change it immediately**.

#### Automated Method

```bash
./setup-argocd-security.sh change-password
```

This will:
1. Generate a strong random password (or use provided)
2. Hash with bcrypt (cost 10)
3. Update `argocd-secret`
4. Display new credentials

#### Manual Method

```bash
# Generate strong password
NEW_PASSWORD=$(openssl rand -base64 20)

# Hash password
HASHED=$(htpasswd -nbBC 10 "" "$NEW_PASSWORD" | tr -d ':\n' | sed 's/$2y/$2a/')

# Update secret
kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\": {\"admin.password\": \"${HASHED}\"}}"

# Display password
echo "New password: $NEW_PASSWORD"
```

#### Login

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login
argocd login localhost:8080 --username admin --password <new-password>

# Or via UI
open https://localhost:8080
```

### Configure RBAC

Restrict permissions based on namespace and role.

#### Role Structure

| Role | Dev | Staging | Production | Delete | Description |
|------|-----|---------|------------|--------|-------------|
| `admin` | ✅ Full | ✅ Full | ✅ Full | ✅ Yes | Platform team |
| `developer` | ✅ Create/Update | ❌ No | ❌ No | ❌ No | App developers |
| `staging` | ✅ Full | ✅ Create/Update | ❌ No | ⚠️ Dev only | Release managers |
| `production` | ❌ No | ❌ No | ✅ Sync only | ❌ No | Production releases |
| `readonly` | 👁️ View | 👁️ View | 👁️ View | ❌ No | Auditors |
| `cicd` | ✅ Sync | ✅ Sync | ✅ Sync | ❌ No | CI/CD automation |

#### Apply Configuration

```bash
# Apply secure RBAC
kubectl apply -f argocd/install/rbac-config-secure.yaml

# Restart ArgoCD server to reload
kubectl rollout restart deployment argocd-server -n argocd
```

#### Assign Roles to Users

**Local Users**:
```bash
# Create account
argocd account update-password --account developer

# Add role
kubectl -n argocd patch configmap argocd-rbac-cm \
  --type merge \
  -p '{"data": {"policy.csv": "g, developer-user, role:developer"}}'
```

**SSO/OIDC Groups**:
```yaml
# In argocd-rbac-cm
policy.csv: |
  # Map SSO groups to roles
  g, myorg:developers, role:developer
  g, myorg:sre, role:admin
  g, myorg:devops, role:staging
```

### Enable TLS

**DO NOT** run ArgoCD with `--insecure` in production.

#### Option 1: cert-manager (Recommended)

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Apply secure configuration
kubectl apply -f argocd/install/argocd-server-patch-secure.yaml

# Certificate will be automatically created
```

#### Option 2: Manual Certificate

```bash
# Create certificate secret
kubectl create secret tls argocd-server-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n argocd

# Update deployment
kubectl apply -f argocd/install/argocd-server-patch-secure.yaml
```

#### Verify TLS

```bash
# Check certificate
kubectl get certificate -n argocd

# Test HTTPS
curl https://argocd.yourdomain.com/api/version
```

### Secure Git Credentials

Never store Git credentials in plain text.

#### SSH Keys (Recommended)

**Generate Key**:
```bash
ssh-keygen -t ed25519 -C "argocd@yourdomain.com" -f ~/.ssh/argocd_ed25519
```

**Add to GitHub/GitLab**:
- GitHub: Settings → Deploy keys → Add deploy key
- GitLab: Project → Settings → Repository → Deploy keys

**Create Secret**:
```bash
kubectl create secret generic repo-ssh-key \
  --from-file=sshPrivateKey=~/.ssh/argocd_ed25519 \
  -n argocd
```

**Add Repository**:
```bash
argocd repo add git@github.com:yourorg/repo.git \
  --ssh-private-key-path ~/.ssh/argocd_ed25519
```

#### HTTPS Token

**Generate Token**:
- GitHub: Settings → Developer settings → Personal access tokens → Generate new token
- GitLab: Profile → Access Tokens

**Create Secret**:
```bash
kubectl create secret generic repo-credentials \
  --from-literal=username=git \
  --from-literal=password=ghp_YOUR_TOKEN_HERE \
  -n argocd

# Label for ArgoCD
kubectl label secret repo-credentials \
  argocd.argoproj.io/secret-type=repository \
  -n argocd
```

**Add Repository**:
```bash
argocd repo add https://github.com/yourorg/repo.git \
  --username git \
  --password ghp_YOUR_TOKEN_HERE
```

#### GitHub App (Most Secure)

**Create App**:
1. GitHub → Settings → Developer settings → GitHub Apps → New GitHub App
2. Permissions: Repository contents (Read-only)
3. Install on repositories
4. Download private key

**Create Secret**:
```bash
kubectl create secret generic github-app \
  --from-file=githubAppPrivateKey=app-key.pem \
  --from-literal=githubAppID=123456 \
  --from-literal=githubAppInstallationID=789012 \
  -n argocd

kubectl label secret github-app \
  argocd.argoproj.io/secret-type=repository \
  -n argocd
```

## Verification

### Check Security Configuration

```bash
# 1. Verify admin password changed
kubectl get secret argocd-secret -n argocd \
  -o jsonpath='{.data.admin\.passwordMtime}' | base64 -d

# 2. Verify RBAC configured
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# 3. Verify TLS enabled
kubectl get deployment argocd-server -n argocd \
  -o jsonpath='{.spec.template.spec.containers[0].command}' | grep -v insecure

# 4. Verify Git credentials secured
kubectl get secrets -n argocd | grep -E 'repo|github|gitlab'
```

### Security Checklist

- [ ] Default admin password changed
- [ ] RBAC roles configured (not using default)
- [ ] `--insecure` flag removed from ArgoCD server
- [ ] TLS certificate configured
- [ ] Git credentials use SSH keys or tokens (not passwords)
- [ ] Git credentials stored in Kubernetes secrets
- [ ] SSO/OIDC configured (optional but recommended)
- [ ] Audit logging enabled
- [ ] Network policies applied (optional)

## Production Deployment

### Recommended Configuration

```bash
# 1. Install with Helm for easier management
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values argocd-values-production.yaml

# 2. Apply security configurations
kubectl apply -f argocd/install/rbac-config-secure.yaml
kubectl apply -f argocd/install/argocd-server-patch-secure.yaml

# 3. Change admin password
./setup-argocd-security.sh change-password

# 4. Configure SSO/OIDC
# See: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/
```

### Production Values (argocd-values-production.yaml)

```yaml
server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - argocd.yourdomain.com
    tls:
      - secretName: argocd-server-tls
        hosts:
          - argocd.yourdomain.com

  resources:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 500m
      memory: 256Mi

  config:
    url: https://argocd.yourdomain.com

# Enable high availability
replicaCount: 3

# Enable Redis HA
redis-ha:
  enabled: true
```

## SSO/OIDC Integration

### Okta Example

```yaml
# In argocd-cm ConfigMap
data:
  url: https://argocd.yourdomain.com
  oidc.config: |
    name: Okta
    issuer: https://yourorg.okta.com
    clientID: $oidc.okta.clientID
    clientSecret: $oidc.okta.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
```

### Google OAuth Example

```yaml
data:
  oidc.config: |
    name: Google
    issuer: https://accounts.google.com
    clientID: $oidc.google.clientID
    clientSecret: $oidc.google.clientSecret
    requestedScopes: ["openid", "profile", "email"]
```

## Troubleshooting

### Cannot Login After Password Change

```bash
# Reset admin password to initial
kubectl -n argocd delete secret argocd-initial-admin-secret
kubectl -n argocd rollout restart deployment argocd-server

# Get new password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### RBAC Changes Not Applied

```bash
# Restart server to reload RBAC
kubectl rollout restart deployment argocd-server -n argocd

# Check logs
kubectl logs -n argocd deployment/argocd-server | grep rbac
```

### TLS Certificate Issues

```bash
# Check certificate status
kubectl get certificate -n argocd
kubectl describe certificate argocd-server-tls -n argocd

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

## References

- [ArgoCD Security Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/security/)
- [ArgoCD RBAC](https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [GitHub Deploy Keys](https://docs.github.com/en/developers/overview/managing-deploy-keys)

---

**Security Note**: This configuration provides defense in depth. Combine with:
- Network policies to restrict traffic
- Pod security policies/standards
- Audit logging
- Regular security updates
- Vulnerability scanning

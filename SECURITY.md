# ABOUTME: Security policy and vulnerability reporting procedures
# ABOUTME: Defines responsible disclosure process for the Backend-First IDP tutorial

# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest (main branch) | Yes |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

### How to Report

1. **Do NOT open a public GitHub issue** for security vulnerabilities
2. Email: security@peopleforrester.dev (or use GitHub's private vulnerability reporting)
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Assessment**: Within 1 week
- **Fix/Advisory**: Dependent on severity

### Scope

This is a tutorial/demo repository for KubeCon Europe 2026. The security considerations apply to:

- **CLI input validation** — Command injection, path traversal prevention
- **Credential handling** — Secrets management, `.gitignore` coverage
- **Kubernetes manifests** — RBAC, network policies, security contexts
- **Crossplane compositions** — Encryption defaults, public access prevention
- **Kyverno policies** — Security baselines, compliance enforcement

### Security Features

This project implements defense-in-depth:

1. **Input Validation** (`bin/platform-validation.sh`)
   - DNS-1123 format enforcement
   - Path traversal blocking
   - Command injection prevention
   - Whitelist-only environment and size values

2. **Infrastructure Security** (Kyverno policies)
   - Encryption-at-rest required for all databases
   - Public access blocked by default
   - Backup retention enforced
   - Cost controls per environment

3. **GitOps Security** (ArgoCD)
   - RBAC-based access control
   - Audit logging
   - SSO/OIDC integration guidance

4. **Credential Protection**
   - Comprehensive `.gitignore` (370+ patterns)
   - Kubernetes Secrets for cloud credentials
   - Encryption key file permissions (chmod 600)

## Security Best Practices for Tutorial Attendees

When using this tutorial in your own environment:

- Change the ArgoCD admin password immediately after installation
- Use SSO/OIDC for ArgoCD authentication in production
- Rotate cloud provider credentials regularly
- Enable audit logging on all CNCF components
- Review Kyverno policy reports regularly
- Use network policies to restrict pod-to-pod traffic

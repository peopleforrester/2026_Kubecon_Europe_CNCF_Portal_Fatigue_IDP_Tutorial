#!/usr/bin/env bash
# ABOUTME: Setup script for ArgoCD security hardening
# ABOUTME: Changes default password, configures RBAC, and enables TLS

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat << EOF
${PURPLE}ArgoCD Security Setup${NC}

Usage: $0 [command]

${CYAN}Commands:${NC}
  change-password    Change ArgoCD admin password
  configure-rbac     Apply restricted RBAC configuration
  enable-tls         Configure TLS for ArgoCD server
  setup-git-creds    Setup secure Git credentials
  all                Run all security configurations

${CYAN}Examples:${NC}
  # Change admin password
  $0 change-password

  # Run all security setup
  $0 all

${YELLOW}Prerequisites:${NC}
  - kubectl with cluster access
  - ArgoCD installed in argocd namespace
  - htpasswd command (for password hashing)

EOF
}

check_prerequisites() {
    local missing=0

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}✗${NC} kubectl not found"
        ((missing++))
    else
        echo -e "${GREEN}✓${NC} kubectl found"
    fi

    # Check htpasswd
    if ! command -v htpasswd &> /dev/null; then
        echo -e "${YELLOW}⚠${NC}  htpasswd not found (install apache2-utils)"
        echo "   Install: sudo apt-get install apache2-utils  # Ubuntu/Debian"
        echo "   Install: brew install httpd  # macOS"
        ((missing++))
    else
        echo -e "${GREEN}✓${NC} htpasswd found"
    fi

    # Check cluster access
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}✗${NC} No cluster access"
        ((missing++))
    else
        echo -e "${GREEN}✓${NC} Cluster accessible"
    fi

    # Check ArgoCD namespace
    if ! kubectl get namespace argocd &> /dev/null; then
        echo -e "${YELLOW}⚠${NC}  ArgoCD namespace not found"
        echo "   Install ArgoCD first"
        ((missing++))
    else
        echo -e "${GREEN}✓${NC} ArgoCD namespace exists"
    fi

    if [[ $missing -gt 0 ]]; then
        echo ""
        echo -e "${RED}Missing $missing prerequisite(s)${NC}"
        return 1
    fi

    return 0
}

change_admin_password() {
    echo -e "${BLUE}Changing ArgoCD Admin Password${NC}"
    echo ""

    # Generate strong password
    read -p "Enter new admin password (or press Enter for random): " new_password
    echo ""

    if [[ -z "$new_password" ]]; then
        # Generate random 20-character password
        new_password=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-20)
        echo -e "${GREEN}✓${NC} Generated random password: ${CYAN}${new_password}${NC}"
        echo -e "${YELLOW}⚠${NC}  Save this password securely!"
    fi

    # Hash password
    echo -e "${BLUE}Hashing password...${NC}"
    local hashed_password=$(htpasswd -nbBC 10 "" "$new_password" | tr -d ':\n' | sed 's/$2y/$2a/')

    # Update ArgoCD secret
    kubectl -n argocd patch secret argocd-secret \
        -p "{\"stringData\": {\"admin.password\": \"${hashed_password}\", \"admin.passwordMtime\": \"$(date +%FT%T%Z)\"}}"

    echo -e "${GREEN}✓${NC} Admin password updated"
    echo ""
    echo -e "${CYAN}New Credentials:${NC}"
    echo "  Username: admin"
    echo "  Password: ${new_password}"
    echo ""
    echo -e "${YELLOW}Important:${NC} Save these credentials in a password manager"
    echo ""
    echo -e "${CYAN}To login:${NC}"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  argocd login localhost:8080"
}

configure_rbac() {
    echo -e "${BLUE}Configuring Restricted RBAC${NC}"
    echo ""

    # Apply restricted RBAC configuration
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.csv: |
    # Admin role (full access)
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, gpgkeys, *, *, allow
    g, admin, role:admin

    # Developer role (restricted to dev namespace)
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, create, dev/*, allow
    p, role:developer, applications, update, dev/*, allow
    p, role:developer, applications, sync, dev/*, allow
    p, role:developer, applications, delete, dev/*, deny
    p, role:developer, repositories, get, *, allow
    p, role:developer, projects, get, *, allow

    # Staging role (dev + staging namespaces)
    p, role:staging, applications, get, */*, allow
    p, role:staging, applications, create, dev/*, allow
    p, role:staging, applications, create, staging/*, allow
    p, role:staging, applications, update, dev/*, allow
    p, role:staging, applications, update, staging/*, allow
    p, role:staging, applications, sync, dev/*, allow
    p, role:staging, applications, sync, staging/*, allow
    p, role:staging, applications, delete, dev/*, allow
    p, role:staging, applications, delete, staging/*, deny
    p, role:staging, applications, delete, production/*, deny

    # Production role (read-only + sync)
    p, role:production, applications, get, */*, allow
    p, role:production, applications, sync, production/*, allow
    p, role:production, applications, update, production/*, deny
    p, role:production, applications, delete, production/*, deny

    # Read-only role
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, repositories, get, *, allow
    p, role:readonly, projects, get, *, allow

  policy.default: role:readonly
EOF

    echo -e "${GREEN}✓${NC} RBAC configuration applied"
    echo ""
    echo -e "${CYAN}Roles configured:${NC}"
    echo "  • admin - Full access"
    echo "  • developer - Create/update in dev (no delete)"
    echo "  • staging - Manage dev/staging (no production)"
    echo "  • production - Sync production only (no modify/delete)"
    echo "  • readonly - View only (default)"
}

enable_tls() {
    echo -e "${BLUE}Enabling TLS for ArgoCD Server${NC}"
    echo ""

    # Check if cert-manager is installed
    if ! kubectl get namespace cert-manager &> /dev/null; then
        echo -e "${YELLOW}⚠${NC}  cert-manager not found"
        echo ""
        echo "To enable TLS, install cert-manager first:"
        echo "  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml"
        echo ""
        echo "Alternative: Provide your own TLS certificate"
        return 1
    fi

    # Create self-signed certificate (for development)
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-server-tls
  namespace: argocd
spec:
  secretName: argocd-server-tls
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
    - argocd.local
    - localhost
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
EOF

    # Patch ArgoCD server to use TLS
    kubectl patch deployment argocd-server -n argocd --type='json' \
        -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/command", "value": ["argocd-server"]}]'

    echo -e "${GREEN}✓${NC} TLS enabled (self-signed certificate)"
    echo ""
    echo -e "${YELLOW}Note:${NC} For production, use a proper certificate from Let's Encrypt or your CA"
    echo ""
    echo -e "${CYAN}Production TLS setup:${NC}"
    echo "  1. Install cert-manager with ACME/Let's Encrypt"
    echo "  2. Create production Issuer"
    echo "  3. Update Certificate with production domain"
}

setup_git_credentials() {
    echo -e "${BLUE}Setting up Secure Git Credentials${NC}"
    echo ""

    echo "Git repository authentication options:"
    echo "  1. SSH key (recommended)"
    echo "  2. HTTPS token"
    echo "  3. GitHub App"
    echo ""
    read -p "Select option [1-3]: " git_auth_option

    case "$git_auth_option" in
        1)
            echo ""
            echo "SSH Key Setup:"
            echo "  1. Generate SSH key: ssh-keygen -t ed25519 -C 'argocd@yourorg.com'"
            echo "  2. Add public key to GitHub/GitLab deploy keys"
            echo "  3. Create secret:"
            echo ""
            echo "     kubectl create secret generic repo-ssh-key \\"
            echo "       --from-file=sshPrivateKey=~/.ssh/id_ed25519 \\"
            echo "       -n argocd"
            echo ""
            echo "  4. Add repository:"
            echo "     argocd repo add git@github.com:yourorg/repo.git \\"
            echo "       --ssh-private-key-path ~/.ssh/id_ed25519"
            ;;
        2)
            echo ""
            echo "HTTPS Token Setup:"
            echo "  1. Generate personal access token (GitHub/GitLab)"
            echo "  2. Create secret:"
            echo ""
            echo "     kubectl create secret generic repo-credentials \\"
            echo "       --from-literal=username=git \\"
            echo "       --from-literal=password=YOUR_TOKEN \\"
            echo "       -n argocd"
            echo ""
            echo "  3. Add repository:"
            echo "     argocd repo add https://github.com/yourorg/repo.git \\"
            echo "       --username git \\"
            echo "       --password YOUR_TOKEN"
            ;;
        3)
            echo ""
            echo "GitHub App Setup:"
            echo "  1. Create GitHub App with repo permissions"
            echo "  2. Install app on repository"
            echo "  3. Download private key"
            echo "  4. Create secret:"
            echo ""
            echo "     kubectl create secret generic github-app \\"
            echo "       --from-file=githubAppPrivateKey=app-key.pem \\"
            echo "       --from-literal=githubAppID=APP_ID \\"
            echo "       --from-literal=githubAppInstallationID=INSTALL_ID \\"
            echo "       -n argocd"
            ;;
    esac

    echo ""
    echo -e "${GREEN}✓${NC} Git credentials setup instructions provided"
}

run_all() {
    echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  ArgoCD Security Hardening - Full Setup${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
    echo ""

    # Check prerequisites
    echo -e "${BLUE}Checking prerequisites...${NC}"
    if ! check_prerequisites; then
        exit 1
    fi

    echo ""
    change_admin_password

    echo ""
    configure_rbac

    echo ""
    enable_tls || echo -e "${YELLOW}⚠${NC}  TLS setup skipped (manual configuration required)"

    echo ""
    setup_git_credentials

    echo ""
    echo -e "${GREEN}✓ ArgoCD security hardening complete!${NC}"
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    case "${1:-}" in
        change-password)
            check_prerequisites || exit 1
            change_admin_password
            ;;
        configure-rbac)
            check_prerequisites || exit 1
            configure_rbac
            ;;
        enable-tls)
            check_prerequisites || exit 1
            enable_tls
            ;;
        setup-git-creds)
            setup_git_credentials
            ;;
        all)
            run_all
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown command: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"

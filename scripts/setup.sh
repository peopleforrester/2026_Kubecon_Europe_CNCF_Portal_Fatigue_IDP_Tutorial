#!/usr/bin/env bash
# ABOUTME: Main installation script for Backend-First IDP
# ABOUTME: Installs ArgoCD, Crossplane, and configures cloud providers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
ARGOCD_VERSION="${ARGOCD_VERSION:-v2.11.0}"
CROSSPLANE_VERSION="${CROSSPLANE_VERSION:-1.16.0}"
NAMESPACE_ARGOCD="${NAMESPACE_ARGOCD:-argocd}"
NAMESPACE_CROSSPLANE="${NAMESPACE_CROSSPLANE:-crossplane-system}"

#######################################
# Helper Functions
#######################################

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}

    log_info "Waiting for pods in namespace ${namespace} to be ready (timeout: ${timeout}s)..."

    if kubectl wait --for=condition=ready pod --all \
        -n "${namespace}" \
        --timeout="${timeout}s" 2>/dev/null; then
        log_success "All pods in ${namespace} are ready"
        return 0
    else
        log_warn "Some pods in ${namespace} are not ready yet"
        return 1
    fi
}

#######################################
# Pre-flight Checks
#######################################

preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check required commands
    local required_commands=("kubectl" "helm" "git")
    for cmd in "${required_commands[@]}"; do
        if ! check_command "$cmd"; then
            log_error "Missing required command: $cmd"
            echo ""
            echo "Please install missing dependencies:"
            echo "  kubectl: https://kubernetes.io/docs/tasks/tools/"
            echo "  helm: https://helm.sh/docs/intro/install/"
            echo "  git: https://git-scm.com/downloads"
            exit 1
        fi
    done
    log_success "All required commands found"

    # Check kubectl access
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access Kubernetes cluster"
        echo ""
        echo "Please configure kubectl to access a Kubernetes cluster:"
        echo "  kubectl config get-contexts"
        exit 1
    fi
    log_success "Kubernetes cluster accessible"

    # Check kubectl version
    local client_version=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
    log_info "kubectl version: ${client_version}"

    # Check cluster version
    local server_version=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' || echo "unknown")
    log_info "Kubernetes server version: ${server_version}"

    # Check if cluster has sufficient resources
    local nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$nodes" -eq 0 ]; then
        log_error "No nodes found in cluster"
        exit 1
    fi
    log_success "Cluster has ${nodes} node(s)"

    echo ""
}

#######################################
# ArgoCD Installation
#######################################

install_argocd() {
    log_info "Installing ArgoCD ${ARGOCD_VERSION}..."

    # Create namespace
    if kubectl get namespace "${NAMESPACE_ARGOCD}" &> /dev/null; then
        log_warn "Namespace ${NAMESPACE_ARGOCD} already exists"
    else
        kubectl create namespace "${NAMESPACE_ARGOCD}"
        log_success "Created namespace ${NAMESPACE_ARGOCD}"
    fi

    # Install ArgoCD
    log_info "Applying ArgoCD manifests..."
    kubectl apply -n "${NAMESPACE_ARGOCD}" \
        -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available \
        deployment/argocd-server \
        -n "${NAMESPACE_ARGOCD}" \
        --timeout=300s

    wait_for_pods "${NAMESPACE_ARGOCD}" 300

    log_success "ArgoCD installed successfully"
    echo ""
}

get_argocd_password() {
    log_info "Retrieving ArgoCD admin password..."

    local password
    password=$(kubectl -n "${NAMESPACE_ARGOCD}" get secret argocd-initial-admin-secret \
        -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)

    if [ -n "$password" ]; then
        echo ""
        echo -e "${GREEN}ArgoCD Admin Credentials:${NC}"
        echo "  URL:      https://localhost:8080"
        echo "  Username: admin"
        echo "  Password: ${password}"
        echo ""
        echo -e "${YELLOW}To access ArgoCD UI, run:${NC}"
        echo "  kubectl port-forward svc/argocd-server -n ${NAMESPACE_ARGOCD} 8080:443"
        echo ""
    else
        log_warn "Could not retrieve ArgoCD password"
    fi
}

#######################################
# Crossplane Installation
#######################################

install_crossplane() {
    log_info "Installing Crossplane ${CROSSPLANE_VERSION}..."

    # Add Crossplane Helm repository
    if helm repo list | grep -q "crossplane-stable"; then
        log_info "Crossplane Helm repo already added"
    else
        helm repo add crossplane-stable https://charts.crossplane.io/stable
        log_success "Added Crossplane Helm repository"
    fi

    helm repo update

    # Create namespace
    if kubectl get namespace "${NAMESPACE_CROSSPLANE}" &> /dev/null; then
        log_warn "Namespace ${NAMESPACE_CROSSPLANE} already exists"
    else
        kubectl create namespace "${NAMESPACE_CROSSPLANE}"
        log_success "Created namespace ${NAMESPACE_CROSSPLANE}"
    fi

    # Install Crossplane
    log_info "Installing Crossplane via Helm..."
    helm upgrade --install crossplane crossplane-stable/crossplane \
        --namespace "${NAMESPACE_CROSSPLANE}" \
        --version "${CROSSPLANE_VERSION}" \
        --wait \
        --timeout 5m

    # Wait for Crossplane to be ready
    kubectl wait --for=condition=available \
        deployment/crossplane \
        -n "${NAMESPACE_CROSSPLANE}" \
        --timeout=300s

    wait_for_pods "${NAMESPACE_CROSSPLANE}" 300

    log_success "Crossplane installed successfully"
    echo ""
}

#######################################
# Cloud Provider Configuration
#######################################

configure_cloud_provider() {
    log_info "Cloud provider configuration"
    echo ""
    echo "Which cloud provider would you like to configure?"
    echo "  1) AWS"
    echo "  2) GCP (Coming soon)"
    echo "  3) Azure (Coming soon)"
    echo "  4) Skip for now"
    echo ""
    read -p "Enter choice [1-4]: " -r choice

    case $choice in
        1)
            configure_aws_provider
            ;;
        2)
            log_warn "GCP provider support coming in Q2 2026"
            ;;
        3)
            log_warn "Azure provider support coming in Q2 2026"
            ;;
        4)
            log_info "Skipping cloud provider configuration"
            log_info "You can configure providers later using: ${REPO_ROOT}/crossplane/providers/"
            ;;
        *)
            log_error "Invalid choice"
            ;;
    esac
    echo ""
}

configure_aws_provider() {
    log_info "Configuring AWS Provider..."

    # Check if AWS credentials are available
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        echo ""
        log_warn "AWS credentials not found in environment"
        echo ""
        echo "Please provide AWS credentials:"
        echo "  (These will be stored in a Kubernetes secret)"
        echo ""
        read -p "AWS Access Key ID: " -r aws_access_key
        read -sp "AWS Secret Access Key: " -r aws_secret_key
        echo ""
        echo ""
    else
        aws_access_key="${AWS_ACCESS_KEY_ID}"
        aws_secret_key="${AWS_SECRET_ACCESS_KEY}"
        log_info "Using AWS credentials from environment"
    fi

    # Create AWS credentials secret
    kubectl create secret generic aws-credentials \
        -n "${NAMESPACE_CROSSPLANE}" \
        --from-literal=credentials="[default]
aws_access_key_id = ${aws_access_key}
aws_secret_access_key = ${aws_secret_key}" \
        --dry-run=client -o yaml | kubectl apply -f -

    log_success "Created AWS credentials secret"

    # Install AWS provider
    log_info "Installing AWS provider..."
    kubectl apply -f "${REPO_ROOT}/crossplane/providers/provider-aws.yaml"

    # Wait for provider to be installed
    log_info "Waiting for AWS provider to be ready..."
    sleep 10
    kubectl wait --for=condition=Healthy \
        provider/provider-aws \
        --timeout=300s || log_warn "Provider health check timed out (this is normal on first install)"

    # Apply provider configuration
    kubectl apply -f "${REPO_ROOT}/crossplane/providers/aws-provider-config.yaml"

    log_success "AWS provider configured successfully"
}

#######################################
# Platform Configuration
#######################################

configure_platform_apps() {
    log_info "Configuring platform applications..."

    # Create application namespaces
    for ns in dev staging production; do
        if kubectl get namespace "${ns}" &> /dev/null; then
            log_info "Namespace ${ns} already exists"
        else
            kubectl create namespace "${ns}"
            log_success "Created namespace ${ns}"
        fi
    done

    # Apply ArgoCD applications
    if [ -f "${REPO_ROOT}/argocd/applications/platform-apps.yaml" ]; then
        log_info "Applying platform applications..."
        kubectl apply -f "${REPO_ROOT}/argocd/applications/platform-apps.yaml"
        log_success "Platform applications configured"
    else
        log_warn "Platform applications manifest not found"
    fi

    echo ""
}

#######################################
# Installation Summary
#######################################

print_summary() {
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                       ║${NC}"
    echo -e "${GREEN}║   Backend-First IDP Installation Complete! 🎉        ║${NC}"
    echo -e "${GREEN}║                                                       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${BLUE}Components Installed:${NC}"
    echo "  ✓ ArgoCD ${ARGOCD_VERSION}"
    echo "  ✓ Crossplane ${CROSSPLANE_VERSION}"
    echo "  ✓ Platform namespaces (dev, staging, production)"
    echo ""

    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "1. Access ArgoCD UI:"
    echo "   ${YELLOW}kubectl port-forward svc/argocd-server -n ${NAMESPACE_ARGOCD} 8080:443${NC}"
    echo "   Then open: https://localhost:8080"
    echo ""

    echo "2. Get ArgoCD admin password:"
    echo "   ${YELLOW}kubectl -n ${NAMESPACE_ARGOCD} get secret argocd-initial-admin-secret \\${NC}"
    echo "   ${YELLOW}  -o jsonpath='{.data.password}' | base64 -d${NC}"
    echo ""

    echo "3. Deploy your first infrastructure:"
    echo "   ${YELLOW}kubectl apply -f environments/dev/postgresql-claim.yaml${NC}"
    echo ""

    echo "4. Watch resources being provisioned:"
    echo "   ${YELLOW}kubectl get claims -A --watch${NC}"
    echo ""

    echo -e "${BLUE}Documentation:${NC}"
    echo "  • Quick Start:  ${REPO_ROOT}/docs/quickstart.md"
    echo "  • Tutorial:     ${REPO_ROOT}/TUTORIAL.md"
    echo "  • FAQ:          ${REPO_ROOT}/docs/FAQ.md"
    echo "  • API Reference: ${REPO_ROOT}/docs/API_REFERENCE.md"
    echo ""

    echo -e "${BLUE}Support:${NC}"
    echo "  • GitHub Issues: https://github.com/[ORG]/backend-first-idp/issues"
    echo "  • Slack:         #backend-first-idp on CNCF Slack"
    echo "  • Email:         support@backend-first-idp.io"
    echo ""
}

#######################################
# Main Installation Flow
#######################################

main() {
    clear
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                       ║${NC}"
    echo -e "${BLUE}║       Backend-First IDP Setup                         ║${NC}"
    echo -e "${BLUE}║       Production Infrastructure Control Plane         ║${NC}"
    echo -e "${BLUE}║                                                       ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "This script will install:"
    echo "  • ArgoCD (GitOps engine)"
    echo "  • Crossplane (Infrastructure provisioning)"
    echo "  • Platform configuration"
    echo ""
    read -p "Continue with installation? [y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    echo ""

    # Run installation steps
    preflight_checks
    install_argocd
    get_argocd_password
    install_crossplane
    configure_cloud_provider
    configure_platform_apps
    print_summary
}

# Run main function
main "$@"

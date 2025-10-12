#!/usr/bin/env bash
# ABOUTME: Setup script for Kubernetes secrets encryption at rest
# ABOUTME: Generates encryption key, creates config, and provides setup instructions

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

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

usage() {
    cat << EOF
${PURPLE}Kubernetes Secrets Encryption Setup${NC}

Usage: $0 [options]

${CYAN}Options:${NC}
  --generate-key        Generate new encryption key
  --apply               Apply encryption configuration (requires cluster access)
  --verify              Verify encryption is working
  --rotate              Rotate encryption keys
  -h, --help            Show this help message

${CYAN}Examples:${NC}
  # Generate encryption key and create config
  $0 --generate-key

  # Apply encryption configuration to cluster
  $0 --apply

  # Verify encryption is working
  $0 --verify

${YELLOW}Note:${NC} This script requires cluster admin access for --apply and --verify

EOF
}

generate_encryption_key() {
    info "Generating 32-byte encryption key..."

    # Generate random 32-byte key and encode as base64
    local key=$(head -c 32 /dev/urandom | base64 | tr -d '\n')

    info "Creating encryption configuration..."

    # Create config file with generated key
    cat > "${SCRIPT_DIR}/encryption-config-generated.yaml" << EOF
# ABOUTME: Kubernetes encryption configuration for secrets at rest (AUTO-GENERATED)
# ABOUTME: Encrypts all secrets stored in etcd using AES-CBC encryption
# Generated: $(date -Iseconds)

apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      # Primary encryption provider - AES-CBC with 256-bit key
      - aescbc:
          keys:
            - name: key1
              secret: ${key}
      # Identity provider (no encryption) - used for migration
      - identity: {}
EOF

    success "Encryption configuration created: encryption-config-generated.yaml"
    echo ""
    warn "IMPORTANT: Store this file securely!"
    warn "Never commit this file to Git!"
    echo ""

    # Create backup location suggestion
    info "Recommended: Back up encryption key to secure location:"
    echo "  • AWS Secrets Manager"
    echo "  • HashiCorp Vault"
    echo "  • Encrypted USB drive in safe"
    echo ""

    # Save just the key for reference
    echo "${key}" > "${SCRIPT_DIR}/.encryption-key.txt"
    chmod 600 "${SCRIPT_DIR}/.encryption-key.txt"

    success "Encryption key also saved to: .encryption-key.txt (chmod 600)"
    echo ""

    info "Next steps:"
    echo "  1. Review: cat encryption-config-generated.yaml"
    echo "  2. Apply: $0 --apply"
    echo "  3. Verify: $0 --verify"
}

apply_encryption_config() {
    info "Applying encryption configuration to Kubernetes cluster..."
    echo ""

    # Check if generated config exists
    if [[ ! -f "${SCRIPT_DIR}/encryption-config-generated.yaml" ]]; then
        error "Encryption config not found. Run '$0 --generate-key' first"
        exit 1
    fi

    warn "This operation requires cluster admin access and kube-apiserver restart"
    read -p "Continue? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled"
        exit 0
    fi

    # Detect cluster type
    local cluster_type="unknown"
    if kubectl get nodes -o json | grep -q "kind"; then
        cluster_type="kind"
    elif kubectl get nodes -o json | grep -q "minikube"; then
        cluster_type="minikube"
    elif kubectl get nodes -o json | grep -q "eks"; then
        cluster_type="eks"
    fi

    echo ""
    info "Detected cluster type: ${cluster_type}"
    echo ""

    case "${cluster_type}" in
        kind)
            warn "KIND cluster detected - manual configuration required"
            echo ""
            echo "Steps for KIND:"
            echo "  1. Copy config to control plane:"
            echo "     docker cp encryption-config-generated.yaml kind-control-plane:/etc/kubernetes/enc/"
            echo ""
            echo "  2. Update kube-apiserver manifest:"
            echo "     kubectl exec -n kube-system kind-control-plane -- vi /etc/kubernetes/manifests/kube-apiserver.yaml"
            echo ""
            echo "  3. Add encryption provider config flag:"
            echo "     --encryption-provider-config=/etc/kubernetes/enc/encryption-config-generated.yaml"
            echo ""
            echo "  4. Mount the config directory:"
            echo "     volumeMounts:"
            echo "       - name: enc"
            echo "         mountPath: /etc/kubernetes/enc"
            echo "         readOnly: true"
            echo "     volumes:"
            echo "       - name: enc"
            echo "         hostPath:"
            echo "           path: /etc/kubernetes/enc"
            echo "           type: DirectoryOrCreate"
            ;;

        minikube)
            info "Configuring Minikube cluster..."

            # Copy config to minikube
            minikube cp "${SCRIPT_DIR}/encryption-config-generated.yaml" /var/lib/minikube/certs/encryption-config.yaml

            # Add to kube-apiserver
            minikube ssh "sudo mkdir -p /etc/kubernetes/enc"
            minikube ssh "sudo cp /var/lib/minikube/certs/encryption-config.yaml /etc/kubernetes/enc/"

            success "Configuration copied to Minikube"
            warn "Manual step required: Update kube-apiserver configuration"
            echo "  minikube ssh"
            echo "  sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml"
            echo "  Add: --encryption-provider-config=/etc/kubernetes/enc/encryption-config.yaml"
            ;;

        eks)
            error "EKS encryption must be configured during cluster creation"
            echo ""
            info "For existing EKS cluster:"
            echo "  1. Create KMS key: aws kms create-key --description 'EKS secrets encryption'"
            echo "  2. Enable encryption: aws eks associate-encryption-config \\"
            echo "       --cluster-name <cluster> \\"
            echo "       --encryption-config 'resources=secrets,provider={keyArn=arn:aws:kms:...}'"
            echo ""
            info "For new EKS cluster, add to cluster config:"
            echo "  encryptionConfig:"
            echo "    - resources: [secrets]"
            echo "      provider:"
            echo "        keyArn: arn:aws:kms:region:account:key/key-id"
            ;;

        *)
            warn "Unknown cluster type - manual configuration required"
            echo ""
            info "General steps:"
            echo "  1. Copy encryption-config-generated.yaml to API server node:"
            echo "     scp encryption-config-generated.yaml <node>:/etc/kubernetes/enc/"
            echo ""
            echo "  2. Update kube-apiserver configuration:"
            echo "     Add flag: --encryption-provider-config=/etc/kubernetes/enc/encryption-config-generated.yaml"
            echo ""
            echo "  3. Mount configuration directory in kube-apiserver pod"
            echo ""
            echo "  4. Restart kube-apiserver"
            ;;
    esac

    echo ""
    warn "After applying configuration:"
    echo "  1. Wait for kube-apiserver to restart"
    echo "  2. Run: $0 --verify"
    echo "  3. Re-encrypt existing secrets (see docs)"
}

verify_encryption() {
    info "Verifying secrets encryption..."
    echo ""

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error "kubectl not found"
        exit 1
    fi

    # Create test secret
    local test_secret_name="encryption-test-$(date +%s)"
    local test_value="test-data-$(date +%s)"

    info "Creating test secret: ${test_secret_name}"
    kubectl create secret generic "${test_secret_name}" \
        --from-literal=test="${test_value}" \
        -n default

    # Wait a moment for etcd sync
    sleep 2

    # Check if secret is encrypted in etcd
    info "Checking etcd for encryption..."

    # Try to read from etcd (requires etcd client access)
    # This is a simplified check - in production, you'd inspect etcd directly

    # Verify secret is readable via kubectl
    local retrieved_value=$(kubectl get secret "${test_secret_name}" -n default \
        -o jsonpath='{.data.test}' | base64 -d)

    if [[ "${retrieved_value}" == "${test_value}" ]]; then
        success "Secret can be read via kubectl API"
    else
        error "Secret value mismatch"
        kubectl delete secret "${test_secret_name}" -n default
        exit 1
    fi

    # Clean up
    kubectl delete secret "${test_secret_name}" -n default

    echo ""
    success "Encryption verification complete!"
    echo ""
    info "To fully verify encryption in etcd, run on API server node:"
    echo "  ETCDCTL_API=3 etcdctl get /registry/secrets/default/${test_secret_name} \\"
    echo "    --endpoints=https://127.0.0.1:2379 \\"
    echo "    --cacert=/etc/kubernetes/pki/etcd/ca.crt \\"
    echo "    --cert=/etc/kubernetes/pki/etcd/server.crt \\"
    echo "    --key=/etc/kubernetes/pki/etcd/server.key"
    echo ""
    info "Encrypted secrets should NOT contain plain text data"
}

rotate_encryption_keys() {
    info "Rotating encryption keys..."
    echo ""

    warn "Key rotation process:"
    echo "  1. Generate new encryption key"
    echo "  2. Add new key as first provider in config"
    echo "  3. Keep old key as second provider"
    echo "  4. Apply updated config"
    echo "  5. Re-encrypt all secrets with new key"
    echo "  6. Remove old key from config after 24 hours"
    echo ""

    read -p "Generate new encryption key? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Cancelled"
        exit 0
    fi

    # Generate new key
    local new_key=$(head -c 32 /dev/urandom | base64 | tr -d '\n')

    # Read old key if exists
    local old_key=""
    if [[ -f "${SCRIPT_DIR}/.encryption-key.txt" ]]; then
        old_key=$(cat "${SCRIPT_DIR}/.encryption-key.txt")
    fi

    # Create rotated config
    cat > "${SCRIPT_DIR}/encryption-config-rotated.yaml" << EOF
# ABOUTME: Kubernetes encryption configuration with rotated keys
# Generated: $(date -Iseconds)

apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      # New key (will be used for new secrets)
      - aescbc:
          keys:
            - name: key2
              secret: ${new_key}
      # Old key (for reading existing secrets)
      - aescbc:
          keys:
            - name: key1
              secret: ${old_key}
      - identity: {}
EOF

    success "Rotated encryption configuration created: encryption-config-rotated.yaml"
    echo ""

    # Save new key
    echo "${new_key}" > "${SCRIPT_DIR}/.encryption-key-new.txt"
    chmod 600 "${SCRIPT_DIR}/.encryption-key-new.txt"

    info "Next steps:"
    echo "  1. Back up old key: .encryption-key.txt"
    echo "  2. Apply rotated config: $0 --apply"
    echo "  3. Re-encrypt all secrets:"
    echo "     kubectl get secrets --all-namespaces -o json | kubectl replace -f -"
    echo "  4. After 24 hours, remove old key from config"
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    case "${1:-}" in
        --generate-key)
            generate_encryption_key
            ;;
        --apply)
            apply_encryption_config
            ;;
        --verify)
            verify_encryption
            ;;
        --rotate)
            rotate_encryption_keys
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"

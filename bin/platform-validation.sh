#!/usr/bin/env bash
# ABOUTME: Input validation functions for Platform CLI security
# ABOUTME: Prevents command injection, path traversal, and other security vulnerabilities

set -euo pipefail

# Colors for output (if not already defined)
RED=${RED:-'\033[0;31m'}
GREEN=${GREEN:-'\033[0;32m'}
YELLOW=${YELLOW:-'\033[1;33m'}
NC=${NC:-'\033[0m'}

# Error function (if not already defined)
error() {
    echo -e "${RED}✗${NC} $1" >&2
}

# =============================================================================
# validate_name() - Validate resource names (DNS-1123 subdomain format)
# =============================================================================
# Ensures names are safe for:
# - Kubernetes resource names
# - File paths
# - No command injection
# - No path traversal
#
# Rules:
# - Must start with lowercase letter or number
# - Can contain lowercase letters, numbers, and hyphens
# - Must end with lowercase letter or number
# - Maximum 63 characters
#
# Arguments:
#   $1 - Name to validate
#
# Returns:
#   0 if valid, 1 if invalid
# =============================================================================
validate_name() {
    local name="$1"

    # Check if empty
    if [[ -z "$name" ]]; then
        error "Name cannot be empty"
        return 1
    fi

    # Check length (DNS-1123 subdomain: max 63 characters)
    if [[ ${#name} -gt 63 ]]; then
        error "Name too long: ${name} (max 63 characters)"
        return 1
    fi

    # Check DNS-1123 subdomain format
    # Must: start with [a-z0-9], contain only [a-z0-9-], end with [a-z0-9]
    if [[ ! "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
        error "Invalid name: ${name}"
        echo "Name must:" >&2
        echo "  • Start with lowercase letter or number" >&2
        echo "  • Contain only lowercase letters, numbers, and hyphens" >&2
        echo "  • End with lowercase letter or number" >&2
        return 1
    fi

    # Security: Prevent path traversal
    if [[ "$name" =~ \.\. ]]; then
        error "Name cannot contain '..': ${name}"
        return 1
    fi

    # Security: Prevent absolute paths
    if [[ "$name" =~ ^/ ]]; then
        error "Name cannot start with '/': ${name}"
        return 1
    fi

    # Security: Prevent home directory expansion
    if [[ "$name" =~ ^~ ]]; then
        error "Name cannot start with '~': ${name}"
        return 1
    fi

    # Valid
    return 0
}

# =============================================================================
# validate_env() - Validate environment name
# =============================================================================
# Ensures environment is one of the allowed values
#
# Allowed environments:
# - dev
# - staging
# - production
#
# Arguments:
#   $1 - Environment to validate
#
# Returns:
#   0 if valid, 1 if invalid
# =============================================================================
validate_env() {
    local env="$1"

    # Whitelist of allowed environments
    local allowed_envs="dev staging production"

    # Check if empty
    if [[ -z "$env" ]]; then
        error "Environment cannot be empty"
        return 1
    fi

    # Check if in allowed list
    if [[ ! " $allowed_envs " =~ " $env " ]]; then
        error "Invalid environment: ${env}"
        echo "Allowed environments: ${allowed_envs}" >&2
        return 1
    fi

    # Valid
    return 0
}

# =============================================================================
# validate_env_var() - Validate environment variable name and value
# =============================================================================
# Ensures environment variables are safe and on whitelist
#
# Allowed variable names:
# - LOG_LEVEL
# - API_VERSION
# - FEATURE_FLAGS
#
# Arguments:
#   $1 - Variable name
#   $2 - Variable value
#
# Returns:
#   0 if valid, 1 if invalid
# =============================================================================
validate_env_var() {
    local name="$1"
    local value="$2"

    # Whitelist of allowed variable names
    local allowed_names="LOG_LEVEL|API_VERSION|FEATURE_FLAGS"

    # Check if name is allowed
    if [[ ! "$name" =~ ^($allowed_names)$ ]]; then
        error "Environment variable '${name}' not allowed"
        echo "Allowed variables: LOG_LEVEL, API_VERSION, FEATURE_FLAGS" >&2
        return 1
    fi

    # Check if value is empty
    if [[ -z "$value" ]]; then
        error "Environment variable value cannot be empty"
        return 1
    fi

    # Security: Prevent command injection via special characters
    # Disallow: $ ` ; | & < > ( ) { } [ ] \ and newlines
    # Check each character type separately for clarity and reliability
    if [[ "$value" =~ \$ ]] || \
       [[ "$value" =~ \` ]] || \
       [[ "$value" =~ \; ]] || \
       [[ "$value" =~ \| ]] || \
       [[ "$value" =~ \& ]] || \
       [[ "$value" =~ \< ]] || \
       [[ "$value" =~ \> ]] || \
       [[ "$value" =~ \( ]] || \
       [[ "$value" =~ \) ]] || \
       [[ "$value" =~ \{ ]] || \
       [[ "$value" =~ \} ]] || \
       [[ "$value" =~ \[ ]] || \
       [[ "$value" =~ \] ]] || \
       [[ "$value" =~ \\ ]] || \
       [[ "$value" =~ $'\n' ]]; then
        error "Environment variable value contains forbidden characters: ${value}"
        echo "Forbidden characters: \$ \` ; | & < > ( ) { } [ ] \\ newline" >&2
        return 1
    fi

    # Valid
    return 0
}

# =============================================================================
# validate_size() - Validate resource size parameter
# =============================================================================
# Ensures size is one of the allowed values
#
# Allowed sizes:
# - small
# - medium
# - large
#
# Arguments:
#   $1 - Size to validate
#
# Returns:
#   0 if valid, 1 if invalid
# =============================================================================
validate_size() {
    local size="$1"

    # Whitelist of allowed sizes
    local allowed_sizes="small medium large"

    # Check if empty
    if [[ -z "$size" ]]; then
        error "Size cannot be empty"
        return 1
    fi

    # Check if in allowed list
    if [[ ! " $allowed_sizes " =~ " $size " ]]; then
        error "Invalid size: ${size}"
        echo "Allowed sizes: ${allowed_sizes}" >&2
        return 1
    fi

    # Valid
    return 0
}

# =============================================================================
# validate_storage() - Validate storage size in GB
# =============================================================================
# Ensures storage is a valid positive integer within limits
#
# Rules:
# - Must be a positive integer
# - Minimum: 20 GB
# - Maximum: 65536 GB (64 TB)
#
# Arguments:
#   $1 - Storage size in GB
#
# Returns:
#   0 if valid, 1 if invalid
# =============================================================================
validate_storage() {
    local storage="$1"

    # Check if empty
    if [[ -z "$storage" ]]; then
        error "Storage cannot be empty"
        return 1
    fi

    # Check if numeric (positive integer only)
    if [[ ! "$storage" =~ ^[0-9]+$ ]]; then
        error "Storage must be a positive integer: ${storage}"
        return 1
    fi

    # Check minimum
    if [[ "$storage" -lt 20 ]]; then
        error "Storage too small: ${storage}GB (minimum 20GB)"
        return 1
    fi

    # Check maximum
    if [[ "$storage" -gt 65536 ]]; then
        error "Storage too large: ${storage}GB (maximum 65536GB)"
        return 1
    fi

    # Valid
    return 0
}

# =============================================================================
# validate_region() - Validate cloud region
# =============================================================================
# Ensures region is in correct format (not comprehensive, just basic validation)
#
# Arguments:
#   $1 - Region to validate
#
# Returns:
#   0 if valid, 1 if invalid
# =============================================================================
validate_region() {
    local region="$1"

    # Check if empty
    if [[ -z "$region" ]]; then
        error "Region cannot be empty"
        return 1
    fi

    # Basic format check: lowercase letters, numbers, hyphens
    # Examples: us-west-2, eu-central-1, ap-southeast-1
    if [[ ! "$region" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
        error "Invalid region format: ${region}"
        echo "Region must contain only lowercase letters, numbers, and hyphens" >&2
        return 1
    fi

    # Valid
    return 0
}

# =============================================================================
# validate_namespace() - Validate Kubernetes namespace
# =============================================================================
# Ensures namespace follows Kubernetes naming rules
#
# Arguments:
#   $1 - Namespace to validate
#
# Returns:
#   0 if valid, 1 if invalid
# =============================================================================
validate_namespace() {
    local namespace="$1"

    # Namespace uses same rules as resource names (DNS-1123 label)
    validate_name "$namespace"
    return $?
}

# =============================================================================
# validate_file_path() - Validate file paths for safe file operations
# =============================================================================
# Ensures file paths are safe and within expected directories
#
# Rules:
# - Must not contain ../
# - Must not be absolute path (unless explicitly allowed)
# - Must not contain special characters
#
# Arguments:
#   $1 - File path to validate
#   $2 - Base directory (optional, for additional validation)
#
# Returns:
#   0 if valid, 1 if invalid
# =============================================================================
validate_file_path() {
    local file_path="$1"
    local base_dir="${2:-}"

    # Check if empty
    if [[ -z "$file_path" ]]; then
        error "File path cannot be empty"
        return 1
    fi

    # Security: Prevent path traversal
    if [[ "$file_path" =~ \.\. ]]; then
        error "File path cannot contain '..': ${file_path}"
        return 1
    fi

    # Security: Prevent absolute paths (unless base_dir is empty)
    if [[ -n "$base_dir" ]] && [[ "$file_path" =~ ^/ ]]; then
        error "File path cannot be absolute: ${file_path}"
        return 1
    fi

    # If base_dir provided, ensure file is within base directory
    if [[ -n "$base_dir" ]]; then
        local full_path="${base_dir}/${file_path}"
        local resolved_path
        resolved_path=$(realpath -m "$full_path" 2>/dev/null || echo "$full_path")
        local resolved_base
        resolved_base=$(realpath -m "$base_dir" 2>/dev/null || echo "$base_dir")

        if [[ ! "$resolved_path" =~ ^"$resolved_base" ]]; then
            error "File path escapes base directory: ${file_path}"
            return 1
        fi
    fi

    # Valid
    return 0
}

# =============================================================================
# sanitize_for_yaml() - Sanitize string for safe YAML generation
# =============================================================================
# Ensures strings can be safely embedded in YAML without injection
#
# Arguments:
#   $1 - String to sanitize
#
# Returns:
#   Sanitized string on stdout
# =============================================================================
sanitize_for_yaml() {
    local input="$1"

    # Escape special YAML characters
    # Replace single quotes with two single quotes (YAML escaping)
    local sanitized="${input//\'/\'\'}"

    # Wrap in single quotes for YAML
    echo "'${sanitized}'"
}

# Export functions for use in other scripts
export -f validate_name
export -f validate_env
export -f validate_env_var
export -f validate_size
export -f validate_storage
export -f validate_region
export -f validate_namespace
export -f validate_file_path
export -f sanitize_for_yaml

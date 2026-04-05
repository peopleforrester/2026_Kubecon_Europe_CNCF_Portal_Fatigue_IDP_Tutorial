#!/usr/bin/env bash
# ABOUTME: Unit tests for CLI input validation functions
# ABOUTME: Tests validate_name, validate_env, and validate_env_var functions

set -euo pipefail

# Test framework setup
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Source the validation functions (will be created)
source "$(dirname "$0")/../../../bin/platform-validation.sh" 2>/dev/null || true

# Test helper functions
assert_success() {
    local test_name="$1"
    local command="$2"

    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name (expected success, got failure)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_failure() {
    local test_name="$1"
    local command="$2"

    if ! eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name (expected failure, got success)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local test_name="$1"
    local command="$2"
    local expected_string="$3"

    local output
    output=$(eval "$command" 2>&1 || true)

    if echo "$output" | grep -q "$expected_string"; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $test_name (expected '$expected_string' in output)"
        echo "  Got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# === Tests for validate_name() ===
echo "Testing validate_name()..."

# Valid names
assert_success "validate_name: lowercase alphanumeric" "validate_name 'my-app'"
assert_success "validate_name: single character" "validate_name 'a'"
assert_success "validate_name: starts with number" "validate_name '1-app'"
assert_success "validate_name: hyphens in middle" "validate_name 'my-test-app'"
assert_success "validate_name: DNS-compliant name" "validate_name 'app-database-01'"

# Invalid names (should fail)
assert_failure "validate_name: uppercase letters" "validate_name 'MyApp'"
assert_failure "validate_name: underscore" "validate_name 'my_app'"
assert_failure "validate_name: spaces" "validate_name 'my app'"
assert_failure "validate_name: starts with hyphen" "validate_name '-myapp'"
assert_failure "validate_name: ends with hyphen" "validate_name 'myapp-'"
assert_failure "validate_name: special characters" "validate_name 'my@app'"
assert_failure "validate_name: empty string" "validate_name ''"

# Security: Command injection attempts (should fail)
assert_failure "validate_name: command injection with semicolon" "validate_name 'test; rm -rf /'"
assert_failure "validate_name: command injection with pipe" "validate_name 'test | cat /etc/passwd'"
assert_failure "validate_name: command injection with backticks" "validate_name 'test\`whoami\`'"
assert_failure "validate_name: command injection with dollar paren" "validate_name 'test\$(whoami)'"
assert_failure "validate_name: command injection with ampersand" "validate_name 'test && ls'"

# Security: Path traversal attempts (should fail)
assert_failure "validate_name: path traversal with .." "validate_name '../../../etc/passwd'"
assert_failure "validate_name: path traversal in middle" "validate_name 'test/../../../secret'"
assert_failure "validate_name: absolute path" "validate_name '/etc/passwd'"
assert_failure "validate_name: home directory" "validate_name '~/malicious'"

# === Tests for validate_env() ===
echo ""
echo "Testing validate_env()..."

# Valid environments
assert_success "validate_env: dev" "validate_env 'dev'"
assert_success "validate_env: staging" "validate_env 'staging'"
assert_success "validate_env: production" "validate_env 'production'"

# Invalid environments (should fail)
assert_failure "validate_env: invalid environment" "validate_env 'test'"
assert_failure "validate_env: uppercase" "validate_env 'DEV'"
assert_failure "validate_env: with hyphen" "validate_env 'dev-test'"
assert_failure "validate_env: empty string" "validate_env ''"

# Security: Command injection in env (should fail)
assert_failure "validate_env: command injection" "validate_env 'dev; rm -rf /'"
assert_failure "validate_env: path traversal" "validate_env '../production'"

# === Tests for validate_env_var() ===
echo ""
echo "Testing validate_env_var()..."

# Valid environment variables
assert_success "validate_env_var: LOG_LEVEL=info" "validate_env_var 'LOG_LEVEL' 'info'"
assert_success "validate_env_var: LOG_LEVEL=debug" "validate_env_var 'LOG_LEVEL' 'debug'"
assert_success "validate_env_var: LOG_LEVEL=warn" "validate_env_var 'LOG_LEVEL' 'warn'"
assert_success "validate_env_var: LOG_LEVEL=error" "validate_env_var 'LOG_LEVEL' 'error'"
assert_success "validate_env_var: API_VERSION with number" "validate_env_var 'API_VERSION' 'v1.2.3'"
assert_success "validate_env_var: FEATURE_FLAGS alphanumeric" "validate_env_var 'FEATURE_FLAGS' 'flag1-flag2'"

# Invalid variable names (should fail)
assert_failure "validate_env_var: unknown variable name" "validate_env_var 'MALICIOUS_VAR' 'value'"
assert_failure "validate_env_var: lowercase name" "validate_env_var 'log_level' 'info'"

# Invalid variable values (should fail - special chars)
assert_failure "validate_env_var: value with dollar sign" 'validate_env_var LOG_LEVEL '\''$PWD'\'''
assert_failure "validate_env_var: value with backtick" 'validate_env_var LOG_LEVEL '\''`whoami`'\'''
assert_failure "validate_env_var: value with semicolon" "validate_env_var LOG_LEVEL 'info; rm -rf /'"
assert_failure "validate_env_var: value with pipe" "validate_env_var LOG_LEVEL 'info | cat /etc/passwd'"

# === Tests for validate_size() ===
echo ""
echo "Testing validate_size()..."

# Valid sizes
assert_success "validate_size: small" "validate_size 'small'"
assert_success "validate_size: medium" "validate_size 'medium'"
assert_success "validate_size: large" "validate_size 'large'"

# Invalid sizes (should fail)
assert_failure "validate_size: invalid size" "validate_size 'xlarge'"
assert_failure "validate_size: uppercase" "validate_size 'SMALL'"
assert_failure "validate_size: number" "validate_size '100'"
assert_failure "validate_size: command injection" "validate_size 'small; rm -rf /'"

# === Tests for validate_storage() ===
echo ""
echo "Testing validate_storage()..."

# Valid storage values
assert_success "validate_storage: minimum 20" "validate_storage '20'"
assert_success "validate_storage: medium value" "validate_storage '100'"
assert_success "validate_storage: large value" "validate_storage '1000'"

# Invalid storage values (should fail)
assert_failure "validate_storage: below minimum" "validate_storage '10'"
assert_failure "validate_storage: zero" "validate_storage '0'"
assert_failure "validate_storage: negative" "validate_storage '-100'"
assert_failure "validate_storage: non-numeric" "validate_storage 'abc'"
assert_failure "validate_storage: with special chars" "validate_storage '100; rm -rf /'"

# === Test Summary ===
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi

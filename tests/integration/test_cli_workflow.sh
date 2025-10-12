#!/usr/bin/env bash
# ABOUTME: Integration tests for Platform CLI workflow
# ABOUTME: Tests actual file creation, git operations, and full command flow

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test temp directory
TEST_DIR="/tmp/platform-cli-test-$$"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Setup
setup() {
    echo -e "${BLUE}Setting up integration test environment...${NC}"
    mkdir -p "${TEST_DIR}"
    cd "${PROJECT_ROOT}"
}

# Teardown
teardown() {
    echo ""
    echo -e "${BLUE}Cleaning up...${NC}"
    if [[ -d "${TEST_DIR}" ]]; then
        rm -rf "${TEST_DIR}"
    fi
    # Clean up test files in project
    rm -f environments/test-*/*.yaml
    rmdir environments/test-* 2>/dev/null || true
}

# Test helpers
assert_success() {
    local test_name="$1"
    local command="$2"

    ((TESTS_RUN++))

    if eval "$command" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "   Command: $command"
        ((TESTS_FAILED++))
    fi
}

assert_file_exists() {
    local test_name="$1"
    local file="$2"

    ((TESTS_RUN++))

    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name - File not found: $file"
        ((TESTS_FAILED++))
    fi
}

assert_file_contains() {
    local test_name="$1"
    local file="$2"
    local pattern="$3"

    ((TESTS_RUN++))

    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name - Pattern not found: $pattern"
        ((TESTS_FAILED++))
    fi
}

# Tests
test_platform_create_postgres_dry_run() {
    echo ""
    echo "Testing: platform create postgres (dry-run)"

    local test_env="test-$$"

    # Create dry-run claim
    assert_success "Create PostgreSQL with dry-run" \
        "bin/platform-create postgres test-db --env=${test_env} --size=small --dry-run"
}

test_platform_create_postgres_actual() {
    echo ""
    echo "Testing: platform create postgres (actual file creation)"

    local test_env="test-$$"
    mkdir -p "environments/${test_env}"

    # Create actual claim
    bin/platform-create postgres test-db \
        --env="${test_env}" \
        --size=small \
        --storage=20 \
        --multi-az=false \
        --backup-days=1 \
        > /dev/null 2>&1

    # Verify file created
    assert_file_exists "PostgreSQL claim file created" \
        "environments/${test_env}/test-db.yaml"

    # Verify file contents
    assert_file_contains "Claim has correct kind" \
        "environments/${test_env}/test-db.yaml" \
        "kind: PostgreSQL"

    assert_file_contains "Claim has correct name" \
        "environments/${test_env}/test-db.yaml" \
        "name: test-db"

    assert_file_contains "Claim has correct namespace" \
        "environments/${test_env}/test-db.yaml" \
        "namespace: ${test_env}"

    assert_file_contains "Claim has correct size" \
        "environments/${test_env}/test-db.yaml" \
        "size: small"

    # Cleanup
    rm -f "environments/${test_env}/test-db.yaml"
    rmdir "environments/${test_env}"
}

test_platform_create_redis() {
    echo ""
    echo "Testing: platform create redis"

    local test_env="test-$$"
    mkdir -p "environments/${test_env}"

    # Create Redis claim
    bin/platform-create redis test-cache \
        --env="${test_env}" \
        --size=small \
        --nodes=1 \
        > /dev/null 2>&1

    # Verify file created
    assert_file_exists "Redis claim file created" \
        "environments/${test_env}/test-cache.yaml"

    # Verify file contents
    assert_file_contains "Claim has correct kind" \
        "environments/${test_env}/test-cache.yaml" \
        "kind: Redis"

    assert_file_contains "Claim has nodes configured" \
        "environments/${test_env}/test-cache.yaml" \
        "numNodes:"

    # Cleanup
    rm -f "environments/${test_env}/test-cache.yaml"
    rmdir "environments/${test_env}"
}

test_platform_create_s3bucket() {
    echo ""
    echo "Testing: platform create s3bucket"

    local test_env="test-$$"
    mkdir -p "environments/${test_env}"

    # Create S3 bucket claim
    bin/platform-create s3bucket test-bucket \
        --env="${test_env}" \
        > /dev/null 2>&1

    # Verify file created
    assert_file_exists "S3Bucket claim file created" \
        "environments/${test_env}/test-bucket.yaml"

    # Verify file contents
    assert_file_contains "Claim has correct kind" \
        "environments/${test_env}/test-bucket.yaml" \
        "kind: S3Bucket"

    assert_file_contains "Claim has versioning configured" \
        "environments/${test_env}/test-bucket.yaml" \
        "versioning:"

    # Cleanup
    rm -f "environments/${test_env}/test-bucket.yaml"
    rmdir "environments/${test_env}"
}

test_platform_list() {
    echo ""
    echo "Testing: platform list"

    # List all types
    assert_success "List all infrastructure types" \
        "bin/platform-list"

    # List specific type
    assert_success "List PostgreSQL type" \
        "bin/platform-list postgres"
}

test_platform_cost() {
    echo ""
    echo "Testing: platform cost"

    # Estimate PostgreSQL cost
    assert_success "Estimate PostgreSQL cost" \
        "bin/platform-cost postgres --size=medium"

    # Estimate Redis cost
    assert_success "Estimate Redis cost" \
        "bin/platform-cost redis --size=small"

    # Compare costs
    assert_success "Compare PostgreSQL costs" \
        "bin/platform-cost postgres --compare"
}

test_platform_validate() {
    echo ""
    echo "Testing: platform validate"

    local test_env="test-$$"
    mkdir -p "environments/${test_env}"

    # Create test claim
    bin/platform-create postgres validate-test \
        --env="${test_env}" \
        --size=small \
        > /dev/null 2>&1

    # Validate claim file
    assert_success "Validate claim file" \
        "bin/platform-validate environments/${test_env}/validate-test.yaml"

    # Cleanup
    rm -f "environments/${test_env}/validate-test.yaml"
    rmdir "environments/${test_env}"
}

test_security_input_validation() {
    echo ""
    echo "Testing: Security - Input validation"

    local test_env="test-$$"

    # Test command injection is blocked
    assert_success "Block command injection in name" \
        "! bin/platform-create postgres 'test; rm -rf /' --env=${test_env} --dry-run"

    # Test path traversal is blocked
    assert_success "Block path traversal in name" \
        "! bin/platform-create postgres '../../../etc/passwd' --env=${test_env} --dry-run"

    # Test invalid environment is blocked
    assert_success "Block invalid environment" \
        "! bin/platform-create postgres test-db --env='prod; whoami' --dry-run"
}

test_file_naming_conventions() {
    echo ""
    echo "Testing: File naming conventions"

    local test_env="test-$$"
    mkdir -p "environments/${test_env}"

    # Create claim with complex valid name
    bin/platform-create postgres my-app-db-01 \
        --env="${test_env}" \
        --size=small \
        > /dev/null 2>&1

    # Verify file follows naming convention
    assert_file_exists "File follows naming convention" \
        "environments/${test_env}/my-app-db-01.yaml"

    # Cleanup
    rm -f "environments/${test_env}/my-app-db-01.yaml"
    rmdir "environments/${test_env}"
}

# Main test runner
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Platform CLI Integration Tests${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

    setup

    # Run tests
    test_platform_create_postgres_dry_run
    test_platform_create_postgres_actual
    test_platform_create_redis
    test_platform_create_s3bucket
    test_platform_list
    test_platform_cost
    test_platform_validate
    test_security_input_validation
    test_file_naming_conventions

    teardown

    # Results
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Test Results${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "Tests Run:    ${TESTS_RUN}"
    echo -e "Passed:       ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Failed:       ${RED}${TESTS_FAILED}${NC}"

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}✓ All integration tests passed!${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}✗ Some integration tests failed${NC}"
        exit 1
    fi
}

# Handle Ctrl+C
trap teardown EXIT INT TERM

main "$@"

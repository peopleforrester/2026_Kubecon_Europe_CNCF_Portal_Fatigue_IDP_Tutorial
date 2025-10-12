#!/usr/bin/env bash
# ABOUTME: Integration tests for Crossplane provider installation and health
# ABOUTME: Verifies providers are installed and healthy before resource provisioning

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

echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Crossplane Provider Integration Tests${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"

# Test helper
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_RUN++))
    echo -n "Testing: $test_name... "

    if eval "$test_command" &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC}"
        ((TESTS_FAILED++))
    fi
}

# Check kubectl availability
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠${NC}  kubectl not found - skipping tests"
    echo -e "${YELLOW}Note:${NC} These tests require cluster access"
    exit 0
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${YELLOW}⚠${NC}  No cluster access - skipping tests"
    echo -e "${YELLOW}Note:${NC} Run these tests against a running cluster"
    exit 0
fi

echo ""

# Test 1: Crossplane namespace exists
run_test "Crossplane namespace exists" \
    "kubectl get namespace crossplane-system"

# Test 2: Crossplane pods are running
run_test "Crossplane pods are running" \
    "kubectl get pods -n crossplane-system -l app=crossplane -o jsonpath='{.items[*].status.phase}' | grep -q Running"

# Test 3: Crossplane CRDs installed
run_test "Crossplane CRDs installed" \
    "kubectl get crds | grep -q crossplane.io"

# Test 4: AWS Provider (if installed)
if kubectl get providers -n crossplane-system | grep -q provider-aws &> /dev/null; then
    run_test "AWS Provider installed" \
        "kubectl get providers -n crossplane-system provider-aws"

    run_test "AWS Provider is healthy" \
        "kubectl get providers -n crossplane-system provider-aws -o jsonpath='{.status.conditions[?(@.type==\"Healthy\")].status}' | grep -q True"
fi

# Test 5: Provider configs (if exist)
if kubectl get providerconfigs -n crossplane-system &> /dev/null 2>&1; then
    run_test "Provider configs exist" \
        "kubectl get providerconfigs -n crossplane-system"
fi

# Test 6: Compositions installed
run_test "Compositions are defined" \
    "kubectl get compositions"

# Test 7: XRDs installed
run_test "XRDs are defined" \
    "kubectl get xrds"

# Results
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
echo "Tests Run:    ${TESTS_RUN}"
echo -e "Passed:       ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed:       ${RED}${TESTS_FAILED}${NC}"

if [[ ${TESTS_FAILED} -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✓ All Crossplane provider tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi

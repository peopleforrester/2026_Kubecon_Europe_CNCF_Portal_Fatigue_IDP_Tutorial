#!/usr/bin/env bash
# ABOUTME: Test runner for all Backend-First IDP tests
# ABOUTME: Runs unit, integration, and E2E tests with comprehensive reporting

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

usage() {
    cat << EOF
${PURPLE}Backend-First IDP Test Runner${NC}

Usage: $0 [options]

${BLUE}Options:${NC}
  --unit             Run unit tests only
  --integration      Run integration tests only
  --e2e              Run E2E tests only
  --no-cluster       Skip tests requiring cluster access
  -h, --help         Show this help message

${BLUE}Examples:${NC}
  # Run all tests
  $0

  # Run only unit tests
  $0 --unit

  # Run tests without cluster access
  $0 --no-cluster

EOF
}

run_test_suite() {
    local suite_name="$1"
    local test_command="$2"

    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  Running: ${suite_name}${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════${NC}"

    ((TOTAL_SUITES++))

    if eval "$test_command"; then
        echo -e "${GREEN}✓${NC} ${suite_name} PASSED"
        ((PASSED_SUITES++))
        return 0
    else
        echo -e "${RED}✗${NC} ${suite_name} FAILED"
        ((FAILED_SUITES++))
        return 1
    fi
}

main() {
    local run_unit=true
    local run_integration=true
    local run_e2e=true
    local skip_cluster=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unit)
                run_integration=false
                run_e2e=false
                ;;
            --integration)
                run_unit=false
                run_e2e=false
                ;;
            --e2e)
                run_unit=false
                run_integration=false
                ;;
            --no-cluster)
                skip_cluster=true
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
        shift
    done

    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Backend-First IDP Test Suite                   ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Project Root: ${PROJECT_ROOT}"
    echo -e "Test Directory: ${SCRIPT_DIR}"

    cd "${PROJECT_ROOT}"

    # Run unit tests
    if [[ "$run_unit" == "true" ]]; then
        run_test_suite "Unit Tests - Input Validation" \
            "bash ${SCRIPT_DIR}/unit/cli/test_input_validation.sh"
    fi

    # Run integration tests
    if [[ "$run_integration" == "true" ]]; then
        if [[ "$skip_cluster" == "true" ]]; then
            echo ""
            echo -e "${YELLOW}⚠${NC}  Skipping integration tests (--no-cluster)"
        else
            run_test_suite "Integration Tests - CLI Workflow" \
                "bash ${SCRIPT_DIR}/integration/test_cli_workflow.sh"

            run_test_suite "Integration Tests - Crossplane Providers" \
                "bash ${SCRIPT_DIR}/integration/test_crossplane_providers.sh"
        fi
    fi

    # Run E2E tests
    if [[ "$run_e2e" == "true" ]]; then
        if [[ "$skip_cluster" == "true" ]]; then
            echo ""
            echo -e "${YELLOW}⚠${NC}  Skipping E2E tests (--no-cluster)"
        else
            run_test_suite "E2E Tests - Application Lifecycle" \
                "python3 ${SCRIPT_DIR}/e2e/test_application_lifecycle.py"
        fi
    fi

    # Final results
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Final Test Results                              ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Test Suites Run:    ${TOTAL_SUITES}"
    echo -e "Passed:             ${GREEN}${PASSED_SUITES}${NC}"
    echo -e "Failed:             ${RED}${FAILED_SUITES}${NC}"

    if [[ ${FAILED_SUITES} -eq 0 ]]; then
        echo ""
        echo -e "${GREEN}✓ ALL TEST SUITES PASSED!${NC}"
        exit 0
    else
        echo ""
        echo -e "${RED}✗ SOME TEST SUITES FAILED${NC}"
        exit 1
    fi
}

main "$@"

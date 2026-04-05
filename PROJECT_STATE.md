# PROJECT_STATE.md — Backend-First IDP Tutorial Remediation

**Last updated**: 2026-04-06
**Branch**: staging (merged to main after each phase)
**Status**: Phases 1-3 COMPLETE

## Context

Senior developer review scored this repo C+. All critical and high-priority
issues have been addressed. KubeCon Europe 2026 blocking items are resolved.

**GitHub org**: `peopleforrester`
**Repo**: `2026_Kubecon_Europe_CNCF_Portal_Fatigue_IDP_Tutorial`

## Verified Versions (April 2026)

| Component | Previous | Updated To | Source |
|-----------|----------|-----------|--------|
| ArgoCD | v2.11.0 (EOL) | v3.3.6 | Web research confirmed |
| Crossplane | v1.16.0 | v2.2.0 | Web research confirmed |
| Kyverno | v1.11.0 | v1.17.1 | Web research confirmed |
| Upbound AWS Providers | v1.2.0 | v2.5.1 | Web research confirmed |

## Phase 1: CRITICAL — COMPLETE

- [x] 1.1 Update ArgoCD v2.11.0 → v3.3.6
- [x] 1.2 Update Crossplane v1.16.0 → v2.2.0
- [x] 1.3 Update Kyverno v1.11.0 → v1.17.1
- [x] 1.4 Update Upbound AWS/GCP/Azure providers v1.2.0 → v2.5.1
- [x] 1.5 Fix setup.sh broken file paths
- [x] 1.6 Create SECURITY.md and SECURITY_QA_REVIEW.md
- [x] 1.7 Replace ALL placeholder URLs (40+ instances)
- [x] 1.8 Change default region to eu-west-1
- [x] 1.9 Fix 2 failing unit tests (57/57 now passing)
- [x] 1.10 Create staging branch

## Phase 2: HIGH PRIORITY — COMPLETE

- [x] 2.1 Add production safety warning for auto-prune
- [x] 2.2 Clean up bot attribution in CLI commit messages
- [x] 2.3 Extract CLI boilerplate into platform-common.sh
- [x] 2.5 Add trap cleanup EXIT to setup.sh
- [x] 2.7 Add GitHub Actions CI pipeline
- [x] 2.8 Fix TUTORIAL.md reference in setup.sh

## Phase 3: MEDIUM PRIORITY — COMPLETE

- [x] 3.1 Migrate compositions to Crossplane v2 Pipeline mode
- [x] 3.7 Update project config with build/test commands

## Remaining (deferred, non-blocking)

- [ ] Fix sed -i portability in platform-promote for macOS
- [ ] Fix platform-connect credential masking
- [ ] Fix E2E test to fail explicitly when no cluster
- [ ] Consolidate overlapping root markdown files
- [ ] Populate or remove empty .gitkeep directories
- [ ] Verify Kyverno CEL policy migration path

## Test Status

- Unit tests: **57/57 passing**
- CI pipeline: GitHub Actions (shellcheck + unit tests + yamllint)

# PROJECT_STATE.md — Backend-First IDP Tutorial Remediation

**Last updated**: 2026-04-06
**Branch**: staging (to be created from main)
**Status**: Planning complete, execution not started

## Context

Senior developer review scored this repo **C+**. KubeCon Europe 2026 is imminent.
The repo has critically outdated dependency versions, broken file references,
pervasive placeholder URLs, and no CI/CD pipeline. This remediation plan
addresses all findings in priority order.

**GitHub org**: `peopleforrester`
**Repo**: `2026_Kubecon_Europe_CNCF_Portal_Fatigue_IDP_Tutorial`

## Verified Version Research (April 2026)

| Component | Current in Repo | Target Version | Status |
|-----------|----------------|----------------|--------|
| ArgoCD | v2.11.0 (EOL) | v3.3.6 | Confirmed via web research |
| Crossplane | v1.16.0 | v2.2.x (TBD) | Research pending |
| Kyverno | v1.11.0 | v1.17.x (TBD) | Research pending |
| Upbound AWS Providers | v1.2.0 | TBD | Research pending |

## Phase 1: CRITICAL — Blocking for KubeCon

- [ ] 1.1 Update ArgoCD from v2.11.0 → v3.3.6
- [ ] 1.2 Update Crossplane from v1.16.0 → current stable
- [ ] 1.3 Update Kyverno from v1.11.0 → current stable
- [ ] 1.4 Update Upbound AWS provider versions
- [ ] 1.5 Fix setup.sh broken file paths (provider-aws.yaml → aws-provider.yaml, remove aws-provider-config.yaml ref)
- [ ] 1.6 Create SECURITY.md and SECURITY_QA_REVIEW.md (or remove badge/references)
- [ ] 1.7 Replace ALL placeholder URLs ([YOUR-ORG], [ORG], link-to-slack, support@ email, youtube placeholders)
- [ ] 1.8 Change default AWS region from us-west-2 → eu-west-1 for European audience
- [ ] 1.9 Fix 2 failing unit tests (bash expansion test framework issue)
- [ ] 1.10 Create staging branch and establish workflow

## Phase 2: HIGH PRIORITY — Important fixes

- [ ] 2.1 Add production safety warning comment for auto-prune in platform-apps.yaml
- [ ] 2.2 Clean up bot attribution emoji in CLI commit messages
- [ ] 2.3 Extract CLI boilerplate into platform-common.sh (colors, helpers, validation source)
- [ ] 2.4 Fix sed -i portability for macOS in platform-promote
- [ ] 2.5 Add trap cleanup EXIT to setup.sh
- [ ] 2.6 Fix platform-connect credential masking (--format=url always shows password)
- [ ] 2.7 Add GitHub Actions CI pipeline (shellcheck + unit tests)
- [ ] 2.8 Fix TUTORIAL.md reference in setup.sh (file doesn't exist)

## Phase 3: MEDIUM PRIORITY — Polish

- [ ] 3.1 Update Crossplane composition mode: Resources syntax if needed for v2
- [ ] 3.2 Verify Kyverno policy patterns work with current version
- [ ] 3.3 Fix E2E test to fail explicitly when no cluster available
- [ ] 3.4 Fix integration tests writing to repo working tree
- [ ] 3.5 Consolidate overlapping root markdown files
- [ ] 3.6 Populate or remove empty .gitkeep directories
- [ ] 3.7 Update CLAUDE.md with build/test commands

## Current Step

**Next**: Create staging branch, then begin Phase 1.1

## Test Status

- Unit tests: 55/57 passing (2 framework bugs)
- Integration tests: Not CI-integrated
- E2E tests: Silently pass without cluster

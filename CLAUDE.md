# 2026 Kubecon Europe CNCF Portal Fatigue IDP Tutorial

KubeCon Europe 2026 Portal Fatigue IDP tutorial

**Stack**: Bash CLI + Kubernetes YAML (ArgoCD, Crossplane, Kyverno) + Documentation

## Quick Commands

```bash
# Run unit tests (57 tests for CLI input validation)
bash tests/unit/cli/test_input_validation.sh

# Run all tests (unit + integration + e2e)
bash tests/run-all-tests.sh

# Run CLI commands
bin/platform list
bin/platform create postgres my-db --env=dev --size=small
bin/platform validate environments/dev/postgresql-claim.yaml
```

## Key Directories

- `bin/` — Platform CLI scripts (platform-common.sh for shared boilerplate)
- `argocd/` — ArgoCD installation and application manifests
- `crossplane/` — Crossplane providers, XRDs, compositions, and functions
- `kyverno/` — Policy engine installation and policies
- `environments/` — Per-environment infrastructure claims
- `scripts/setup.sh` — Main installation script
- `tests/` — Unit, integration, and E2E tests

## Dependency Versions (April 2026)

- ArgoCD: v3.3.6
- Crossplane: v2.2.0 (Pipeline mode required, uses function-patch-and-transform)
- Kyverno: v1.17.1 (CEL policies GA, ClusterPolicy deprecated but functional)
- Upbound AWS/GCP/Azure Providers: v2.5.1

## GitHub

- Org: peopleforrester
- Default region: eu-west-1 (European conference)

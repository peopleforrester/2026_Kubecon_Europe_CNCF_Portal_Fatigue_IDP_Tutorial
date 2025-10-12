# Staging Environment

Pre-production environment for final testing before production deployment. Infrastructure mirrors production but with smaller resource allocations.

## What's Deployed

### Redis Cache (High Availability)
- **File**: `redis-claim.yaml`
- **Size**: Medium (cache.t3.small)
- **Nodes**: 2 with automatic failover
- **Encryption**: Transit and at-rest enabled
- **Snapshots**: 3-day retention
- **Cost**: ~$25/month

## Key Differences from Dev

| Feature | Dev | Staging |
|---------|-----|---------|
| Instance Size | Small | Medium |
| High Availability | No (1 node) | Yes (2 nodes with failover) |
| Backup Retention | 1 day | 3 days |
| Encryption | Basic | Full (transit + at-rest) |
| Purpose | Development | Pre-production testing |

## GitOps Promotion from Dev

Staging receives promoted features from dev:

```bash
# 1. Feature tested in dev
git checkout dev-feature-branch

# 2. Merge to main (triggers dev deployment)
git checkout main
git merge dev-feature-branch

# 3. Promote to staging
cp environments/dev/my-service-claim.yaml environments/staging/
# Edit to upgrade size and HA settings
sed -i 's/size: small/size: medium/' environments/staging/my-service-claim.yaml

# 4. Commit and deploy
git add environments/staging/
git commit -m "Promote feature X to staging"
git push
```

## Testing Checklist

Before promoting to production:

- [ ] All integration tests pass
- [ ] Load testing completed
- [ ] Security scan clean
- [ ] Performance benchmarks met
- [ ] Backup/restore verified
- [ ] Failover tested (for HA resources)
- [ ] Monitoring and alerts configured

## Environment Characteristics

- **Purpose**: Pre-production validation
- **Uptime**: High (mirrors production)
- **Data**: Anonymized production data
- **Users**: Internal QA and stakeholders
- **Changes**: Controlled promotion from dev

## Monitoring

Resources in staging should be monitored:

```bash
# Check Redis cluster status
kubectl describe redis app-cache -n staging

# View CloudWatch metrics (if configured)
# CPU, Memory, Network, Evictions, etc.
```

## Cost Estimation

Current staging infrastructure:
- Redis HA (medium, 2 nodes): ~$25/month

## Next Steps

After validation in staging:
1. Review test results
2. Get stakeholder approval
3. Promote to production (see [../production/README.md](../production/README.md))

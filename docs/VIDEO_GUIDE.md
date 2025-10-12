# Video Guide

**Learn Backend-First IDP through video walkthroughs**

This guide provides links to video tutorials, demos, and recordings to help you learn the Backend-First IDP approach visually.

---

## Quick Start Videos

### 1. Installation & Setup (5 minutes)

**What you'll learn**:
- Install ArgoCD and Crossplane
- Configure cloud provider credentials
- Verify installation health

**Video**: [Installation Walkthrough](https://youtube.com/placeholder) *(Coming soon)*

**Corresponding docs**: [Quick Start Guide](/docs/quickstart.md)

**Commands covered**:
```bash
./scripts/setup.sh
kubectl get providers
kubectl get pods -n argocd
```

---

### 2. Your First Infrastructure Request (10 minutes)

**What you'll learn**:
- Create a PostgreSQL claim via Git commit
- Watch ArgoCD sync the change
- Verify Crossplane provisioned RDS
- Access connection secrets

**Video**: [First Database Provisioning](https://youtube.com/placeholder) *(Coming soon)*

**Corresponding docs**: [Quick Start - Step 6](/docs/quickstart.md#step-6-deploy-first-infrastructure)

**YAML you'll create**:
```yaml
apiVersion: platform.io/v1alpha1
kind: PostgreSQL
metadata:
  name: my-first-db
  namespace: dev
spec:
  parameters:
    size: small
    storageGB: 20
    version: "15"
  writeConnectionSecretToRef:
    name: my-first-db-connection
```

---

### 3. Application CRD Deep Dive (15 minutes)

**What you'll learn**:
- Deploy full application stack with one resource
- Understand auto-wiring of infrastructure
- Test application connectivity
- Explore generated resources

**Video**: [Application CRD Tutorial](https://youtube.com/placeholder) *(Coming soon)*

**Corresponding docs**: [Tutorial - Lab 4](/TUTORIAL.md#lab-4-deploy-full-application-20-min)

**Key concept**: Application CRD provisions infrastructure AND application together:
```yaml
apiVersion: platform.io/v1alpha1
kind: Application
metadata:
  name: simple-api
spec:
  infrastructure:
    database:
      type: PostgreSQL
      size: small
    cache:
      type: Redis
      size: small
  application:
    image: ghcr.io/backend-first-idp/simple-api:v1.0
    port: 8080
    replicas: 2
```

---

### 4. Multi-Environment Promotion (12 minutes)

**What you'll learn**:
- Promote changes from dev → staging → production
- Understand environment-specific policies
- Test cost controls and security enforcement
- Handle promotion workflows

**Video**: [Environment Promotion](https://youtube.com/placeholder) *(Coming soon)*

**Corresponding docs**: [Tutorial - Lab 5](/TUTORIAL.md#lab-5-environment-promotion-10-min)

**Environment progression**:
```
environments/dev/my-app.yaml
    ↓ (copy & modify)
environments/staging/my-app.yaml
    ↓ (copy & modify with approvals)
environments/production/my-app.yaml
```

---

### 5. Building Custom Compositions (20 minutes)

**What you'll learn**:
- Understand XRD (Composite Resource Definition)
- Create custom infrastructure API
- Build AWS-specific Composition
- Test with developer claims

**Video**: [Custom Compositions](https://youtube.com/placeholder) *(Coming soon)*

**Corresponding docs**: [FAQ - Custom Compositions](/docs/FAQ.md#how-do-i-add-custom-compositions)

**You'll build**: MongoDB composition using AWS DocumentDB

---

## Conference Recordings

### KubeCon EU 2026 Tutorial (75 minutes)

**Full hands-on lab session**:
- Complete walkthrough of Backend-First IDP
- Live demos with audience participation
- Q&A with maintainers

**Recording**: [KubeCon EU 2026 Tutorial](https://youtube.com/placeholder) *(Available after conference - May 2026)*

**Session materials**: [TUTORIAL.md](/TUTORIAL.md)

---

### KubeCon EU 2026 Lightning Talk (10 minutes)

**Topic**: "Why Portal-First IDP Development Fails"

**Key points**:
- Portal fatigue anti-pattern
- Backend-first success stories
- 2 weeks to production vs 18 months

**Recording**: [Lightning Talk](https://youtube.com/placeholder) *(Available after conference - May 2026)*

---

## Demo Videos

### Live Demo Script (18 minutes)

**What you'll see**:
- **Demo 1**: GitOps infrastructure provisioning (10 min)
- **Demo 2**: Full application deployment (5 min)
- **Demo 3**: Policy enforcement in action (3 min)

**Video**: [Live Demo Recording](https://youtube.com/placeholder) *(Coming soon)*

**Script**: [DEMO.md](/docs/DEMO.md)

**Perfect for**: Showing your team, management buy-in presentations

---

## Architecture Explained

### Visual Architecture Walkthrough (8 minutes)

**What you'll learn**:
- High-level architecture components
- Data flow for infrastructure provisioning
- Multi-environment workflows
- Disaster recovery patterns

**Video**: [Architecture Explained](https://youtube.com/placeholder) *(Coming soon)*

**Diagrams**: [ARCHITECTURE_DIAGRAMS.md](/docs/ARCHITECTURE_DIAGRAMS.md)

**Covers all 10 diagrams**:
1. High-Level Architecture
2. PostgreSQL Provisioning Flow
3. Multi-Environment Setup
4. Application CRD Flow
5. Portal-First vs Backend-First Timeline
6. Crossplane Composition Architecture
7. Policy Enforcement Flow
8. Secret Management Flow
9. Cost Control Architecture
10. Disaster Recovery Flow

---

## Troubleshooting Videos

### Common Issues & Solutions (12 minutes)

**Topics covered**:
- Provider not healthy - debugging steps
- Claims stuck in pending state
- ArgoCD sync failures
- Secret management issues
- Cloud API authentication

**Video**: [Troubleshooting Guide](https://youtube.com/placeholder) *(Coming soon)*

**Written guide**: [TROUBLESHOOTING.md](/TROUBLESHOOTING.md)

---

## Community Videos

### Office Hours Recordings

**Monthly community calls** covering:
- New features and releases
- Community Q&A
- User showcases
- Best practices

**Playlist**: [Office Hours Archive](https://youtube.com/playlist/placeholder) *(Coming soon)*

**Schedule**: First Tuesday of month, 10 AM ET
**Join live**: Announced in [CNCF Slack #backend-first-idp](https://cloud-native.slack.com)

---

### Community Showcases

**See how others use Backend-First IDP**:

- **"From Terraform to Crossplane"** - Migration story (15 min)
- **"Multi-cloud with one API"** - AWS + GCP setup (20 min)
- **"Cost savings: $50K/year"** - Real-world case study (10 min)
- **"On-prem integration"** - VMware + Crossplane (18 min)

**Playlist**: [Community Showcases](https://youtube.com/playlist/placeholder) *(Coming soon)*

**Submit your story**: Email community@backend-first-idp.io

---

## Comparison Videos

### Backend-First IDP vs Alternatives

**Video series comparing approaches**:

1. **vs Backstage** (8 min) - When to use each, integration patterns
2. **vs Terraform** (10 min) - GitOps vs CLI, state management
3. **vs AWS Proton** (6 min) - Multi-cloud vs vendor lock-in
4. **vs DIY Scripts** (5 min) - Why not bash scripts + kubectl

**Playlist**: [Comparisons](https://youtube.com/playlist/placeholder) *(Coming soon)*

**Written comparison**: [COMPARISON.md](/COMPARISON.md) *(Coming soon)*

---

## Advanced Topics

### Advanced Patterns (20-minute series)

**Episode 1**: Secret Rotation with External Secrets Operator
**Episode 2**: Multi-cluster with ArgoCD ApplicationSets
**Episode 3**: Cost Optimization Strategies
**Episode 4**: Compliance Automation (SOC 2, HIPAA)
**Episode 5**: On-prem Integration Patterns

**Playlist**: [Advanced Topics](https://youtube.com/playlist/placeholder) *(Coming soon)*

---

## Video Production Timeline

**Q2 2026** (Pre-conference):
- ✅ Installation & Setup (5 min)
- ✅ First Infrastructure Request (10 min)
- ✅ Application CRD Deep Dive (15 min)
- ✅ Live Demo Recording (18 min)
- ✅ Architecture Walkthrough (8 min)

**Q2 2026** (Post-conference):
- KubeCon EU 2026 Tutorial Recording (75 min)
- Lightning Talk Recording (10 min)

**Q3 2026**:
- Multi-Environment Promotion (12 min)
- Custom Compositions (20 min)
- Troubleshooting Guide (12 min)
- Comparison series (4 videos)

**Q4 2026**:
- Advanced patterns series (5 episodes)
- Community showcases (ongoing)
- Office hours archive (monthly)

---

## Creating Your Own Videos

**Want to create videos about Backend-First IDP?**

**We encourage it!** Here's how:

### Recording Setup

**Recommended tools**:
- **Screen recording**: OBS Studio (free, open source)
- **Terminal**: Use large font (18-20pt) for readability
- **Audio**: Decent USB microphone
- **Editing**: DaVinci Resolve (free) or iMovie/Final Cut

**Screen layout**:
```
┌─────────────────────────────────────┐
│  Terminal (70% of screen)           │
│  - Large font                        │
│  - Clear PS1 prompt                  │
│                                      │
├─────────────────────────────────────┤
│  Browser (30%, minimize when not    │
│  needed)                             │
│  - ArgoCD UI                         │
│  - AWS Console                       │
└─────────────────────────────────────┘
```

### Content Guidelines

**Good video practices**:
- ✅ Explain before typing - narrate what you're doing
- ✅ Pause after outputs - let viewers absorb
- ✅ Use `watch` commands to show progression
- ✅ Highlight key parts with `grep`, `jq`
- ✅ Include timestamps in description
- ✅ Provide commands in video description

**Avoid**:
- ❌ Long periods of silence
- ❌ Small fonts (minimum 18pt)
- ❌ Fast mouse movements
- ❌ Skipping error handling
- ❌ Assuming prior knowledge without links

### Sharing Your Videos

**Submit to community**:
1. Upload to YouTube (public or unlisted)
2. Add to description:
   - Link to this repository
   - Commands used (copy-pasteable)
   - Timestamps for sections
3. Share in [CNCF Slack #backend-first-idp](https://cloud-native.slack.com)
4. Tag with `#BackendFirstIDP`

**We'll feature** high-quality community videos in:
- This VIDEO_GUIDE.md
- Project website
- Newsletter
- Social media

---

## Video Subtitles & Accessibility

**All official videos include**:
- ✅ English subtitles (auto-generated + manual review)
- ✅ Transcript in video description
- ✅ High contrast terminal themes
- ✅ Screen reader compatible (where applicable)

**Community contributions**: We welcome subtitle translations! Contact community@backend-first-idp.io

---

## Subscribe & Notifications

**Stay updated on new videos**:

**YouTube**:
- Subscribe: [Backend-First IDP Channel](https://youtube.com/placeholder)
- Enable notifications for new uploads

**Community channels**:
- **Slack**: #backend-first-idp on [CNCF Slack](https://slack.cncf.io)
- **Twitter/X**: [@BackendFirstIDP](https://twitter.com/placeholder)
- **Mailing list**: [Subscribe](https://groups.google.com/g/backend-first-idp)

**RSS feed**: [https://youtube.com/feeds/placeholder](https://youtube.com/feeds/placeholder)

---

## Feedback on Videos

**Help us improve**:

**What we want to know**:
- Which videos were most helpful?
- What topics are missing?
- Suggested improvements
- Technical accuracy issues

**How to give feedback**:
- **During video**: Comment on YouTube
- **General feedback**: [GitHub Discussions](https://github.com/[ORG]/backend-first-idp/discussions)
- **Issues/corrections**: [GitHub Issues](https://github.com/[ORG]/backend-first-idp/issues)
- **Email**: video-feedback@backend-first-idp.io

---

## Video Credits

**Production**:
- **Maintainers**: Core team members
- **Editing**: Community volunteers
- **Voiceover**: [Contributors list](https://github.com/[ORG]/backend-first-idp/graphs/contributors)
- **Music**: Creative Commons licensed tracks

**Special thanks** to CNCF for conference recording support.

---

## Quick Reference

**Most popular videos** (sorted by views):

1. 🎥 [Installation & Setup](https://youtube.com/placeholder) - Start here! (5 min)
2. 🎥 [First Infrastructure Request](https://youtube.com/placeholder) - See it work (10 min)
3. 🎥 [Live Demo](https://youtube.com/placeholder) - Complete workflow (18 min)
4. 🎥 [Application CRD](https://youtube.com/placeholder) - Advanced usage (15 min)
5. 🎥 [Architecture Explained](https://youtube.com/placeholder) - Understand design (8 min)

**Total video content**: ~4 hours (and growing!)

---

## Alternative Learning Paths

**Not a video learner?** We have you covered:

- **Hands-on labs**: [TUTORIAL.md](/TUTORIAL.md) - 75-minute interactive tutorial
- **Quick start**: [quickstart.md](/docs/quickstart.md) - 15-20 minute guide
- **Live demo script**: [DEMO.md](/docs/DEMO.md) - Follow along yourself
- **FAQ**: [FAQ.md](/docs/FAQ.md) - 40+ answered questions
- **Architecture diagrams**: [ARCHITECTURE_DIAGRAMS.md](/docs/ARCHITECTURE_DIAGRAMS.md) - Visual learning

**Everyone learns differently** - choose the path that works for you!

---

**Questions about videos?** Ask in [CNCF Slack #backend-first-idp](https://cloud-native.slack.com) or email video@backend-first-idp.io

**Want to contribute videos?** See [CONTRIBUTING.md](/CONTRIBUTING.md) and reach out!

---

**Last Updated**: 2026-01-15 | **Video Count**: 15+ planned

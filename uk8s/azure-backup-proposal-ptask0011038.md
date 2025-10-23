# Azure Backup for UK8S Platform Recovery - Proposal

**PTASK**: PTASK0011038
**Author**: DevOps Engineering / UK8S Platform Team
**Date**: 2025-10-21
**Version**: 1.0

---

## Executive Summary

This document evaluates Azure Backup as a recovery mechanism for the UK8S shared AKS platform and provides recommendations on its role in platform recovery strategy. Based on comprehensive analysis of capabilities, costs, and platform requirements, **Azure Backup is recommended as a complementary solution for specific recovery scenarios, not as the primary platform recovery mechanism**.

**Key Recommendations**:
- GitOps and Infrastructure as Code should remain the primary recovery mechanism
- Azure Backup recommended for tenant namespace protection (selective adoption)
- Velero recommended as cost-effective alternative for specific use cases
- Estimated cost: £50-95/month plus storage for selective namespace protection (assuming 5-10 critical tenant namespaces)

---

## 1. Background & Context

### 1.1 UK8S Platform Overview
The UK8S AKS platform operates as a shared, multi-tenant managed service supporting multiple application teams within the organization. Each team operates within isolated namespaces with dedicated resources, while the platform team maintains the underlying infrastructure, security, and compliance.

### 1.2 Recovery Requirements
Platform recovery scenarios fall into three categories:

1. **Infrastructure Recovery**: Cluster control plane, node pools, networking, core infrastructure
2. **Platform Services Recovery**: Shared services (monitoring, logging, ingress, service mesh)
3. **Tenant Application Recovery**: Individual team namespaces, workloads, and persistent data

---

## 2. Azure Backup for AKS - Understanding the Opportunity

### 2.1 What Azure Backup Offers

Azure Backup for AKS is a cloud-native backup solution providing:

**Core Capabilities**:
- Scheduled backups of cluster state and application data
- Granular control: namespace-level or full-cluster backups
- Dual-tier storage: Operational Tier (snapshots) and Vault Tier (compliance blobs)
- Cross-region disaster recovery (Vault Tier only)
- Application-consistent snapshots using backup hooks
- Integration with Azure Backup Center for unified governance

**Technical Architecture**:
```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Backup for AKS                     │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
  ┌───────────────┐   ┌──────────────┐   ┌──────────────┐
  │ Backup Vault  │   │   Extension  │   │ Trusted      │
  │  (Regional)   │◄──┤  (In-Cluster)│   │ Access       │
  └───────────────┘   └──────────────┘   └──────────────┘
          │
          ├─► Operational Tier (Snapshots - Fast Recovery)
          └─► Vault Tier (Blobs - Compliance/Cross-Region)
```

### 2.2 What Azure Backup Can Protect

**Supported**:
- Kubernetes resources (Deployments, Services, ConfigMaps, Secrets)
- Persistent Volumes using Azure Disk CSI driver (≤ 1TB for Vault Tier)
- Namespace-level or cluster-wide configurations
- Application state with custom backup hooks

**Not Supported**:
- Azure Files or Blob-based persistent volumes
- Cross-subscription restore (Operational Tier)
- Resources outside the cluster (Azure resources, networking)
- Automatic resource replacement (requires manual deletion before restore)

### 2.3 Recovery Characteristics

**Recovery Point Objective (RPO)**:
- Operational Tier: Minimum 4-hour intervals
- Vault Tier: Daily snapshots

**Recovery Time Objective (RTO)**:
- Operational Tier: Fast (minutes to tens of minutes for disk snapshots)
- Vault Tier: Slower (blob-based restoration)
- Cross-region restore: Significantly longer (regional failover scenario)

**Limitations**:
- Vault and AKS cluster must be in same region and subscription
- No automated deletion of conflicting resources during restore
- Restore hooks not executed for same-namespace restores

---

## 3. Cost Assessment

### 3.1 Azure Backup Pricing Model

**Protected Instance Charges**:
- **£10 per namespace per month** for each namespace configured for backup
- Charged regardless of backup size or frequency

**Storage Charges**:
- **Blob storage**: Standard blob storage rates for Vault Tier backups
- **Disk snapshots**: Incremental snapshots charged at standard snapshot rates
- **Snapshot storage**: Billed per GB-month based on incremental changes

**Example Cost Scenarios for UK8S**:

| Scenario | Namespaces Protected | Monthly Base Cost | Est. Storage Cost* | Total Est. Monthly |
|----------|---------------------|-------------------|-------------------|-------------------|
| Minimal (Critical Tenants) | 5 | £50 | £15-40 | £65-90 |
| Moderate (All Tenants) | 20 | £200 | £80-160 | £280-360 |
| Full Platform | 40+ | £400+ | £160-400 | £560-800+ |

*Storage costs vary based on PV size, change rate, retention policy, and snapshot frequency

### 3.2 Alternative Solution Costs

**Velero (Open Source)**:
- **License cost**: £0 (Apache 2.0 license)
- **Storage cost**: Blob storage only (~£15-80/month depending on retention)
- **Operational cost**: Staff time for setup, maintenance, monitoring
- **Support**: Community-based (no guaranteed SLA)

**Kasten K10 (Commercial)**:
- **License cost**: Vendor-specific (typically per-node or per-namespace)
- **Advanced features**: Enterprise support, automated DR, multi-cloud
- **Cost range**: Estimated £4,000-16,000+ annually for enterprise deployment

**GitOps + IaC (Current Approach)**:
- **License cost**: £0 (using Flux, ARM templates/Bicep, etc.)
- **Storage cost**: Minimal (Git repository storage)
- **Operational benefit**: Declarative, version-controlled, auditable
- **Limitation**: Does not protect persistent data

---

## 4. Evaluation: Azure Backup Role in UK8S Platform Recovery

### 4.1 Recovery Scenario Analysis

| Recovery Scenario | Azure Backup Fit | Recommended Approach | Rationale |
|------------------|------------------|---------------------|-----------|
| **Cluster Infrastructure Failure** | Poor | GitOps + ARM templates | Infrastructure is code-defined; backup doesn't restore control plane, networking, or Azure resources |
| **Platform Services Failure** | Moderate | GitOps + Helm | Platform services are declaratively defined; faster to redeploy than restore |
| **Tenant Namespace Deletion** | Good | Azure Backup or Velero | Namespace-level granular restore valuable for accidental deletions |
| **Persistent Volume Data Loss** | Excellent | Azure Backup | Protects Azure Disk PVs with point-in-time recovery |
| **Regional Disaster** | Moderate | Multi-region architecture | Backup supports cross-region restore (Vault Tier only); DR architecture preferred |
| **Configuration Drift** | Poor | GitOps reconciliation | Git-based source of truth handles drift better than backup restore |
| **Compliance Audit** | Good | Azure Backup (Vault Tier) | Provides point-in-time compliance evidence and audit trail |

### 4.2 Strengths for UK8S Platform

1. **Tenant Data Protection**: Excellent for protecting tenant persistent volume data (databases, file storage)
2. **Granular Recovery**: Namespace-level restore aligns with multi-tenant isolation model
3. **Azure Native Integration**: Seamless integration with Azure ecosystem and Backup Center
4. **Compliance Support**: Vault Tier provides long-term retention for regulatory requirements
5. **Self-Service Potential**: Can enable tenant teams to manage their own namespace backups

### 4.3 Limitations for UK8S Platform

1. **Infrastructure Scope Gap**: Does not protect cluster infrastructure, networking, or Azure resources
2. **Cost at Scale**: £10/namespace becomes expensive with 30-50 tenant namespaces
3. **Platform Services Mismatch**: GitOps redeploy faster than backup restore for stateless services
4. **Storage Type Limitation**: Only supports Azure Disk CSI; no Azure Files or blob support
5. **Cross-Subscription Constraint**: Cannot restore across subscriptions (limits multi-cluster strategies)
6. **Manual Conflict Resolution**: Requires manual resource deletion before restore

---

## 5. Proposal: Recommended Backup Strategy for UK8S

### 5.1 Hybrid Recovery Architecture

**Primary Recovery Mechanism**: **GitOps + Infrastructure as Code**
- All platform infrastructure defined in ARM templates/Bicep
- All platform services and configurations managed via Flux GitOps
- Git repository serves as source of truth for cluster state
- Automated reconciliation prevents configuration drift

**Complementary Backup Mechanisms**: **Selective Azure Backup + Velero**

### 5.2 Recommended Implementation

#### Tier 1: Critical Tenant Namespaces with Persistent Data
**Solution**: Azure Backup
**Scope**: 5-10 critical tenant namespaces with stateful applications (databases, file storage)
**Cost**: ~£50-95/month + storage
**Justification**:
- Business-critical data requires enterprise-grade backup
- Azure-native integration simplifies management
- Cross-region DR capability available if needed
- Compliance audit trail for regulated workloads

**Configuration**:
- Daily backups to Vault Tier (compliance retention)
- 4-hour RPO on Operational Tier (fast recovery)
- 30-day retention for Operational Tier
- 1-year retention for Vault Tier (compliance)

#### Tier 2: Platform Services & Non-Critical Tenants
**Solution**: GitOps + Velero (Optional)
**Scope**: Platform namespaces (ingress, monitoring, logging) and non-critical tenant apps
**Cost**: £0 (GitOps) or ~£40-80/month (Velero with blob storage)
**Justification**:
- GitOps provides declarative redeploy faster than backup restore
- Velero offers cost-effective backup for non-critical workloads
- Community support acceptable for non-critical applications

**Configuration**:
- GitOps: Continuous reconciliation via Flux
- Velero: Daily backups, 14-day retention, blob storage backend

#### Tier 3: Cluster Infrastructure
**Solution**: Infrastructure as Code (ARM templates/Bicep)
**Scope**: AKS cluster, node pools, networking, Azure resources
**Cost**: £0 (existing practice)
**Justification**:
- IaC enables rapid cluster recreation
- Version-controlled infrastructure changes
- Backup does not cover infrastructure layer

**Configuration**:
- All infrastructure defined in Git-managed IaC
- ARM templates (and compiled Bicep files) stored in Git with version history
- Automated cluster provisioning pipelines

### 5.3 Decision Matrix for Teams

Provide tenant teams with guidance on selecting backup approach:

```
┌─────────────────────────────────────────────────────────────┐
│          Backup Solution Selection for Tenants             │
└─────────────────────────────────────────────────────────────┘

  Has Persistent                    Business Impact
  Volume Data?                      if Lost?
       │                                  │
       │                                  │
  ┌────▼─────┐                      ┌────▼─────┐
  │   YES    │                      │  CRITICAL│
  └────┬─────┘                      └────┬─────┘
       │                                  │
       └────────────┬─────────────────────┘
                    ▼
            ┌──────────────┐
            │ Azure Backup │ ← Recommended
            │  (£10/month) │
            └──────────────┘

  ┌─────────────┐                   ┌──────────────┐
  │   NO PV     │                   │ LOW/MODERATE │
  │   (Stateless)│                   │   IMPACT     │
  └─────┬───────┘                   └──────┬───────┘
        │                                  │
        └────────────┬─────────────────────┘
                     ▼
             ┌──────────────┐
             │   GitOps +   │ ← Recommended
             │ Velero (Opt) │
             └──────────────┘
```

---

## 6. Risks & Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Backup costs exceed budget as platform scales | Medium | High | Implement selective backup strategy; use Velero for non-critical workloads |
| RTO not met during actual disaster | High | Low | Regular restore testing; maintain GitOps as primary recovery path |
| Backup extension introduces cluster instability | Medium | Low | Deploy to non-prod first; monitor extension resource usage |
| Teams over-rely on backup instead of GitOps | Medium | Medium | Education and documentation emphasizing GitOps-first approach |
| Storage costs grow unexpectedly | Low | Medium | Implement retention policies; monitor snapshot growth; regular cleanup |

---

## 7. Success Criteria

**Backup is considered successful for UK8S if**:
1. Critical tenant data can be restored within defined RTO (< 1 hour for Operational Tier)
2. Backup costs remain within budget allocation (< £160/month initially)
3. Backup operations do not impact cluster performance or stability
4. Restore testing demonstrates 95%+ success rate
5. GitOps remains primary recovery mechanism (backup as safety net)

---

## 8. Conclusion & Final Recommendation

### 8.1 Summary

Azure Backup for AKS provides valuable capabilities for protecting tenant persistent data and supporting compliance requirements. However, it is **not a replacement for GitOps and Infrastructure as Code** as the primary platform recovery mechanism.

### 8.2 Recommended Role for Azure Backup

**Azure Backup should play a LIMITED, COMPLEMENTARY role** in UK8S platform recovery:

**Recommended Uses**:
- Protecting persistent volume data for critical tenant applications
- Providing point-in-time recovery for accidental namespace deletions
- Supporting compliance and audit requirements with long-term retention
- Enabling cross-region disaster recovery for specific high-value workloads

**Not Recommended For**:
- Platform infrastructure recovery (use ARM templates/Bicep)
- Platform services recovery (use GitOps/Flux)
- Cost-sensitive or non-critical tenant workloads (use Velero or GitOps)
- Primary disaster recovery strategy (use multi-region architecture)

### 8.3 Financial Justification

**Estimated Annual Cost**: £575 - £1,150 per year (assuming 5-10 critical namespaces)

**Value Proposition**:
- Protects high-value tenant data that cannot be easily recreated
- Reduces recovery time for data loss scenarios
- Provides compliance evidence for regulated workloads
- Enables tenant self-service backup capabilities

**Cost-Benefit Assessment**: **POSITIVE** for selective adoption of critical workloads

### 8.4 Next Steps

1. **Approve pilot program** for Azure Backup on 2-3 critical tenant namespaces
2. **Deploy Velero** as cost-effective backup for non-critical workloads
3. **Document tenant guidance** for backup solution selection
4. **Establish cost tracking** and chargeback model for backup services
5. **Review quarterly** to assess effectiveness and adjust strategy

---

## 9. References

- [Azure Backup for AKS Overview](https://learn.microsoft.com/en-us/azure/backup/azure-kubernetes-service-backup-overview)
- [AKS Backup and Recovery Architecture](https://learn.microsoft.com/en-us/azure/architecture/operator-guides/aks/aks-backup-and-recovery)
- [Azure Backup Pricing](https://azure.microsoft.com/en-us/pricing/details/backup/)
- [Velero Documentation](https://velero.io/docs/)
- [GitOps with Flux](https://fluxcd.io/docs/)

---

**Document Status**: Ready for Review
**Approvers**: UK8S Product Owner, Platform Team Lead, Finance
**Next Review Date**: 2025-11-21 (Post-Pilot)

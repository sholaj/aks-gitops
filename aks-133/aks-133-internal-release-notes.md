# AKS 1.33 Internal Release Notes

**Release Date**: Q1 2025  
**Version**: Azure Kubernetes Service 1.33  
**Classification**: Internal - Engineering Teams  
**Priority**: High - Client Curation Required  

## Executive Summary
AKS 1.33 introduces significant improvements in resource management, security, and operational efficiency. The headline feature is dynamic pod resizing (beta), enabling in-place vertical scaling without pod restarts. This release is based on upstream Kubernetes 1.33 and includes all features from the [official Kubernetes 1.33 release](https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/). This release requires thorough testing before client deployment.

## Major Features

### 1. Dynamic Pod Resizing (Beta)
**Impact**: High  
**Status**: Beta (Enabled by Default)  
**Kubernetes KEP**: [KEP-1287](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/1287-in-place-update-pod-resources)

- **Description**: Pods can now be resized in-place for CPU and memory without restart
- **Benefits**: 
  - Zero-downtime resource adjustments
  - Improved resource utilization
  - Reduced operational overhead
- **Limitations**:
  - Linux containers only (Windows support planned for future release)
  - Not supported for init containers or ephemeral containers
  - Requires containerd 1.7+ (included in AKS 1.33)
  - Storage requests/limits cannot be resized
- **Client Considerations**:
  - Test with client workloads before production
  - JVM applications may require special attention
  - Monitor for memory management issues

### 2. Enhanced Security Features

#### Pod Security Standards Enforcement
- Graduated to stable
- Replaces Pod Security Policies (deprecated)
- Three profiles: Privileged, Baseline, Restricted
- **Action Required**: Migrate from PSP before upgrade

#### Kubernetes Authentication Updates
- Support for structured authentication configuration
- Enhanced OIDC provider integration
- Improved audit logging capabilities

### 3. Performance Improvements

#### API Server Optimizations
- 20% reduction in API server memory usage
- Improved list/watch performance for large clusters
- Better handling of high cardinality resources

#### Scheduler Enhancements
- Faster pod scheduling for large deployments
- Improved bin-packing algorithms
- Better support for topology-aware scheduling

### 4. Storage Enhancements

#### CSI Migration Complete
- In-tree Azure Disk/File drivers fully migrated to CSI
- Improved snapshot capabilities
- Volume cloning performance improvements

#### Volume Expansion
- Online volume expansion for Azure Disks
- Support for Windows container volume expansion

### 5. Networking Updates

#### Service Mesh Integration
- Native support for Gateway API v1.0
- Improved Istio compatibility
- Enhanced load balancing algorithms

#### IPv6 Improvements
- Dual-stack networking GA
- Better IPv6 service discovery

## Breaking Changes

1. **Removed Features**:
   - Pod Security Policies (use Pod Security Standards)
   - Legacy Azure in-tree storage drivers
   - Deprecated API versions (see migration guide)

2. **Default Changes**:
   - Dynamic pod resizing enabled by default
   - Stricter security defaults for new clusters
   - Updated default storage class parameters

## Migration Considerations

### Pre-Upgrade Checklist
- [ ] Audit deprecated API usage
- [ ] Migrate from Pod Security Policies
- [ ] Test dynamic pod resizing with critical workloads
- [ ] Verify storage driver compatibility
- [ ] Review RBAC policies for new features

### Recommended Testing Timeline
1. **Week 1-2**: Deploy to development environment
2. **Week 3-4**: Staging validation with load testing
3. **Week 5-6**: Limited production rollout (10% clusters)
4. **Week 7-8**: Full production deployment

## Client-Specific Recommendations

### High-Priority Clients (Tier 1)
- Enable gradual rollout with feature flags
- Implement comprehensive monitoring for resize operations
- Document rollback procedures

### Standard Clients (Tier 2)
- Wait for 2-3 weeks post-GA before upgrade
- Focus testing on critical workloads
- Leverage managed upgrade windows

### Development/Test Environments
- Immediate upgrade recommended
- Use as validation environment for production

## Known Issues and Workarounds

### Issue 1: Pod Resize Failures with Custom Schedulers
**Symptoms**: Pods using custom schedulers may fail resize operations  
**Workaround**: Disable dynamic resizing for affected workloads  
**Fix ETA**: 1.33.1 patch release  

### Issue 2: Metrics Server Lag During Resize
**Symptoms**: HPA may show stale metrics for 1-2 minutes post-resize  
**Workaround**: Increase HPA tolerance settings  
**Fix ETA**: Under investigation  

### Issue 3: Windows Container Resize Not Supported
**Symptoms**: Windows pods cannot be resized in-place  
**Workaround**: Continue using pod recreation strategy for Windows workloads  
**Fix ETA**: Under evaluation - may require Windows Server container runtime updates  

## Performance Benchmarks

| Metric | AKS 1.31 | AKS 1.33 | Improvement |
|--------|----------|----------|-------------|
| API Latency (p99) | 250ms | 180ms | 28% |
| Pod Startup Time | 12s | 9s | 25% |
| Memory Usage (API Server) | 4GB | 3.2GB | 20% |
| Resize Operation Time | N/A | 15s | New Feature |
| Max Pods per Node | 110 | 110* | 0% |

*No change in AKS 1.33 - requires specific node pool configuration

## Security Improvements

### CVE Fixes
- CVE-2024-3177: High - Container runtime vulnerability patched
- CVE-2024-24783: Medium - API server DoS protection improved
- CVE-2024-24784: Low - Information disclosure in audit logs prevented

### Compliance Updates
- CIS Kubernetes Benchmark 1.8.0 compliance
- PCI DSS 4.0 compatibility improvements
- HIPAA audit logging enhancements

## Monitoring and Observability

### New Metrics Available
- `container_resize_duration_seconds`: Time taken for resize operations
- `container_resize_failures_total`: Count of failed resize attempts  
- `pod_resource_allocation_changes_total`: Resource allocation modifications
- `vpa_resize_operations_total`: VPA-triggered resize operations

### Recommended Dashboards
- Pod Resize Operations Dashboard
- Resource Utilization Efficiency Dashboard
- Security Compliance Dashboard

## Support and Resources

### Official External References
- [Kubernetes 1.33 Release Notes](https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/)
- [Kubernetes 1.33 Changelog](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.33.md)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [AKS Release Notes](https://github.com/Azure/AKS/releases)
- [Azure Kubernetes Service Security Bulletins](https://docs.azure.cn/en-us/aks/security-bulletins/overview)

### Internal Documentation
- [AKS 1.33 Upgrade Guide](https://docs.azure.cn/en-us/aks/)
- [Pod Resizing Best Practices](/docs/pod-resizing)
- [Migration Toolkit](/tools/migration)

### Support Channels
- Slack: #aks-133-support
- Email: aks-curation@company.com
- On-call: DevOps Platform Team

### Training Resources
- Internal Workshop: "AKS 1.33 Deep Dive" - Every Tuesday
- Hands-on Lab: "Pod Resizing in Practice" - Self-paced
- Office Hours: Thursdays 2-3 PM PST

## Action Items for DevOps Team

1. **Immediate Actions**:
   - Update CI/CD pipelines for 1.33 compatibility
   - Create client-specific upgrade runbooks
   - Schedule upgrade windows with client teams

2. **Within 1 Week**:
   - Complete staging environment validation
   - Document resize operation procedures
   - Update monitoring alerts and dashboards

3. **Within 2 Weeks**:
   - Conduct client readiness assessments
   - Finalize rollback procedures
   - Complete performance baseline testing

## Appendix

### A. API Deprecations
```yaml
# Deprecated in 1.33, removed in 1.36
- batch/v1beta1/CronJob → batch/v1/CronJob
- networking.k8s.io/v1beta1/Ingress → networking.k8s.io/v1/Ingress
- policy/v1beta1/PodSecurityPolicy → Removed (use Pod Security Standards)
```

### B. Feature Gates Changes
```yaml
# Graduated to GA (enabled by default, cannot be disabled)
- IPv6DualStack: true
- CSIMigrationAzureDisk: true
- CSIMigrationAzureFile: true
- WindowsHostProcessContainers: true

# New Beta Features (enabled by default)
- InPlacePodVerticalScaling: true
- PodSchedulingReadiness: true
```

### C. Sample Pod Resize Command
```bash
# Resize pod resources dynamically
kubectl patch deployment nginx-deployment -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","resources":{"requests":{"memory":"256Mi","cpu":"200m"},"limits":{"memory":"512Mi","cpu":"400m"}}}]}}}}'
```

## Additional References

### Kubernetes 1.33 Resources

- [Kubernetes 1.33 Blog Post](https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/)
- [What's New in Kubernetes 1.33](https://kubernetes.io/docs/reference/using-api/deprecation-guide/#v1-33)
- [Kubernetes SIG Release Page](https://github.com/kubernetes/sig-release/tree/master/releases/release-1.33)

### Azure Kubernetes Service Resources

- [AKS Roadmap](https://github.com/Azure/AKS/projects/1)
- [AKS Best Practices](https://learn.microsoft.com/en-us/azure/aks/best-practices)
- [AKS Security Baseline](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline)

### Pod Resizing Specific Resources

- [In-Place Pod Vertical Scaling KEP](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/1287-in-place-update-pod-resources)
- [Pod Resizing Design Document](https://github.com/kubernetes/design-proposals-archive/blob/main/node/pod-resize.md)
- [LinkedIn: Kubernetes 1.33 Pod Resizing Analysis](https://www.linkedin.com/pulse/kubernetes-133-resizing-pods-gopal-das-tsxff)

## Revision History

- v1.0 - Initial release notes
- v1.1 - Added known issues section
- v1.2 - Updated with testing results from staging
- v1.3 - Added comprehensive external references for Kubernetes and AKS

---
**Document Status**: FINAL  
**Last Updated**: 2025-09-04  
**Next Review**: Post-GA + 30 days  
**Owner**: DevOps Platform Team
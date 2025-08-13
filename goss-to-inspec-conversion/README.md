# AKS Compliance Tests - InSpec Profile

This InSpec profile contains production-grade compliance and configuration tests for Azure Kubernetes Service (AKS) clusters. The tests have been converted from Goss format to InSpec and organized into logical control groups.

## Overview

This profile validates the security, compliance, and operational readiness of AKS clusters across multiple dimensions:

- **Cluster-Level Properties**: Kubernetes version, DNS, RBAC configuration
- **Workload Identity Setup**: OIDC issuer configuration for workload identity
- **GitOps Configuration**: Flux controllers and GitOps resource validation
- **AddOns**: Service mesh, cert-manager, external-dns, and other addon validation
- **Cost Analysis**: Cost monitoring and Azure Monitor integration
- **Security**: Private cluster, authentication, and security hardening validation
- **Logging Framework**: Logging infrastructure and configuration validation
- **UAMI Checks**: User Assigned Managed Identity validation
- **ARM Parameters**: Infrastructure-as-Code parameter validation

## Prerequisites

### Required Tools

- **InSpec**: Version 5.0 or higher
- **Azure CLI**: Authenticated with appropriate permissions
- **kubectl**: Configured with cluster access
- **jq**: For JSON processing in commands

### Azure Permissions

The executing identity needs the following Azure RBAC permissions:

- `Reader` on the AKS cluster resource group
- `Reader` on the User Assigned Managed Identity resource group
- `Azure Kubernetes Service Cluster User Role` on the AKS cluster

### Kubernetes Permissions

The kubectl context should have permissions to:

- List and describe pods, deployments, daemonsets
- Get custom resources (GitRepository, Kustomization, etc.)
- Access cluster-wide resources (ClusterIssuers, CRDs)

## Installation

1. Clone or download this InSpec profile
2. Install InSpec dependencies:

```bash
cd /path/to/aks-compliance-tests
inspec vendor
```

## Configuration

### Environment-Specific Input Files

The profile includes three pre-configured input files:

- `inputs/dev.yml` - Development environment
- `inputs/staging.yml` - Staging environment  
- `inputs/prod.yml` - Production environment

### Required Input Parameters

Update the input files with your environment-specific values:

```yaml
# Core AKS Configuration
resource_group: "your-aks-resource-group"
cluster_name: "your-aks-cluster-name"
kubernetes_version: "1.29.2"
dns_prefix: "your-dns-prefix"

# Identity Configuration
uami_resource_group: "your-identity-resource-group"
cert_mgr_managed_identity: "your-certmgr-identity"
extdns_managed_identity: "your-externaldns-identity"
extsecret_managed_identity: "your-externalsecrets-identity"

# Monitoring
log_analytics_workspace_id: "/subscriptions/.../workspaces/your-workspace"

# Service Mesh
istio_version: "1.20.2"

# GitOps Resources
gitrepository_name: "flux-system"
kustomization_name: "flux-system"
```

### Optional Configurations

Some controls can be enabled/disabled via input parameters:

```yaml
# Optional validations
check_http_routing: true          # Enable HTTP routing validation
validate_arm_parameters: false    # Enable ARM parameter validation
validate_variable_files: false    # Enable variable file validation
```

## Usage

### Basic Execution

Run all tests against a development environment:

```bash
inspec exec . --input-file=inputs/dev.yml
```

### Specific Control Groups

Run only security-related controls:

```bash
inspec exec . --input-file=inputs/prod.yml --controls=/security/
```

### Output Formats

Generate detailed reports:

```bash
# HTML report
inspec exec . --input-file=inputs/prod.yml --reporter html:aks-compliance-report.html

# JSON report for CI/CD integration
inspec exec . --input-file=inputs/prod.yml --reporter json:aks-compliance.json

# JUnit for test integration
inspec exec . --input-file=inputs/prod.yml --reporter junit:aks-compliance.xml
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
- name: Run AKS Compliance Tests
  run: |
    inspec exec aks-compliance-tests \
      --input-file=inputs/prod.yml \
      --reporter json:compliance-results.json \
      --chef-license=accept-silent
    
- name: Upload Compliance Report
  uses: actions/upload-artifact@v3
  with:
    name: aks-compliance-report
    path: compliance-results.json
```

### Azure DevOps Pipeline

```yaml
- task: Bash@3
  displayName: 'Run AKS Compliance Tests'
  inputs:
    targetType: 'inline'
    script: |
      inspec exec $(System.DefaultWorkingDirectory)/aks-compliance-tests \
        --input-file=inputs/$(Environment).yml \
        --reporter junit:compliance-results.xml \
        --chef-license=accept-silent
```

## Analysis and Improvements Report

### Issues Identified in Original `tobeconvert.rb`

The original monolithic control file had several critical issues that have been resolved:

1. **Incorrect InSpec Resource Usage**
   - **Issue**: Used incorrect resource names like `azurerm_aks_cluster` instead of proper Azure CLI commands
   - **Resolution**: Replaced with proper `az aks show` commands with specific query paths

2. **Monolithic Structure**
   - **Issue**: Single massive control with 28+ different test types mixed together
   - **Resolution**: Broke down into 12 focused control files with clear separation of concerns

3. **Missing Error Handling**
   - **Issue**: No conditional logic or error handling for environment differences
   - **Resolution**: Added `only_if` conditions and environment-specific logic

4. **Inconsistent Property Access**
   - **Issue**: Mixed property access patterns and incorrect syntax
   - **Resolution**: Standardized on Azure CLI query patterns with proper JMESPath expressions

5. **Missing Production Features**
   - **Issue**: No compliance framework tags, inconsistent impact ratings
   - **Resolution**: Added comprehensive NIST CSF, CIS, PCI DSS tags and appropriate impact ratings

### Improvements Implemented

1. **Proper Resource Testing**
   - Used Azure CLI commands with specific JMESPath queries
   - Added proper exit status and output validation
   - Implemented environment-specific node count validation

2. **Enhanced Security Validation**
   - Added node pool security profile checks (Secure Boot, vTPM)
   - Implemented encryption-at-host validation
   - Added Azure Linux OS verification
   - Enhanced pod identity exception handling

3. **Comprehensive Kubernetes Resource Validation**
   - Flux controller health checks with proper label selectors
   - External secrets synchronization status validation
   - Custom Resource Definition existence checks
   - Cluster issuer ready state validation

4. **Production-Ready Features**
   - Environment-aware testing (dev/staging/prod)
   - Conditional control execution
   - Comprehensive input validation
   - Proper error handling and graceful failures

5. **Improved Maintainability**
   - Helper library with utility methods
   - Consistent naming conventions
   - Comprehensive documentation
   - Modular control structure

### New Control Files Created

- **`10_node_pools.rb`**: Complete node pool security and configuration validation
- **`11_kubernetes_resources.rb`**: Comprehensive Kubernetes resource health checks
- **`12_file_validation.rb`**: File system and configuration validation

### Enhanced Existing Controls

- **`01_cluster_properties.rb`**: Added 7 new controls for network, autoscaling, and service mesh
- **`06_security.rb`**: Enhanced pod identity and Azure Policy validation
- **Input Files**: Updated all environment files with new parameters and proper structure

## Control Groups

### 01 - Cluster Properties
- **Controls**: 11 controls
- **Focus**: Kubernetes version, DNS prefix, RBAC, provisioning state, network configuration (CNI, Cilium), load balancer, KEDA, auto-upgrade, service mesh
- **Impact**: High (security and operational)

### 02 - Workload Identity
- **Controls**: 2 controls
- **Focus**: OIDC issuer configuration
- **Impact**: High (security)

### 03 - GitOps Configuration
- **Controls**: 9 controls
- **Focus**: Flux controllers, GitRepository, Kustomization sync
- **Impact**: High (operational)

### 04 - AddOns
- **Controls**: 10 controls
- **Focus**: cert-manager, external-dns, Istio, KEDA, maintenance
- **Impact**: Medium to High

### 05 - Cost Analysis
- **Controls**: 3 controls
- **Focus**: Cost monitoring, Azure Monitor integration
- **Impact**: Medium (financial governance)

### 06 - Security
- **Controls**: 6 controls
- **Focus**: Private cluster, authentication, logging, hardening
- **Impact**: High (security)

### 07 - Logging Framework
- **Controls**: 6 controls
- **Focus**: Logging infrastructure, DaemonSets, configuration
- **Impact**: Medium (observability)

### 08 - UAMI Checks
- **Controls**: 6 controls
- **Focus**: Managed identities and federated credentials
- **Impact**: High (security)

### 09 - ARM Parameters
- **Controls**: 3 controls
- **Focus**: Infrastructure-as-Code validation
- **Impact**: Medium (governance)

### 10 - Node Pools
- **Controls**: 7 controls
- **Focus**: Node pool security, autoscaling, OS configuration, encryption
- **Impact**: High (security and performance)

### 11 - Kubernetes Resources
- **Controls**: 14 controls
- **Focus**: Pod health, Flux controllers, cert-manager, external-dns, logging, CRDs, external secrets
- **Impact**: High (operational)

### 12 - File Validation
- **Controls**: 7 controls
- **Focus**: ARM templates, variable files, system configurations, permissions
- **Impact**: Medium (governance and security)

## Compliance Framework Mappings

This profile includes tags for major compliance frameworks:

- **NIST Cybersecurity Framework**: PR.AC-1, PR.DS-2, DE.CM-1, etc.
- **CIS Kubernetes Benchmark**: 1.1.1, 1.2.1, 1.2.2, 1.2.3
- **PCI DSS**: 1.2, 7.1, 8.1
- **Custom Tags**: azure, kubernetes, security, gitops, etc.

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```bash
   # Verify Azure CLI authentication
   az account show
   
   # Verify kubectl context
   kubectl config current-context
   ```

2. **Permission Denied**
   ```bash
   # Check AKS credentials
   az aks get-credentials --resource-group <rg> --name <cluster>
   
   # Verify Azure permissions
   az role assignment list --assignee $(az account show --query user.name -o tsv)
   ```

3. **Missing Dependencies**
   ```bash
   # Install jq if missing
   sudo apt-get install jq  # Ubuntu/Debian
   brew install jq          # macOS
   ```

4. **Timeout Issues**
   ```bash
   # Increase kubectl timeout for slow operations
   export KUBECTL_TIMEOUT=60s
   ```

### Control Debugging

Enable detailed output for specific control debugging:

```bash
inspec exec . --input-file=inputs/dev.yml --log-level=debug --controls=cluster-properties-01
```

### Custom Configuration

For environments requiring custom configuration, create a new input file:

```bash
cp inputs/prod.yml inputs/custom.yml
# Edit custom.yml with your specific values
inspec exec . --input-file=inputs/custom.yml
```

## Development and Customization

### Adding New Controls

1. Create or edit control files in the `controls/` directory
2. Follow the existing naming convention: `XX_category_name.rb`
3. Use appropriate impact levels (0.1-1.0)
4. Include relevant tags for compliance frameworks
5. Add input parameters to `inspec.yml` if needed

### Helper Library

The `libraries/aks_helper.rb` provides utility methods for common operations:

```ruby
# Example usage in controls
describe "Custom validation" do
  it "should validate pod health" do
    expect(AKSHelper.check_pod_status('default', 'app=myapp')).to be true
  end
end
```

### Testing Control Changes

```bash
# Syntax check
inspec check .

# Test specific controls
inspec exec . --controls=your-new-control --input-file=inputs/dev.yml
```

## Contributing

1. Follow InSpec best practices
2. Include appropriate compliance framework tags
3. Test thoroughly across environments
4. Update documentation and input files
5. Validate syntax with `inspec check`

## License

This InSpec profile is licensed under the Apache License 2.0.

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review InSpec documentation: https://docs.chef.io/inspec/
3. Validate Azure CLI and kubectl configuration
4. Check Azure RBAC permissions
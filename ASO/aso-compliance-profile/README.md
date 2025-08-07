# ASO Infrastructure Compliance Profile

A comprehensive InSpec compliance testing profile for Azure Service Operator (ASO) provisioned infrastructure. This profile validates security, governance, and compliance requirements across multiple Azure services and environments.

## Table of Contents

- [Overview](#overview)
- [Supported Resources](#supported-resources)
- [Compliance Frameworks](#compliance-frameworks)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Local Execution](#local-execution)
  - [GitLab CI/CD Integration](#gitlab-cicd-integration)
- [Test Controls](#test-controls)
- [Environment Variables](#environment-variables)
- [Interpreting Results](#interpreting-results)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

This InSpec profile provides comprehensive compliance testing for Azure infrastructure provisioned using Azure Service Operator (ASO). It covers security best practices, governance requirements, and compliance with industry standards including CIS Azure Foundations Benchmark, Azure Security Benchmark, and NIST Cybersecurity Framework.

### Key Features

- **Multi-Environment Support**: Different compliance requirements for dev, staging, and production
- **Comprehensive Coverage**: Tests for AKS, Key Vault, Managed Identities, Resource Groups, and VNets
- **Compliance Frameworks**: Mapped to CIS, Azure Security Benchmark, and NIST controls
- **GitLab CI/CD Integration**: Automated testing with detailed reporting
- **Flexible Configuration**: Environment-specific inputs and requirements
- **Rich Reporting**: JSON, HTML, and JUnit output formats

## Supported Resources

| Resource Type | Controls | Description |
|---------------|----------|-------------|
| **AKS Clusters** | 8 controls | RBAC, network policies, encryption, monitoring, private clusters |
| **Key Vault** | 8 controls | Soft delete, purge protection, network restrictions, RBAC |
| **User Assigned Managed Identity** | 7 controls | Lifecycle, role assignments, federated credentials |
| **Resource Groups** | 8 controls | Tagging, locks, policies, governance |
| **Virtual Networks** | 7 controls | NSG associations, address spaces, peering, DDoS protection |

**Total: 38 controls** covering critical security and compliance requirements.

## Compliance Frameworks

### CIS Azure Foundations Benchmark v1.5.0
- 12 mapped controls
- Focus on foundational security configurations
- Critical for baseline security posture

### Azure Security Benchmark v3.0
- 23 mapped controls  
- Microsoft's comprehensive security guidance
- Aligned with Azure Well-Architected Framework

### NIST Cybersecurity Framework v1.1
- 15 mapped controls
- Covers Identify, Protect, Detect, Respond, Recover functions
- Industry-standard cybersecurity guidance

## Requirements

### Local Development
- **InSpec**: Version 5.0 or higher
- **Azure CLI**: Version 2.50 or higher
- **Ruby**: Version 3.0 or higher (for custom libraries)
- **Azure Subscription**: With appropriate permissions

### Azure Permissions
The service principal or user running the tests needs the following minimum permissions:
- `Reader` role on target resource groups
- `Security Reader` role for security-related resources
- `Key Vault Reader` role for Key Vault access

### InSpec Dependencies
- `inspec-azure` gem (automatically installed)
- Azure authentication configured

## Installation

### 1. Clone the Profile

```bash
git clone <repository-url>
cd aso-compliance-profile
```

### 2. Install InSpec

```bash
# Using Homebrew (macOS)
brew install chef/chef/inspec

# Using gem
gem install inspec

# Using Docker
docker pull chef/inspec:latest
```

### 3. Install Azure CLI

```bash
# Using Homebrew (macOS)
brew install azure-cli

# Using package manager (Ubuntu)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### 4. Verify Installation

```bash
inspec check .
inspec deps list
```

## Configuration

### Azure Authentication

#### Option 1: Service Principal (Recommended for CI/CD)

```bash
export AZURE_CLIENT_ID="your-client-id"
export AZURE_CLIENT_SECRET="your-client-secret"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_SUBSCRIPTION_ID="your-subscription-id"

# Login using service principal
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
```

#### Option 2: Interactive Login (Development)

```bash
az login
az account set --subscription "your-subscription-name-or-id"
```

### Environment Configuration

Create environment-specific input files:

#### `inputs/dev.yml`
```yaml
resource_group_name: "rg-aso-dev"
aks_cluster_name: "aks-dev-cluster"
key_vault_name: "kv-aso-dev-001"
uami_name: "uami-aso-workload-dev"
vnet_name: "vnet-aso-dev"
environment: "dev"
required_tags:
  - "environment"
  - "owner"
  - "project"
```

#### `inputs/prod.yml`
```yaml
resource_group_name: "rg-aso-prod"
aks_cluster_name: "aks-prod-cluster"
key_vault_name: "kv-aso-prod-001"
uami_name: "uami-aso-workload-prod"
vnet_name: "vnet-aso-prod"
environment: "prod"
required_tags:
  - "environment"
  - "owner"
  - "cost-center"
  - "project"
  - "backup-policy"
  - "compliance-framework"
```

## Usage

### Local Execution

#### Run All Controls
```bash
# Run against development environment
inspec exec . -t azure:// --input-file inputs/dev.yml

# Run against production environment
inspec exec . -t azure:// --input-file inputs/prod.yml
```

#### Run Specific Controls
```bash
# Run only AKS controls
inspec exec . -t azure:// --input-file inputs/prod.yml --controls aks-*

# Run only critical controls (impact >= 0.8)
inspec exec . -t azure:// --input-file inputs/prod.yml --controls "/(aks-rbac-enabled|keyvault-soft-delete-enabled)/"
```

#### Generate Reports
```bash
# Generate multiple report formats
inspec exec . -t azure:// \
  --input-file inputs/prod.yml \
  --reporter cli json:reports/results.json html:reports/results.html junit2:reports/junit.xml
```

#### Environment-Specific Variables
```bash
# Using environment variables
export AZURE_RESOURCE_GROUP="rg-aso-staging"
export AKS_CLUSTER_NAME="aks-staging-cluster"
export KEY_VAULT_NAME="kv-aso-staging-001"
export ENVIRONMENT="staging"

inspec exec . -t azure://
```

### GitLab CI/CD Integration

#### 1. Set Up CI/CD Variables

In your GitLab project, configure the following CI/CD variables:

**Azure Authentication:**
- `AZURE_CLIENT_ID` (protected)
- `AZURE_CLIENT_SECRET` (protected, masked)
- `AZURE_TENANT_ID` (protected)
- `AZURE_SUBSCRIPTION_ID` (protected)

**Environment-Specific Resources:**

*Development:*
- `DEV_RESOURCE_GROUP`
- `DEV_AKS_CLUSTER_NAME`
- `DEV_KEY_VAULT_NAME`
- `DEV_UAMI_NAME`
- `DEV_VNET_NAME`

*Staging:*
- `STAGING_RESOURCE_GROUP`
- `STAGING_AKS_CLUSTER_NAME`
- `STAGING_KEY_VAULT_NAME`
- `STAGING_UAMI_NAME`
- `STAGING_VNET_NAME`

*Production:*
- `PROD_RESOURCE_GROUP`
- `PROD_AKS_CLUSTER_NAME`
- `PROD_KEY_VAULT_NAME`
- `PROD_UAMI_NAME`
- `PROD_VNET_NAME`

**Notification (Optional):**
- `SLACK_WEBHOOK_URL`
- `TEAMS_WEBHOOK_URL`

#### 2. Pipeline Integration

Copy the provided `.gitlab-ci.yml` to your project root or include it in your existing pipeline:

```yaml
include:
  - local: 'aso-compliance-profile/.gitlab-ci.yml'
```

#### 3. Trigger Compliance Tests

```bash
# Manual trigger for specific environment
gitlab-runner exec docker compliance_test_prod --env ENVIRONMENT=prod

# Schedule daily compliance checks
# Configure in GitLab UI: CI/CD > Schedules
```

## Test Controls

### Control Categories

#### Critical Controls (Impact 1.0)
- **aks-rbac-enabled**: AKS RBAC configuration
- **aks-network-policy-enabled**: Network policy enforcement
- **aks-node-pool-encryption**: Node pool encryption at host
- **keyvault-soft-delete-enabled**: Key Vault soft delete protection
- **keyvault-purge-protection-enabled**: Key Vault purge protection
- **uami-exists-and-active**: UAMI provisioning state
- **resourcegroup-exists-and-active**: Resource group state

#### High Priority Controls (Impact 0.8)
- **aks-cluster-monitoring**: Container insights monitoring
- **aks-private-cluster**: Private cluster configuration
- **keyvault-network-access-restrictions**: Network access controls
- **vnet-nsg-associations**: Network security group associations

#### Medium Priority Controls (Impact 0.6-0.7)
- **aks-api-server-authorized-ip-ranges**: API server access restrictions
- **keyvault-logging-enabled**: Diagnostic logging
- **vnet-peering-security**: Virtual network peering security

#### Low Priority Controls (Impact 0.3-0.5)
- **aks-cluster-tagging**: Resource tagging compliance
- **resourcegroup-naming-convention**: Naming standard compliance
- **vnet-address-space-best-practices**: IP address allocation

### Control Dependencies

Some controls have environment-specific requirements:

```ruby
# Example: Private cluster only required in production
only_if('Only enforce private cluster for production') do
  input('environment') == 'prod'
end
```

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `12345678-1234-1234-1234-123456789012` |
| `AZURE_RESOURCE_GROUP` | Resource group name | `rg-aso-prod` |
| `AKS_CLUSTER_NAME` | AKS cluster name | `aks-prod-cluster` |
| `KEY_VAULT_NAME` | Key Vault name | `kv-aso-prod-001` |
| `UAMI_NAME` | Managed identity name | `uami-aso-workload-prod` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `VNET_NAME` | Virtual network name | None (VNet controls skipped) |
| `ENVIRONMENT` | Deployment environment | `dev` |
| `COMPLIANCE_FRAMEWORKS` | Frameworks to validate | `["CIS", "ASB", "NIST"]` |

### Authentication Variables (CI/CD)

| Variable | Description | Security |
|----------|-------------|----------|
| `AZURE_CLIENT_ID` | Service principal ID | Protected |
| `AZURE_CLIENT_SECRET` | Service principal secret | Protected, Masked |
| `AZURE_TENANT_ID` | Azure AD tenant ID | Protected |

## Interpreting Results

### Exit Codes
- **0**: All tests passed
- **1**: One or more tests failed
- **100**: InSpec error (syntax, connectivity, etc.)

### Output Formats

#### CLI Output
```
Profile: ASO Infrastructure Compliance (aso-compliance-profile)
Version: 1.0.0
Target:  azure://

  ✔  aks-rbac-enabled: AKS cluster should have RBAC enabled
     ✔  AKS cluster aks-prod-cluster should exist
     ✔  AKS cluster aks-prod-cluster enable_rbac should cmp == true

  ×  keyvault-purge-protection-enabled: Key Vault should have purge protection enabled
     ✔  Key Vault kv-aso-prod-001 should exist
     ×  Key Vault kv-aso-prod-001 properties.enablePurgeProtection should cmp == true

Profile Summary: 23 successful, 1 failure, 2 skipped
Test Summary: 45 successful, 1 failure, 2 skipped
```

#### JSON Report Structure
```json
{
  "profiles": [{
    "name": "aso-compliance-profile",
    "controls": [{
      "id": "aks-rbac-enabled",
      "title": "AKS cluster should have RBAC enabled",
      "impact": 1.0,
      "results": [{
        "status": "passed",
        "message": "Test passed"
      }]
    }]
  }],
  "statistics": {
    "duration": 45.123
  }
}
```

### Compliance Scoring

#### Overall Compliance
```
Compliance % = (Passed Controls / Total Controls) × 100
```

#### Weighted Compliance (Impact-based)
```
Weighted Score = Σ(Control Impact × Result) / Σ(Control Impact)
```

### Common Failure Scenarios

#### Authentication Issues
```
Error: Unable to connect to Azure
Solution: Verify Azure CLI login and subscription access
```

#### Resource Not Found
```
Control: aks-rbac-enabled
Status: Failed
Message: AKS cluster 'aks-cluster' not found
Solution: Verify cluster name and resource group
```

#### Permission Denied
```
Error: Authorization failed
Solution: Ensure service principal has Reader role on resource group
```

## Customization

### Adding New Controls

1. **Create Control File**
```ruby
# controls/custom_controls.rb
control 'custom-control-id' do
  impact 0.7
  title 'Custom control description'
  desc 'Detailed description of what this control validates'
  
  describe azure_resource do
    # Your test logic here
  end
end
```

2. **Update Profile Metadata**
```yaml
# inspec.yml - add new inputs if needed
inputs:
  - name: custom_setting
    description: Custom configuration setting
    type: string
    required: false
```

3. **Add Compliance Mappings**
```ruby
# libraries/compliance_frameworks.rb
CIS_MAPPINGS['custom-control-id'] = ['CIS-X.Y.Z']
```

### Environment-Specific Controls

```ruby
control 'prod-only-control' do
  impact 1.0
  title 'Production-only validation'
  
  only_if('Only run in production') do
    input('environment') == 'prod'
  end
  
  describe azure_resource do
    # Production-specific tests
  end
end
```

### Custom Resources

Create custom InSpec resources in the `libraries/` directory:

```ruby
# libraries/custom_azure_resource.rb
class CustomAzureResource < Inspec.resource(1)
  name 'custom_azure_resource'
  
  def initialize(opts = {})
    @resource_group = opts[:resource_group]
    @name = opts[:name]
  end
  
  def exists?
    # Implementation
  end
  
  def custom_property
    # Custom property logic
  end
end
```

### Modifying Thresholds

Update compliance baselines in `files/compliance_baselines.yaml`:

```yaml
environments:
  production:
    aks:
      rbac_enabled: true           # Required
      private_cluster_required: true
    custom_thresholds:
      min_compliance_score: 95     # Minimum 95% compliance
      critical_failure_threshold: 0 # No critical failures allowed
```

## Troubleshooting

### Common Issues

#### 1. Azure Authentication Failures

**Problem**: `Error: Please run 'az login' to setup account.`

**Solutions**:
```bash
# Interactive login
az login

# Service principal login
az login --service-principal -u $CLIENT_ID -p $CLIENT_SECRET --tenant $TENANT_ID

# Verify authentication
az account show
```

#### 2. Resource Access Denied

**Problem**: `Authorization failed` or `Forbidden`

**Solutions**:
- Verify service principal has appropriate roles
- Check resource group permissions
- Ensure subscription access

```bash
# Check current permissions
az role assignment list --assignee $AZURE_CLIENT_ID

# Add Reader role if needed
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role Reader \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP
```

#### 3. InSpec Dependency Issues

**Problem**: `Failed to load dependencies`

**Solutions**:
```bash
# Clear InSpec cache
inspec clear_cache

# Reinstall dependencies
inspec deps vendor

# Check profile syntax
inspec check .
```

#### 4. Resource Not Found Errors

**Problem**: Controls failing because resources don't exist

**Solutions**:
- Verify resource names and resource group
- Check if resources are in expected subscription
- Ensure ASO resources are properly provisioned

```bash
# List resources in resource group
az resource list --resource-group $RESOURCE_GROUP --output table

# Verify specific resource
az aks show --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP
```

### Debug Mode

Enable verbose output for troubleshooting:

```bash
# Run with debug logging
inspec exec . -t azure:// --log-level debug

# Show all available resources
inspec exec . -t azure:// --reporter documentation
```

### Performance Optimization

For large environments or frequent runs:

```bash
# Run specific control groups
inspec exec . -t azure:// --controls "aks-*"

# Use cached results (if available)
inspec exec . -t azure:// --cache

# Parallel execution (where supported)
inspec exec . -t azure:// --reporter progress-bar
```

## Contributing

### Development Setup

1. **Fork and Clone**
```bash
git clone https://github.com/your-org/aso-compliance-profile.git
cd aso-compliance-profile
```

2. **Install Development Dependencies**
```bash
gem install inspec
gem install rubocop  # For code linting
```

3. **Run Tests**
```bash
# Syntax check
inspec check .

# Local testing
inspec exec . -t azure:// --input-file inputs/dev.yml --reporter progress-bar

# Linting
rubocop controls/ libraries/
```

### Contribution Guidelines

1. **Control Development**
   - Follow InSpec best practices
   - Include proper descriptions and remediation guidance
   - Map to relevant compliance frameworks
   - Test in multiple environments

2. **Code Quality**
   - Use descriptive control IDs and titles
   - Include rationale in descriptions
   - Add appropriate impact levels
   - Follow Ruby style guidelines

3. **Documentation**
   - Update README for new controls
   - Add examples for custom configurations
   - Document any new dependencies
   - Include troubleshooting guidance

4. **Testing**
   - Test controls in dev, staging, and production
   - Verify error handling for missing resources
   - Check performance impact
   - Validate compliance mappings

### Pull Request Process

1. Create feature branch from `main`
2. Implement changes with tests
3. Update documentation
4. Run full test suite
5. Submit PR with detailed description
6. Address review feedback
7. Squash and merge when approved

---

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.

## Support

For support and questions:
- **Issues**: GitHub Issues
- **Documentation**: This README and inline comments
- **Enterprise Support**: Contact your DevOps team

## Changelog

### v1.0.0 (Initial Release)
- 38 comprehensive controls across 5 resource types
- Multi-environment support (dev/staging/prod)
- GitLab CI/CD integration
- Compliance framework mappings (CIS, ASB, NIST)
- Comprehensive documentation and troubleshooting guides
# AKS GitOps Repository

This repository contains Azure Kubernetes Service (AKS) GitOps configurations and tools for managing Kubernetes deployments using GitOps principles.

## Git Commit Message Standards

This repository enforces strict commit message standards to ensure consistent logs and proper JIRA integration. All commits must follow the specified format.

### Required Format

```
<type>: <JIRA-TICKET> <description>
```

Where:
- `<type>` must be one of: `feat`, `fix`, `update`
- `<JIRA-TICKET>` must follow the pattern: `PROJECT-NUMBER` (e.g., `CCBR-123`)
- `<description>` is a brief description of the change

### Examples

```bash
feat: CCBR-123 Add user authentication module
fix: CCBR-456 Resolve memory leak in data processing  
update: CCBR-789 Update API documentation
```

### Setting Up Git Hooks

To enforce commit message standards automatically, configure the git hooks path:

```bash
# Set the hooks path to use our custom hooks
git config core.hooksPath scripts/git-hooks

# Or set it globally for all repositories
git config --global core.hooksPath scripts/git-hooks
```

The pre-push hook will validate all commit messages being pushed and reject the push if any commit doesn't follow the required format.

## Repository Structure

This repository contains several key components for AKS GitOps management:

- `ASO/` - Azure Service Operator configurations
- `aks-version-test/` - AKS version testing InSpec profiles  
- `azure-backup/` - Azure backup scripts and configurations
- `goss-to-inspec-conversion/` - Tools for converting Goss tests to InSpec format
- `vpanap/` - VPA-NAP (Vertical Pod Autoscaler - Node Auto Provisioner) configurations
- `scripts/git-hooks/` - Git hooks for enforcing development standards

## Development Guidelines

### Before You Start

1. **Set up git hooks** (required for all contributors):
   ```bash
   git config core.hooksPath scripts/git-hooks
   ```

2. **Follow commit message standards** - all commits must include a JIRA ticket reference

3. **Test your changes** using the provided InSpec profiles and scripts

## Contributing

1. Fork the repository
2. Create a feature branch with a descriptive name
3. Set up git hooks: `git config core.hooksPath scripts/git-hooks`
4. Make your changes following the established patterns
5. Ensure all commits follow the required message format
6. Submit a pull request

## Components

### ASO (Azure Service Operator)
Azure Service Operator configurations for managing Azure resources from Kubernetes.

### AKS Version Test
InSpec profiles for testing AKS version compliance and configuration.

### Azure Backup
Scripts and configurations for setting up and managing Azure Kubernetes Service backups.

### Goss to InSpec Conversion
Tools and utilities for converting Goss test specifications to InSpec format for compliance testing.

### VPA-NAP
Vertical Pod Autoscaler and Node Auto Provisioner configurations for optimizing resource utilization.

## License

This project is licensed under the terms specified in the LICENSE file.
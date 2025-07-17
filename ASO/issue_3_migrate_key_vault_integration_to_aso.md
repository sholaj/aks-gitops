# Migrate Key Vault Integration to ASO

Labels: aso, keyvault, secrets

As a platform engineer  
I want to configure Azure Key Vault using ASO  
So that secrets integration with CSI and workload identities is fully declarative

### Acceptance Criteria
- `Vault` manifest defined in `infrastructure/keyvault/vault.yaml`
- Access policies generated using ASO referencing UAMI
- CSI secrets driver deployment supports the mounted KV integration
- InSpec profile confirms read permission on secrets

# Azure Key Vault Compliance Controls
# These controls validate Key Vault instances provisioned by Azure Service Operator (ASO)

control 'keyvault-soft-delete-enabled' do
  impact 1.0
  title 'Key Vault should have soft delete enabled'
  desc 'Soft delete protection prevents accidental or malicious deletion of Key Vault and its contents'
  desc 'rationale', 'Soft delete provides a safety net against data loss and supports compliance requirements'
  desc 'remediation', 'Enable soft delete on Key Vault (enabled by default on new vaults)'
  tag 'CIS': ['CIS-8.1']
  tag 'Azure Security Benchmark': ['ASB-10.1']
  tag 'NIST': ['CP-9']
  ref 'Azure Key Vault Soft Delete', url: 'https://docs.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview'

  describe azurerm_key_vault(resource_group: input('resource_group_name'), name: input('key_vault_name')) do
    it { should exist }
    its('properties.enableSoftDelete') { should cmp true }
  end
end

control 'keyvault-purge-protection-enabled' do
  impact 1.0
  title 'Key Vault should have purge protection enabled for production environments'
  desc 'Purge protection prevents permanent deletion of Key Vault during the retention period'
  desc 'rationale', 'Purge protection provides additional security against malicious deletion in critical environments'
  desc 'remediation', 'Enable purge protection on Key Vault during creation'
  tag 'CIS': ['CIS-8.2']
  tag 'Azure Security Benchmark': ['ASB-10.2']
  tag 'NIST': ['CP-9']

  only_if('Enforce purge protection for production and staging environments') do
    %w[prod staging].include?(input('environment'))
  end

  describe azurerm_key_vault(resource_group: input('resource_group_name'), name: input('key_vault_name')) do
    it { should exist }
    its('properties.enablePurgeProtection') { should cmp true }
  end
end

control 'keyvault-network-access-restrictions' do
  impact 0.8
  title 'Key Vault should have network access restrictions configured'
  desc 'Network access restrictions limit Key Vault access to specific networks or IP addresses'
  desc 'rationale', 'Network restrictions reduce the attack surface and prevent unauthorized access'
  desc 'remediation', 'Configure firewall rules and virtual network service endpoints'
  tag 'CIS': ['CIS-8.3']
  tag 'Azure Security Benchmark': ['ASB-9.4']
  tag 'NIST': ['AC-3']

  only_if('Skip network restrictions check for development environments') do
    input('environment') != 'dev'
  end

  describe azurerm_key_vault(resource_group: input('resource_group_name'), name: input('key_vault_name')) do
    it { should exist }
    its('properties.networkAcls') { should_not be_nil }
    its('properties.networkAcls.defaultAction') { should cmp 'Deny' }
    # Should have either virtual network rules or IP rules configured
    it 'should have network restrictions configured' do
      network_acls = subject.properties['networkAcls']
      has_vnet_rules = network_acls['virtualNetworkRules'] && !network_acls['virtualNetworkRules'].empty?
      has_ip_rules = network_acls['ipRules'] && !network_acls['ipRules'].empty?
      expect(has_vnet_rules || has_ip_rules).to be true
    end
  end
end

control 'keyvault-rbac-enabled' do
  impact 0.7
  title 'Key Vault should use Azure RBAC for access control'
  desc 'Azure RBAC provides more granular and centralized access control compared to access policies'
  desc 'rationale', 'RBAC provides better security governance and integrates with Azure AD'
  desc 'remediation', 'Enable Azure RBAC for Key Vault authorization'
  tag 'Azure Security Benchmark': ['ASB-4.3']
  tag 'NIST': ['AC-3']

  describe azurerm_key_vault(resource_group: input('resource_group_name'), name: input('key_vault_name')) do
    it { should exist }
    its('properties.enableRbacAuthorization') { should cmp true }
  end
end

control 'keyvault-logging-enabled' do
  impact 0.6
  title 'Key Vault should have diagnostic logging enabled'
  desc 'Diagnostic logging provides audit trail for Key Vault access and operations'
  desc 'rationale', 'Logging is essential for security monitoring and compliance requirements'
  desc 'remediation', 'Configure diagnostic settings to send logs to Log Analytics or Storage Account'
  tag 'Azure Security Benchmark': ['ASB-6.1']
  tag 'NIST': ['AU-2']

  # This control checks for the presence of diagnostic settings
  # Note: This requires additional Azure REST API calls or custom resources
  describe azurerm_key_vault(resource_group: input('resource_group_name'), name: input('key_vault_name')) do
    it { should exist }
  end

  # Custom check for diagnostic settings (placeholder - would need custom resource)
  describe 'Key Vault diagnostic settings' do
    skip 'This control requires custom resource implementation to check diagnostic settings'
  end
end

control 'keyvault-required-tagging' do
  impact 0.5
  title 'Key Vault should have required tags'
  desc 'Proper tagging ensures resource governance and cost management'
  desc 'rationale', 'Tags are essential for resource management, cost allocation, and compliance tracking'
  desc 'remediation', 'Add all required tags to the Key Vault resource'
  tag 'Governance': ['Tagging']

  required_tags = input('required_tags')
  
  describe azurerm_key_vault(resource_group: input('resource_group_name'), name: input('key_vault_name')) do
    it { should exist }
    required_tags.each do |tag|
      its('tags') { should include(tag) }
      its("tags.#{tag}") { should_not be_empty }
    end
  end
end

control 'keyvault-private-endpoint' do
  impact 0.8
  title 'Key Vault should use private endpoints for secure connectivity'
  desc 'Private endpoints provide secure connectivity to Key Vault through private IP addresses'
  desc 'rationale', 'Private endpoints eliminate exposure to the public internet and improve security posture'
  desc 'remediation', 'Configure private endpoints for Key Vault access'
  tag 'Azure Security Benchmark': ['ASB-9.5']
  tag 'NIST': ['SC-7']

  only_if('Enforce private endpoints for production environments') do
    input('environment') == 'prod'
  end

  describe azurerm_key_vault(resource_group: input('resource_group_name'), name: input('key_vault_name')) do
    it { should exist }
    its('properties.privateEndpointConnections') { should_not be_empty }
  end
end

control 'keyvault-key-expiration-policy' do
  impact 0.5
  title 'Key Vault keys should have expiration dates configured'
  desc 'Key expiration policies ensure regular key rotation and reduce risk of key compromise'
  desc 'rationale', 'Regular key rotation is a security best practice and compliance requirement'
  desc 'remediation', 'Set expiration dates on all cryptographic keys in Key Vault'
  tag 'CIS': ['CIS-8.5']
  tag 'NIST': ['SC-12']

  # This would require iterating through all keys in the vault
  # Placeholder for demonstration - would need custom resource implementation
  describe 'Key Vault key expiration policy' do
    skip 'This control requires custom resource implementation to check individual key expiration'
  end
end
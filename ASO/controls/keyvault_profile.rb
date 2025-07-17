control 'keyvault-access-policy' do
  impact 1.0
  title 'KeyVault should grant access to the cluster identity'
  describe azurerm_key_vault(resource_group: 'my-rg', name: 'my-keyvault') do
    its('enabled_for_deployment') { should cmp true }
    its('access_policies.count') { should be > 0 }
  end
end
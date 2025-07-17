control 'uami-exists' do
  impact 1.0
  title 'User Assigned Managed Identity should exist'
  describe azurerm_user_assigned_identity(resource_group: 'my-rg', name: 'aks-uami') do
    it { should exist }
  end
end

control 'uami-has-client-id' do
  impact 1.0
  title 'UAMI should have a client ID'
  describe azurerm_user_assigned_identity(resource_group: 'my-rg', name: 'aks-uami') do
    its('client_id') { should_not be_nil }
  end
end
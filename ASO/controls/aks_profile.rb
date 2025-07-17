control 'aks-rbac-enabled' do
  impact 1.0
  title 'AKS cluster should have RBAC enabled'
  describe azurerm_kubernetes_cluster(resource_group: 'my-rg', name: 'my-aks-cluster') do
    its('enable_rbac') { should cmp true }
  end
end

control 'aks-node-pools-count' do
  impact 0.5
  title 'AKS cluster should have at least one node pool'
  describe azurerm_kubernetes_cluster(resource_group: 'my-rg', name: 'my-aks-cluster') do
    its('agent_pool_profiles.count') { should be >= 1 }
  end
end
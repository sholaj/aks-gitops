control 'aks-rbac-enabled' do
  impact 1.0
  title 'AKS cluster should have RBAC enabled'
  describe azurerm_kubernetes_cluster(resource_group: 'my-rg', name: 'my-aks-cluster') do
    its('enable_rbac') { should cmp true }
  end
end

control 'aks-node-pool-encryption' do
  impact 1.0
  title 'Node pool should have host encryption enabled'
  describe azurerm_kubernetes_cluster(resource_group: 'my-rg', name: 'my-aks-cluster') do
    its('agent_pool_profiles') do
      should all(include("enable_encryption_at_host" => true))
    end
  end
end

control 'aks-cluster-tag-check' do
  impact 0.5
  title 'AKS cluster should include required tags'
  describe azurerm_resource(resource_group: 'my-rg', name: 'my-aks-cluster', type: 'Microsoft.ContainerService/managedClusters') do
    its('tags') { should include('env') }
    its('tags') { should include('owner') }
  end
end
control 'aks-cluster-complete' do
  impact 1.0
  title 'Comprehensive AKS Cluster, Node Pool, Add-on, Security, and Resource Checks'
 
  # AKS Cluster Properties
  describe azurerm_aks_cluster(resource_group: input('resource_group'), name: input('cluster_name')) do
    it { should exist }
    its('properties.kubernetesVersion') { should cmp input('kubernetes_version') }
    its('properties.enableRbac') { should eq true }
    its('properties.provisioningState') { should cmp 'Succeeded' }
    its('properties.networkProfile.networkDataplane') { should cmp 'cilium' }
    its('oidcIssuerProfile.issuerUrl') { should match %r{/oic.prod-aks.azure.com/} }
    its('oidcIssuerProfile.enabled') { should eq true }
    its('metricsProfile.costAnalysis.enabled') { should eq true }
    its('azureMonitorProfile.metrics.enabled') { should eq true }
    its('azureMonitorProfile.containerInsights.enabled') { should eq true }
    its('properties.disableLocalAccounts') { should eq true }
    its(['addonProfiles', 'omsagent', 'enabled']) { should eq true }
    its(['addonProfiles', 'omsagent', 'config', 'logAnalyticsWorkspaceResourceID']) { should eq input('aks_logAnalyticsWorkspaceID') }
    its('apiServerAccessProfile.enablePrivateCluster') { should eq true }
    its('apiServerAccessProfile.enablePrivateClusterPublicFqdn') { should eq true }
    its(['addonProfiles', 'azurepolicy', 'enabled']) { should eq true }
    its('properties.networkProfile.networkPlugin') { should cmp 'azure' }
    its('properties.networkProfile.networkPluginMode') { should cmp 'overlay' }
    its('properties.networkProfile.networkPolicy') { should cmp 'cilium' }
    its('properties.networkProfile.loadBalancerSku') { should cmp 'standard' }
    its('workloadAutoScalerProfile.keda') { should eq true }
    its('serviceMeshProfile.istio.revisions.first') { should cmp input('aks_serviceMeshProfile_value_istio_revisions_0') }
    its('serviceMeshProfile.istio.components.ingressGateways.first.enabled') { should eq true }
    its('autoUpgradeProfile.nodeOsUpgradeChannel') { should cmp 'NodeImage' }
    its('autoUpgradeProfile.upgradeChannel') { should cmp 'patch' }
    its('podIdentityProfile.userAssignedIdentityExceptions') { should include 'ubs-system' }
    its('podIdentityProfile.userAssignedIdentityExceptions') { should include 'kube-system' }
  end
 
  # Node Pool Checks (System and User)
  %w[sysnpl usrnpl].each do |pool|
    describe azurerm_aks_node_pool(resource_group: input('resource_group'), cluster_name: input('cluster_name'), name: pool) do
      its('enableAutoScaling') { should eq true }
      its('enableCustomCaTrust') { should eq true }
      its('enableEncryptionAtHost') { should eq true }
      its(['securityProfile', 'enableSecureBoot']) { should eq true }
      its(['securityProfile', 'enableVtpm']) { should eq true }
      its('osSku') { should cmp 'AzureLinux' }
      its('osType') { should cmp 'Linux' }
      its('typePropertiesType') { should cmp 'VirtualMachineScaleSets' }
      its('osDiskType') { should cmp 'Managed' }
    end
  end
 
  # Autoscaling min/max node count checks
  describe azurerm_aks_node_pool(resource_group: input('resource_group'), cluster_name: input('cluster_name'), name: 'usrnpl') do
    its('minCount') { should eq 1 }
    # maxCount logic (custom command for environment-based check)
  end
  describe azurerm_aks_node_pool(resource_group: input('resource_group'), cluster_name: input('cluster_name'), name: 'sysnpl') do
    # maxCount logic (custom command for environment-based check)
  end
 
  # Managed Identities
  %w[CERT_MGR_MANAGEDIDENTITY EXTDNS_MANAGEDIDENTITY EXTSECRET_MANAGEDIDENTITY].each do |id|
    describe azurerm_managed_identity(resource_group: input('uami_resource_group'), name: input(id)) do
      it { should exist }
    end
  end
 
  # Federated credential checks (custom command)
  describe command("az identity federated-credential list --identity-name #{input('EXTSECRET_MANAGEDIDENTITY')} --resource-group #{input('uami_resource_group')} | jq length") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq '1' }
  end
 
  # Kubernetes resource checks (pods, configmaps, CRDs, clusterissuers)
  describe k8s_resource(api_version: 'v1', kind: 'Pod', namespace: 'flux-system', label_selector: 'app=source-controller') do
    its('status.phase') { should eq 'Running' }
  end
  describe k8s_resource(api_version: 'v1', kind: 'Pod', namespace: 'flux-system', label_selector: 'app=kustomize-controller') do
    its('status.phase') { should eq 'Running' }
  end
  describe k8s_resource(api_version: 'v1', kind: 'Pod', namespace: 'flux-system', label_selector: 'app=helm-controller') do
    its('status.phase') { should eq 'Running' }
  end
  describe k8s_resource(api_version: 'v1', kind: 'Pod', namespace: 'flux-system', label_selector: 'app.kubernetes.io/component=fluxconfig-agent') do
    its('status.phase') { should eq 'Running' }
  end
  describe k8s_resource(api_version: 'v1', kind: 'Pod', namespace: 'flux-system', label_selector: 'app.kubernetes.io/component=fluxconfig-controller') do
    its('status.phase') { should eq 'Running' }
  end
  describe k8s_resource(api_version: 'v1', kind: 'Pod', namespace: 'cert-manager') do
    its('status.phase') { should eq 'Running' }
  end
  describe k8s_resource(api_version: 'v1', kind: 'Pod', namespace: 'external-dns') do
    its('status.phase') { should eq 'Running' }
  end
  describe k8s_resource(api_version: 'v1', kind: 'Pod', namespace: 'informer') do
    its('status.phase') { should eq 'Running' }
  end
  describe k8s_resource(api_version: 'v1', kind: 'ConfigMap', namespace: 'logging', name: 'log-collector-config') do
    it { should exist }
  end
  describe k8s_resource(api_version: 'v1', kind: 'ConfigMap', namespace: 'logging', name: 'log-collector-scripts') do
    it { should exist }
  end
  describe k8s_resource(api_version: 'apiextensions.k8s.io/v1', kind: 'CustomResourceDefinition', name: 'loggingendpoints.uk8s.ubs.com') do
    it { should exist }
  end
  describe k8s_resource(api_version: 'cert-manager.io/v1', kind: 'ClusterIssuer', name: 'ubs-issuer') do
    it { should exist }
  end
  # Informer External Secret KV ref (custom command)
  describe command("kubectl get es -n informer") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/external-eva-secret/) }
    its('stdout') { should match(/eva-secretstore/) }
    its('stdout') { should match(/SecretSynced/) }
  end
 
  # File existence
  describe file(input('arm_var_file')) do
    it { should exist }
  end
 
  # SKIPPED: Custom command for ARM param update and istio version
  # describe command("python ../../main/python-scripts/updateParams.py --env-yml ../../../#{input('VAR_FILE')} --params-template ../../main/arm/aks/dev.k8s.azure.managedidentity.params._template.json --prefix-to-remove common_,aks_ && cat ../../main/arm/aks/dev.k8s.azure.managedidentity.params.json") do
  #   its('exit_status') { should eq 0 }
  #   its('stdout') { should match(/#{input('aks_serviceMeshProfile_value_istio_revisions_0')}/) }
  # end
end
 
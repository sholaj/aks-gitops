# encoding: utf-8
# copyright: DevOps Team

title '01 - Cluster-Level Properties'

# Retrieve inputs
resource_group = input('resource_group')
cluster_name = input('cluster_name')
kubernetes_version = input('kubernetes_version')
dns_prefix = input('dns_prefix')
istio_version = input('istio_version')
node_os_upgrade_channel = input('node_os_upgrade_channel')
upgrade_channel = input('upgrade_channel')

control 'cluster-properties-01' do
  impact 1.0
  title 'Kubernetes version should match expected version'
  desc 'Verify that the AKS cluster is running the expected Kubernetes version'
  
  tag 'cluster'
  tag 'version'
  tag 'compliance'
  tag 'cis-kubernetes-benchmark: 1.1.1'
  tag 'nist-csf: ID.AM-2'
  
  describe command("kubectl version --short | grep 'Server Version' | awk '{print $3}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/#{Regexp.escape(kubernetes_version)}/) }
  end
end

control 'cluster-properties-02' do
  impact 0.7
  title 'DNS prefix should be configured correctly'
  desc 'Verify that the AKS cluster has the correct DNS prefix configured'
  
  tag 'cluster'
  tag 'dns'
  tag 'networking'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'dnsPrefix' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq dns_prefix }
  end
end

control 'cluster-properties-03' do
  impact 1.0
  title 'RBAC should be enabled'
  desc 'Verify that Role-Based Access Control (RBAC) is enabled on the AKS cluster'
  
  tag 'cluster'
  tag 'security'
  tag 'rbac'
  tag 'cis-kubernetes-benchmark: 1.2.1'
  tag 'nist-csf: PR.AC-1'
  tag 'pci-dss: 7.1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'enableRBAC' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'cluster-properties-04' do
  impact 1.0
  title 'Cluster provisioning state should be successful'
  desc 'Verify that the AKS cluster provisioning state is Succeeded'
  
  tag 'cluster'
  tag 'provisioning'
  tag 'availability'
  tag 'nist-csf: ID.AM-2'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'provisioningState' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'Succeeded' }
  end
end

control 'cluster-properties-05' do
  impact 0.8
  title 'Kubernetes network configuration should use Azure CNI with Overlay'
  desc 'Verify that the cluster uses Azure CNI network plugin with overlay mode'
  
  tag 'cluster'
  tag 'networking'
  tag 'cni'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'networkProfile.networkPlugin' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'azure' }
  end
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'networkProfile.networkPluginMode' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'overlay' }
  end
end

control 'cluster-properties-06' do
  impact 0.8
  title 'Network dataplane should use Cilium'
  desc 'Verify that the cluster network dataplane is configured to use Cilium'
  
  tag 'cluster'
  tag 'networking'
  tag 'cilium'
  tag 'dataplane'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'networkProfile.networkDataplane' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'cilium' }
  end
end

control 'cluster-properties-07' do
  impact 0.8
  title 'Network policy should use Cilium'
  desc 'Verify that the cluster network policy is configured to use Cilium'
  
  tag 'cluster'
  tag 'networking'
  tag 'policy'
  tag 'cilium'
  tag 'security'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'networkProfile.networkPolicy' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'cilium' }
  end
end

control 'cluster-properties-08' do
  impact 0.7
  title 'Load balancer should use Standard SKU'
  desc 'Verify that the cluster load balancer uses Standard SKU for better performance and security'
  
  tag 'cluster'
  tag 'networking'
  tag 'loadbalancer'
  tag 'performance'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'networkProfile.loadBalancerSku' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'standard' }
  end
end

control 'cluster-properties-09' do
  impact 0.6
  title 'KEDA workload autoscaler should be enabled'
  desc 'Verify that KEDA (Kubernetes Event Driven Autoscaling) is enabled'
  
  tag 'cluster'
  tag 'autoscaling'
  tag 'keda'
  tag 'workload'
  tag 'performance'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'workloadAutoScalerProfile.keda.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'cluster-properties-10' do
  impact 0.7
  title 'Auto-upgrade channels should be properly configured'
  desc 'Verify that auto-upgrade channels are configured for both cluster and nodes'
  
  tag 'cluster'
  tag 'upgrade'
  tag 'maintenance'
  tag 'automation'
  tag 'nist-csf: PR.MA-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'autoUpgradeProfile.nodeOsUpgradeChannel' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq node_os_upgrade_channel }
  end
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'autoUpgradeProfile.upgradeChannel' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq upgrade_channel }
  end
end

control 'cluster-properties-11' do
  impact 0.6
  title 'Service mesh should be configured with Istio'
  desc 'Verify that Istio service mesh is properly configured'
  
  tag 'cluster'
  tag 'service-mesh'
  tag 'istio'
  tag 'microservices'
  tag 'networking'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'serviceMeshProfile.istio.revisions[0]' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq istio_version }
  end
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'serviceMeshProfile.istio.components.ingressGateways[0].enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end
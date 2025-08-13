# encoding: utf-8
# copyright: DevOps Team

title '04 - AddOns'

# Retrieve inputs
resource_group = input('resource_group')
cluster_name = input('cluster_name')
cert_manager_namespace = input('cert_manager_namespace')
external_dns_namespace = input('external_dns_namespace')
informer_namespace = input('informer_namespace')
cluster_issuer_name = input('cluster_issuer_name')
external_secret_name = input('external_secret_name')
secret_store_name = input('secret_store_name')
istio_version = input('istio_version')
node_os_upgrade_channel = input('node_os_upgrade_channel')
upgrade_channel = input('upgrade_channel')

control 'addons-01' do
  impact 0.8
  title 'Cert-manager pods should be running'
  desc 'Verify that cert-manager pods are in Running state'
  
  tag 'addons'
  tag 'cert-manager'
  tag 'tls'
  tag 'security'
  tag 'nist-csf: PR.DS-2'
  
  describe command("kubectl -n #{cert_manager_namespace} get pods -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Failed|Pending|Error/) }
  end
end

control 'addons-02' do
  impact 0.7
  title 'External DNS pods should be running'
  desc 'Verify that external-dns pods are in Running state'
  
  tag 'addons'
  tag 'external-dns'
  tag 'dns'
  tag 'networking'
  tag 'nist-csf: PR.AC-4'
  
  describe command("kubectl -n #{external_dns_namespace} get pods -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Failed|Pending|Error/) }
  end
end

control 'addons-03' do
  impact 0.7
  title 'Informer pods should be running'
  desc 'Verify that informer pods are in Running state'
  
  tag 'addons'
  tag 'informer'
  tag 'monitoring'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl -n #{informer_namespace} get pods -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Failed|Pending|Error/) }
  end
end

control 'addons-04' do
  impact 0.8
  title 'Cluster issuer should be ready'
  desc 'Verify that the cluster issuer is in Ready state with Success condition'
  
  tag 'addons'
  tag 'cert-manager'
  tag 'cluster-issuer'
  tag 'tls'
  tag 'nist-csf: PR.DS-2'
  
  describe command("kubectl get clusterissuers #{cluster_issuer_name} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'True' }
  end
  
  describe command("kubectl get clusterissuers #{cluster_issuer_name} -o jsonpath='{.metadata.name}'") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq cluster_issuer_name }
  end
end

control 'addons-05' do
  impact 0.7
  title 'Informer external secret should be synced'
  desc 'Verify that the external secret is in SecretSynced state'
  
  tag 'addons'
  tag 'external-secrets'
  tag 'informer'
  tag 'security'
  tag 'nist-csf: PR.AC-1'
  
  describe command("kubectl get externalsecrets #{external_secret_name} -n #{informer_namespace} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'True' }
  end
  
  describe command("kubectl get externalsecrets #{external_secret_name} -n #{informer_namespace} -o jsonpath='{.spec.secretStoreRef.name}'") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq secret_store_name }
  end
end

control 'addons-06' do
  impact 0.6
  title 'KEDA configuration should be enabled'
  desc 'Verify that KEDA workload autoscaler is enabled on the cluster'
  
  tag 'addons'
  tag 'keda'
  tag 'autoscaling'
  tag 'nist-csf: PR.DS-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'workloadAutoScalerProfile.keda.enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'addons-07' do
  impact 0.7
  title 'Istio version should match expected version'
  desc 'Verify that the correct Istio version is configured'
  
  tag 'addons'
  tag 'istio'
  tag 'service-mesh'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'serviceMeshProfile.istio.revisions[0]' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/#{Regexp.escape(istio_version)}/) }
  end
end

control 'addons-08' do
  impact 0.6
  title 'Istio ingress gateway should be enabled'
  desc 'Verify that Istio ingress gateway is enabled'
  
  tag 'addons'
  tag 'istio'
  tag 'ingress-gateway'
  tag 'networking'
  tag 'nist-csf: PR.AC-4'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'serviceMeshProfile.istio.components.ingressGateways[0].enabled' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'true' }
  end
end

control 'addons-09' do
  impact 0.5
  title 'Planned maintenance node OS upgrade channel should be configured'
  desc 'Verify that the node OS upgrade channel is properly configured'
  
  tag 'addons'
  tag 'maintenance'
  tag 'node-upgrade'
  tag 'nist-csf: PR.MA-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'autoUpgradeProfile.nodeOsUpgradeChannel' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq node_os_upgrade_channel }
  end
end

control 'addons-10' do
  impact 0.5
  title 'Planned maintenance upgrade channel should be configured'
  desc 'Verify that the AKS upgrade channel is properly configured'
  
  tag 'addons'
  tag 'maintenance'
  tag 'cluster-upgrade'
  tag 'nist-csf: PR.MA-1'
  
  describe command("az aks show --resource-group #{resource_group} --name #{cluster_name} --query 'autoUpgradeProfile.upgradeChannel' -o tsv") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq upgrade_channel }
  end
end
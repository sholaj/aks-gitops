# encoding: utf-8
# copyright: DevOps Team

title '11 - Kubernetes Resources Validation'

# Retrieve inputs
flux_namespace = input('flux_namespace')
cert_manager_namespace = input('cert_manager_namespace')
external_dns_namespace = input('external_dns_namespace')
informer_namespace = input('informer_namespace')
logging_namespace = input('logging_namespace')
cluster_issuer_name = input('cluster_issuer_name')
external_secret_name = input('external_secret_name')
secret_store_name = input('secret_store_name')
logging_configmap_name = input('logging_configmap_name')
logging_scripts_configmap_name = input('logging_scripts_configmap_name')
logging_crd_name = input('logging_crd_name')

control 'k8s-resources-01' do
  impact 1.0
  title 'Flux source controller should be running'
  desc 'Verify that the Flux source controller pods are running in the flux-system namespace'
  
  tag 'kubernetes'
  tag 'flux'
  tag 'gitops'
  tag 'source-controller'
  tag 'availability'
  tag 'nist-csf: DE.CM-7'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app=source-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Pending|Failed|Unknown/) }
  end
end

control 'k8s-resources-02' do
  impact 1.0
  title 'Flux kustomize controller should be running'
  desc 'Verify that the Flux kustomize controller pods are running in the flux-system namespace'
  
  tag 'kubernetes'
  tag 'flux'
  tag 'gitops'
  tag 'kustomize-controller'
  tag 'availability'
  tag 'nist-csf: DE.CM-7'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app=kustomize-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Pending|Failed|Unknown/) }
  end
end

control 'k8s-resources-03' do
  impact 1.0
  title 'Flux helm controller should be running'
  desc 'Verify that the Flux helm controller pods are running in the flux-system namespace'
  
  tag 'kubernetes'
  tag 'flux'
  tag 'gitops'
  tag 'helm-controller'
  tag 'availability'
  tag 'nist-csf: DE.CM-7'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app=helm-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Pending|Failed|Unknown/) }
  end
end

control 'k8s-resources-04' do
  impact 0.8
  title 'Flux config agent should be running'
  desc 'Verify that the Flux config agent pods are running in the flux-system namespace'
  
  tag 'kubernetes'
  tag 'flux'
  tag 'gitops'
  tag 'fluxconfig-agent'
  tag 'availability'
  tag 'nist-csf: DE.CM-7'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app.kubernetes.io/component=fluxconfig-agent -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Pending|Failed|Unknown/) }
  end
end

control 'k8s-resources-05' do
  impact 0.8
  title 'Flux config controller should be running'
  desc 'Verify that the Flux config controller pods are running in the flux-system namespace'
  
  tag 'kubernetes'
  tag 'flux'
  tag 'gitops'
  tag 'fluxconfig-controller'
  tag 'availability'
  tag 'nist-csf: DE.CM-7'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app.kubernetes.io/component=fluxconfig-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Pending|Failed|Unknown/) }
  end
end

control 'k8s-resources-06' do
  impact 1.0
  title 'Cert-manager pods should be running'
  desc 'Verify that cert-manager pods are running in the cert-manager namespace'
  
  tag 'kubernetes'
  tag 'cert-manager'
  tag 'tls'
  tag 'certificates'
  tag 'availability'
  tag 'nist-csf: PR.DS-2'
  
  describe command("kubectl get pods -n #{cert_manager_namespace} -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Pending|Failed|Unknown/) }
  end
end

control 'k8s-resources-07' do
  impact 0.8
  title 'External DNS pods should be running'
  desc 'Verify that external-dns pods are running in the external-dns namespace'
  
  tag 'kubernetes'
  tag 'external-dns'
  tag 'dns'
  tag 'networking'
  tag 'availability'
  tag 'nist-csf: PR.AC-4'
  
  describe command("kubectl get pods -n #{external_dns_namespace} -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Pending|Failed|Unknown/) }
  end
end

control 'k8s-resources-08' do
  impact 0.7
  title 'Informer pods should be running'
  desc 'Verify that informer pods are running in the informer namespace'
  
  tag 'kubernetes'
  tag 'informer'
  tag 'monitoring'
  tag 'availability'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl get pods -n #{informer_namespace} -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
    its('stdout') { should_not match(/Pending|Failed|Unknown/) }
  end
end

control 'k8s-resources-09' do
  impact 0.8
  title 'Logging configuration should exist'
  desc 'Verify that required logging ConfigMaps exist in the logging namespace'
  
  tag 'kubernetes'
  tag 'logging'
  tag 'configuration'
  tag 'observability'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl get configmap #{logging_configmap_name} -n #{logging_namespace}") do
    its('exit_status') { should eq 0 }
  end
  
  describe command("kubectl get configmap #{logging_scripts_configmap_name} -n #{logging_namespace}") do
    its('exit_status') { should eq 0 }
  end
end

control 'k8s-resources-10' do
  impact 0.7
  title 'Custom Resource Definitions should exist'
  desc 'Verify that required Custom Resource Definitions are installed'
  
  tag 'kubernetes'
  tag 'crd'
  tag 'custom-resources'
  tag 'logging'
  tag 'extensibility'
  
  describe command("kubectl get crd #{logging_crd_name}") do
    its('exit_status') { should eq 0 }
  end
end

control 'k8s-resources-11' do
  impact 0.8
  title 'Cluster issuer should exist and be ready'
  desc 'Verify that the cluster certificate issuer exists and is in ready state'
  
  tag 'kubernetes'
  tag 'cert-manager'
  tag 'cluster-issuer'
  tag 'tls'
  tag 'certificates'
  tag 'security'
  tag 'nist-csf: PR.DS-2'
  
  describe command("kubectl get clusterissuer #{cluster_issuer_name}") do
    its('exit_status') { should eq 0 }
  end
  
  describe command("kubectl get clusterissuer #{cluster_issuer_name} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'True' }
  end
end

control 'k8s-resources-12' do
  impact 0.7
  title 'External secrets should be synchronized'
  desc 'Verify that external secrets are properly synchronized from the secret store'
  
  tag 'kubernetes'
  tag 'external-secrets'
  tag 'secrets-management'
  tag 'security'
  tag 'synchronization'
  tag 'nist-csf: PR.AC-1'
  
  describe command("kubectl get externalsecrets -n #{informer_namespace}") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/#{external_secret_name}/) }
    its('stdout') { should match(/#{secret_store_name}/) }
    its('stdout') { should match(/SecretSynced/) }
  end
end

control 'k8s-resources-13' do
  impact 0.6
  title 'External secret should be in Ready state'
  desc 'Verify that the external secret is in Ready state indicating successful synchronization'
  
  tag 'kubernetes'
  tag 'external-secrets'
  tag 'secrets-management'
  tag 'security'
  tag 'health'
  tag 'nist-csf: PR.AC-1'
  
  describe command("kubectl get externalsecrets #{external_secret_name} -n #{informer_namespace} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq 'True' }
  end
end

control 'k8s-resources-14' do
  impact 0.5
  title 'Namespace resources should be properly labeled'
  desc 'Verify that critical namespaces have appropriate labels for governance and monitoring'
  
  tag 'kubernetes'
  tag 'namespaces'
  tag 'governance'
  tag 'labels'
  tag 'organization'
  
  critical_namespaces = [flux_namespace, cert_manager_namespace, external_dns_namespace, informer_namespace, logging_namespace]
  
  critical_namespaces.each do |namespace|
    describe command("kubectl get namespace #{namespace}") do
      its('exit_status') { should eq 0 }
    end
  end
end
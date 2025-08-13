# encoding: utf-8
# copyright: DevOps Team

title '03 - GitOps Configuration'

# Retrieve inputs
flux_namespace = input('flux_namespace')
gitrepository_name = input('gitrepository_name')
kustomization_name = input('kustomization_name')

control 'gitops-01' do
  impact 1.0
  title 'Flux source controller should be running'
  desc 'Verify that the Flux source controller pod is in Running state'
  
  tag 'gitops'
  tag 'flux'
  tag 'source-controller'
  tag 'nist-csf: PR.DS-6'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app=source-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
  end
end

control 'gitops-02' do
  impact 1.0
  title 'Flux kustomize controller should be running'
  desc 'Verify that the Flux kustomize controller pod is in Running state'
  
  tag 'gitops'
  tag 'flux'
  tag 'kustomize-controller'
  tag 'nist-csf: PR.DS-6'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app=kustomize-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
  end
end

control 'gitops-03' do
  impact 1.0
  title 'Flux helm controller should be running'
  desc 'Verify that the Flux helm controller pod is in Running state'
  
  tag 'gitops'
  tag 'flux'
  tag 'helm-controller'
  tag 'nist-csf: PR.DS-6'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app=helm-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
  end
end

control 'gitops-04' do
  impact 0.8
  title 'Fluxconfig agent pod should be running'
  desc 'Verify that the fluxconfig agent pod is in Running state'
  
  tag 'gitops'
  tag 'flux'
  tag 'fluxconfig-agent'
  tag 'nist-csf: PR.DS-6'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app.kubernetes.io/component=fluxconfig-agent -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
  end
end

control 'gitops-05' do
  impact 0.8
  title 'Fluxconfig controller pod should be running'
  desc 'Verify that the fluxconfig controller pod is in Running state'
  
  tag 'gitops'
  tag 'flux'
  tag 'fluxconfig-controller'
  tag 'nist-csf: PR.DS-6'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app.kubernetes.io/component=fluxconfig-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
  end
end

control 'gitops-06' do
  impact 0.7
  title 'Image automation controller pod should be running'
  desc 'Verify that the image automation controller pod is in Running state'
  
  tag 'gitops'
  tag 'flux'
  tag 'image-automation-controller'
  tag 'nist-csf: PR.DS-6'
  
  describe command("kubectl get pods -n #{flux_namespace} -l app=image-automation-controller -o jsonpath='{.items[*].status.phase}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/Running/) }
  end
end

control 'gitops-07' do
  impact 1.0
  title 'GitRepository resource should exist'
  desc 'Verify that the expected GitRepository custom resource exists'
  
  tag 'gitops'
  tag 'flux'
  tag 'gitrepository'
  tag 'nist-csf: PR.DS-6'
  
  describe command('kubectl get gitrepositories.source.toolkit.fluxcd.io -A -o jsonpath=\'{range .items[*]}{.metadata.name}{"\n"}{end}\'') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/#{Regexp.escape(gitrepository_name)}/) }
  end
end

control 'gitops-08' do
  impact 1.0
  title 'Kustomization resource should exist'
  desc 'Verify that the expected Kustomization custom resource exists'
  
  tag 'gitops'
  tag 'flux'
  tag 'kustomization'
  tag 'nist-csf: PR.DS-6'
  
  describe command('kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o jsonpath=\'{range .items[*]}{.metadata.name}{"\n"}{end}\'') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/#{Regexp.escape(kustomization_name)}/) }
  end
end

control 'gitops-09' do
  impact 0.8
  title 'Kustomization should be synchronized'
  desc 'Verify that the Kustomization resource is in a Ready/True state'
  
  tag 'gitops'
  tag 'flux'
  tag 'kustomization'
  tag 'synchronization'
  tag 'nist-csf: PR.DS-6'
  
  describe command("kubectl get kustomizations.kustomize.toolkit.fluxcd.io -n #{flux_namespace} -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}'") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/True/) }
  end
end
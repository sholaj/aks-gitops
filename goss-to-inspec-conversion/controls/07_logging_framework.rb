# encoding: utf-8
# copyright: DevOps Team

title '07 - Logging Framework'

# Retrieve inputs
logging_namespace = input('logging_namespace')
logging_daemonset_name = input('logging_daemonset_name')
logging_crd_name = input('logging_crd_name')
logging_configmap_name = input('logging_configmap_name')
logging_scripts_configmap_name = input('logging_scripts_configmap_name')

control 'logging-01' do
  impact 0.8
  title 'Logging daemonset should be rolled out successfully'
  desc 'Verify that the logging daemonset has been successfully rolled out'
  
  tag 'logging'
  tag 'daemonset'
  tag 'deployment'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl --namespace #{logging_namespace} rollout status daemonset/#{logging_daemonset_name} --timeout=30s") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(/successfully rolled out/) }
  end
end

control 'logging-02' do
  impact 0.8
  title 'Logging daemonset pods should be running on all nodes'
  desc 'Verify that the logging daemonset has pods running on all desired nodes'
  
  tag 'logging'
  tag 'daemonset'
  tag 'pods'
  tag 'availability'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl --namespace #{logging_namespace} get daemonset #{logging_daemonset_name} -o json | jq -r 'select(.status.desiredNumberScheduled == .status.numberReady).metadata.name'") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq logging_daemonset_name }
  end
end

control 'logging-03' do
  impact 0.7
  title 'Logging CRD should be installed'
  desc 'Verify that the required logging Custom Resource Definition is installed'
  
  tag 'logging'
  tag 'crd'
  tag 'custom-resources'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl get crd #{logging_crd_name}") do
    its('exit_status') { should eq 0 }
  end
end

control 'logging-04' do
  impact 0.7
  title 'Logging configmap should be created'
  desc 'Verify that the logging configuration configmap exists'
  
  tag 'logging'
  tag 'configmap'
  tag 'configuration'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl --namespace #{logging_namespace} get configmap #{logging_configmap_name}") do
    its('exit_status') { should eq 0 }
  end
end

control 'logging-05' do
  impact 0.6
  title 'Logging configmap should have correct filter configuration'
  desc 'Verify that the logging configmap contains the correct path filter for container logs'
  
  tag 'logging'
  tag 'configmap'
  tag 'configuration'
  tag 'filter'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl --namespace #{logging_namespace} get configmap #{logging_configmap_name} -o yaml") do
    its('exit_status') { should eq 0 }
    its('stdout') { should match(%r{Path\s*/var/log/containers/\*\.log}) }
  end
end

control 'logging-06' do
  impact 0.6
  title 'Logging scripts configmap should be created'
  desc 'Verify that the logging scripts configmap exists'
  
  tag 'logging'
  tag 'configmap'
  tag 'scripts'
  tag 'nist-csf: DE.CM-1'
  
  describe command("kubectl --namespace #{logging_namespace} get configmap #{logging_scripts_configmap_name}") do
    its('exit_status') { should eq 0 }
  end
end
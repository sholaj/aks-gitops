# encoding: utf-8
# copyright: DevOps Team

title '08 - User Assigned Managed Identity (UAMI) Checks'

# Retrieve inputs
uami_resource_group = input('uami_resource_group')
cert_mgr_managed_identity = input('cert_mgr_managed_identity')
extdns_managed_identity = input('extdns_managed_identity')
extsecret_managed_identity = input('extsecret_managed_identity')
federated_credential_count = input('federated_credential_count')

control 'uami-01' do
  impact 1.0
  title 'Cert-manager managed identity should exist'
  desc 'Verify that the cert-manager User Assigned Managed Identity exists'
  
  tag 'uami'
  tag 'cert-manager'
  tag 'identity'
  tag 'security'
  tag 'nist-csf: PR.AC-1'
  
  describe command("az identity show --name #{cert_mgr_managed_identity} --resource-group #{uami_resource_group}") do
    its('exit_status') { should eq 0 }
  end
end

control 'uami-02' do
  impact 1.0
  title 'External DNS managed identity should exist'
  desc 'Verify that the external-dns User Assigned Managed Identity exists'
  
  tag 'uami'
  tag 'external-dns'
  tag 'identity'
  tag 'security'
  tag 'nist-csf: PR.AC-1'
  
  describe command("az identity show --name #{extdns_managed_identity} --resource-group #{uami_resource_group}") do
    its('exit_status') { should eq 0 }
  end
end

control 'uami-03' do
  impact 1.0
  title 'External secrets managed identity should exist'
  desc 'Verify that the external-secrets User Assigned Managed Identity exists'
  
  tag 'uami'
  tag 'external-secrets'
  tag 'identity'
  tag 'security'
  tag 'nist-csf: PR.AC-1'
  
  describe command("az identity show --name #{extsecret_managed_identity} --resource-group #{uami_resource_group}") do
    its('exit_status') { should eq 0 }
  end
end

control 'uami-04' do
  impact 0.8
  title 'Cert-manager managed identity should have correct federated credentials'
  desc 'Verify that the cert-manager UAMI has the expected number of federated credentials'
  
  tag 'uami'
  tag 'cert-manager'
  tag 'federated-credentials'
  tag 'workload-identity'
  tag 'nist-csf: PR.AC-1'
  
  describe command("az identity federated-credential list --identity-name #{cert_mgr_managed_identity} --resource-group #{uami_resource_group} | jq length") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq federated_credential_count }
  end
end

control 'uami-05' do
  impact 0.8
  title 'External DNS managed identity should have correct federated credentials'
  desc 'Verify that the external-dns UAMI has the expected number of federated credentials'
  
  tag 'uami'
  tag 'external-dns'
  tag 'federated-credentials'
  tag 'workload-identity'
  tag 'nist-csf: PR.AC-1'
  
  describe command("az identity federated-credential list --identity-name #{extdns_managed_identity} --resource-group #{uami_resource_group} | jq length") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq federated_credential_count }
  end
end

control 'uami-06' do
  impact 0.8
  title 'External secrets managed identity should have correct federated credentials'
  desc 'Verify that the external-secrets UAMI has the expected number of federated credentials'
  
  tag 'uami'
  tag 'external-secrets'
  tag 'federated-credentials'
  tag 'workload-identity'
  tag 'nist-csf: PR.AC-1'
  
  describe command("az identity federated-credential list --identity-name #{extsecret_managed_identity} --resource-group #{uami_resource_group} | jq length") do
    its('exit_status') { should eq 0 }
    its('stdout.strip') { should eq federated_credential_count }
  end
end
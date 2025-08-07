# User Assigned Managed Identity (UAMI) Compliance Controls
# These controls validate UAMI instances provisioned by Azure Service Operator (ASO)

control 'uami-exists-and-active' do
  impact 1.0
  title 'User Assigned Managed Identity should exist and be in active state'
  desc 'Verify that the UAMI resource exists and is properly provisioned'
  desc 'rationale', 'UAMI must be active to provide authentication services to workloads'
  desc 'remediation', 'Ensure UAMI is properly created and not in failed state'
  tag 'Azure Security Benchmark': ['ASB-4.4']
  tag 'NIST': ['IA-2']

  describe azurerm_user_assigned_identity(resource_group: input('resource_group_name'), name: input('uami_name')) do
    it { should exist }
    its('properties.provisioning_state') { should cmp 'Succeeded' }
    its('principal_id') { should_not be_nil }
    its('client_id') { should_not be_nil }
  end
end

control 'uami-proper-naming-convention' do
  impact 0.3
  title 'User Assigned Managed Identity should follow naming conventions'
  desc 'UAMI should follow organizational naming conventions for consistency'
  desc 'rationale', 'Consistent naming conventions improve resource management and governance'
  desc 'remediation', 'Update UAMI name to follow organizational naming standards'
  tag 'Governance': ['Naming']

  describe input('uami_name') do
    # Example naming convention: uami-{workload}-{environment}
    it { should match(/^uami-[a-z0-9-]+-[a-z]+$/) }
  end

  describe azurerm_user_assigned_identity(resource_group: input('resource_group_name'), name: input('uami_name')) do
    it { should exist }
  end
end

control 'uami-required-tagging' do
  impact 0.5
  title 'User Assigned Managed Identity should have required tags'
  desc 'Proper tagging ensures resource governance and cost management'
  desc 'rationale', 'Tags are essential for resource management, cost allocation, and compliance tracking'
  desc 'remediation', 'Add all required tags to the UAMI resource'
  tag 'Governance': ['Tagging']

  required_tags = input('required_tags')
  
  describe azurerm_user_assigned_identity(resource_group: input('resource_group_name'), name: input('uami_name')) do
    it { should exist }
    required_tags.each do |tag|
      its('tags') { should include(tag) }
      its("tags.#{tag}") { should_not be_empty }
    end
  end
end

control 'uami-role-assignments-principle-of-least-privilege' do
  impact 0.8
  title 'UAMI should follow principle of least privilege for role assignments'
  desc 'UAMI should only have the minimum required permissions for its intended purpose'
  desc 'rationale', 'Least privilege access reduces security risk and limits potential damage from compromise'
  desc 'remediation', 'Review and remove unnecessary role assignments from UAMI'
  tag 'CIS': ['CIS-1.21']
  tag 'Azure Security Benchmark': ['ASB-4.5']
  tag 'NIST': ['AC-6']

  # Get the principal ID for role assignment checks
  principal_id = azurerm_user_assigned_identity(resource_group: input('resource_group_name'), name: input('uami_name')).principal_id

  # Check that UAMI doesn't have overly permissive roles
  dangerous_roles = [
    'Owner',
    'Contributor',
    'User Access Administrator',
    'Security Admin'
  ]

  dangerous_roles.each do |role|
    describe "UAMI should not have #{role} role assignment" do
      subject { azurerm_role_assignments.where(principal_id: principal_id, role_definition_name: role) }
      it { should be_empty }
    end
  end

  # Verify UAMI has some role assignments (not orphaned)
  describe "UAMI should have at least one role assignment" do
    subject { azurerm_role_assignments.where(principal_id: principal_id) }
    it { should_not be_empty }
  end
end

control 'uami-federated-credentials-configuration' do
  impact 0.7
  title 'UAMI should have properly configured federated credentials for workload identity'
  desc 'Federated credentials enable secure authentication from Kubernetes workloads'
  desc 'rationale', 'Proper federated credential configuration ensures secure workload authentication'
  desc 'remediation', 'Configure federated credentials with proper issuer and subject claims'
  tag 'Azure Security Benchmark': ['ASB-4.6']
  tag 'NIST': ['IA-2']

  # Note: This control would require custom resource implementation to check federated credentials
  # Azure REST API call would be needed to verify federated credential configuration
  describe azurerm_user_assigned_identity(resource_group: input('resource_group_name'), name: input('uami_name')) do
    it { should exist }
  end

  describe 'UAMI federated credentials configuration' do
    skip 'This control requires custom resource implementation to check federated credentials'
  end
end

control 'uami-no-assigned-applications' do
  impact 0.4
  title 'UAMI should not be assigned to applications that do not require it'
  desc 'UAMIs should only be assigned to applications that specifically require managed identity authentication'
  desc 'rationale', 'Unnecessary UAMI assignments increase attack surface and violate least privilege'
  desc 'remediation', 'Remove UAMI assignments from applications that do not require managed identity'
  tag 'NIST': ['AC-6']

  # This is a placeholder control - would need custom implementation to check application assignments
  describe azurerm_user_assigned_identity(resource_group: input('resource_group_name'), name: input('uami_name')) do
    it { should exist }
  end

  describe 'UAMI application assignments' do
    skip 'This control requires custom resource implementation to check application assignments'
  end
end

control 'uami-location-compliance' do
  impact 0.3
  title 'UAMI should be created in approved Azure regions'
  desc 'UAMIs should be created in regions that comply with data residency requirements'
  desc 'rationale', 'Data residency compliance may require resources to be in specific geographic regions'
  desc 'remediation', 'Move or recreate UAMI in approved regions'
  tag 'Governance': ['Data Residency']

  # Define approved regions based on environment
  approved_regions = case input('environment')
                    when 'prod'
                      ['eastus', 'westus2', 'centralus']  # Production approved regions
                    when 'staging'
                      ['eastus', 'westus2', 'centralus', 'eastus2']  # Staging regions
                    else
                      ['eastus', 'westus2', 'centralus', 'eastus2', 'westeurope']  # Dev regions
                    end

  describe azurerm_user_assigned_identity(resource_group: input('resource_group_name'), name: input('uami_name')) do
    it { should exist }
    its('location') { should be_in approved_regions }
  end
end
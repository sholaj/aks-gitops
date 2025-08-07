# Resource Group Compliance Controls
# These controls validate Resource Groups that contain ASO-provisioned resources

control 'resourcegroup-exists-and-active' do
  impact 1.0
  title 'Resource Group should exist and be in active state'
  desc 'Verify that the Resource Group exists and is properly provisioned'
  desc 'rationale', 'Resource Group must exist and be active to contain ASO resources'
  desc 'remediation', 'Ensure Resource Group is properly created and not in failed state'
  tag 'Azure Security Benchmark': ['ASB-11.1']

  describe azurerm_resource_group(name: input('resource_group_name')) do
    it { should exist }
    its('properties.provisioning_state') { should cmp 'Succeeded' }
  end
end

control 'resourcegroup-required-tagging' do
  impact 0.7
  title 'Resource Group should have required tags'
  desc 'Proper tagging ensures resource governance and cost management at the Resource Group level'
  desc 'rationale', 'Resource Group tags are inherited by resources and are essential for governance'
  desc 'remediation', 'Add all required tags to the Resource Group'
  tag 'Governance': ['Tagging']

  required_tags = input('required_tags')
  
  describe azurerm_resource_group(name: input('resource_group_name')) do
    it { should exist }
    required_tags.each do |tag|
      its('tags') { should include(tag) }
      its("tags.#{tag}") { should_not be_empty }
    end
  end
end

control 'resourcegroup-location-compliance' do
  impact 0.5
  title 'Resource Group should be in approved Azure regions'
  desc 'Resource Groups should be created in regions that comply with data residency requirements'
  desc 'rationale', 'Data residency compliance may require resources to be in specific geographic regions'
  desc 'remediation', 'Recreate Resource Group in approved regions'
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

  describe azurerm_resource_group(name: input('resource_group_name')) do
    it { should exist }
    its('location') { should be_in approved_regions }
  end
end

control 'resourcegroup-resource-locks' do
  impact 0.8
  title 'Resource Group should have resource locks for production environments'
  desc 'Resource locks prevent accidental deletion or modification of critical resources'
  desc 'rationale', 'Resource locks provide protection against accidental changes in production environments'
  desc 'remediation', 'Apply resource locks (CanNotDelete or ReadOnly) to production Resource Groups'
  tag 'CIS': ['CIS-1.15']
  tag 'Azure Security Benchmark': ['ASB-11.2']
  tag 'NIST': ['CP-9']

  only_if('Enforce resource locks for production environments') do
    input('environment') == 'prod'
  end

  # Note: This control would require custom resource implementation to check resource locks
  # Azure REST API call would be needed to verify lock configuration
  describe azurerm_resource_group(name: input('resource_group_name')) do
    it { should exist }
  end

  describe 'Resource Group locks' do
    skip 'This control requires custom resource implementation to check resource locks'
  end
end

control 'resourcegroup-policy-compliance' do
  impact 0.6
  title 'Resource Group should comply with assigned Azure Policies'
  desc 'Resource Groups should comply with all assigned Azure Policy definitions'
  desc 'rationale', 'Policy compliance ensures adherence to organizational governance standards'
  desc 'remediation', 'Review and remediate any policy violations in the Resource Group'
  tag 'Azure Security Benchmark': ['ASB-11.3']
  tag 'Governance': ['Policy']

  # Note: This control would require custom resource implementation to check policy compliance
  # Azure REST API calls would be needed to verify policy assignments and compliance state
  describe azurerm_resource_group(name: input('resource_group_name')) do
    it { should exist }
  end

  describe 'Resource Group policy compliance' do
    skip 'This control requires custom resource implementation to check policy compliance'
  end
end

control 'resourcegroup-naming-convention' do
  impact 0.3
  title 'Resource Group should follow naming conventions'
  desc 'Resource Group should follow organizational naming conventions for consistency'
  desc 'rationale', 'Consistent naming conventions improve resource management and governance'
  desc 'remediation', 'Update Resource Group name to follow organizational naming standards'
  tag 'Governance': ['Naming']

  describe input('resource_group_name') do
    # Example naming convention: rg-{project}-{environment}
    it { should match(/^rg-[a-z0-9-]+-[a-z]+$/) }
  end

  describe azurerm_resource_group(name: input('resource_group_name')) do
    it { should exist }
  end
end

control 'resourcegroup-contained-resources-compliance' do
  impact 0.4
  title 'Resources within Resource Group should be compliant'
  desc 'All resources within the Resource Group should follow organizational standards'
  desc 'rationale', 'Resource-level compliance ensures overall security and governance posture'
  desc 'remediation', 'Review and remediate non-compliant resources within the Resource Group'
  tag 'Governance': ['Resource Management']

  describe azurerm_resource_group(name: input('resource_group_name')) do
    it { should exist }
  end

  # Get all resources in the resource group
  resources = azurerm_resources(resource_group: input('resource_group_name'))
  
  describe resources do
    it { should_not be_empty }
    
    # Verify all resources have required tags (inherited or explicit)
    input('required_tags').each do |required_tag|
      its('entries') do
        should all(satisfy do |resource|
          resource_tags = resource[:tags] || {}
          rg_tags = azurerm_resource_group(name: input('resource_group_name')).tags || {}
          resource_tags.key?(required_tag) || rg_tags.key?(required_tag)
        end)
      end
    end
  end
end

control 'resourcegroup-cost-management-tags' do
  impact 0.4
  title 'Resource Group should have cost management tags'
  desc 'Resource Group should have tags specifically for cost management and allocation'
  desc 'rationale', 'Cost management tags enable accurate cost allocation and budgeting'
  desc 'remediation', 'Add cost management specific tags to the Resource Group'
  tag 'Governance': ['Cost Management']

  cost_tags = ['cost-center', 'budget-code', 'project']
  
  describe azurerm_resource_group(name: input('resource_group_name')) do
    it { should exist }
    
    cost_tags.each do |tag|
      context "Cost management tag: #{tag}" do
        its('tags') { should include(tag) }
        its("tags.#{tag}") { should_not be_empty }
      end
    end
  end
end
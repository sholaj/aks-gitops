# Compliance Frameworks Library
# Maps controls to various compliance frameworks

class ComplianceFrameworks
  # CIS Azure Foundations Benchmark mappings
  CIS_MAPPINGS = {
    'aks-rbac-enabled' => ['CIS-5.2.1'],
    'aks-network-policy-enabled' => ['CIS-5.3.2'],
    'aks-node-pool-encryption' => ['CIS-2.1.1'],
    'aks-api-server-authorized-ip-ranges' => ['CIS-4.2.1'],
    'aks-private-cluster' => ['CIS-4.2.2'],
    'keyvault-soft-delete-enabled' => ['CIS-8.1'],
    'keyvault-purge-protection-enabled' => ['CIS-8.2'],
    'keyvault-network-access-restrictions' => ['CIS-8.3'],
    'keyvault-key-expiration-policy' => ['CIS-8.5'],
    'uami-role-assignments-principle-of-least-privilege' => ['CIS-1.21'],
    'resourcegroup-resource-locks' => ['CIS-1.15'],
    'vnet-nsg-associations' => ['CIS-6.2']
  }.freeze

  # Azure Security Benchmark mappings
  ASB_MAPPINGS = {
    'aks-rbac-enabled' => ['ASB-4.1'],
    'aks-network-policy-enabled' => ['ASB-9.2'],
    'aks-node-pool-encryption' => ['ASB-8.1'],
    'aks-cluster-monitoring' => ['ASB-6.3'],
    'aks-api-server-authorized-ip-ranges' => ['ASB-9.1'],
    'aks-private-cluster' => ['ASB-9.3'],
    'aks-azure-ad-integration' => ['ASB-4.2'],
    'keyvault-soft-delete-enabled' => ['ASB-10.1'],
    'keyvault-purge-protection-enabled' => ['ASB-10.2'],
    'keyvault-network-access-restrictions' => ['ASB-9.4'],
    'keyvault-rbac-enabled' => ['ASB-4.3'],
    'keyvault-logging-enabled' => ['ASB-6.1'],
    'keyvault-private-endpoint' => ['ASB-9.5'],
    'uami-exists-and-active' => ['ASB-4.4'],
    'uami-role-assignments-principle-of-least-privilege' => ['ASB-4.5'],
    'uami-federated-credentials-configuration' => ['ASB-4.6'],
    'resourcegroup-exists-and-active' => ['ASB-11.1'],
    'resourcegroup-resource-locks' => ['ASB-11.2'],
    'resourcegroup-policy-compliance' => ['ASB-11.3'],
    'vnet-exists-and-configured' => ['ASB-9.6'],
    'vnet-nsg-associations' => ['ASB-9.7'],
    'vnet-service-endpoints-configured' => ['ASB-9.8'],
    'vnet-peering-security' => ['ASB-9.9'],
    'vnet-ddos-protection' => ['ASB-9.10']
  }.freeze

  # NIST Cybersecurity Framework mappings
  NIST_MAPPINGS = {
    'aks-rbac-enabled' => ['AC-3'],
    'aks-network-policy-enabled' => ['SC-7'],
    'aks-node-pool-encryption' => ['SC-28'],
    'aks-cluster-monitoring' => ['SI-4'],
    'aks-api-server-authorized-ip-ranges' => ['AC-3'],
    'aks-azure-ad-integration' => ['IA-2'],
    'keyvault-soft-delete-enabled' => ['CP-9'],
    'keyvault-purge-protection-enabled' => ['CP-9'],
    'keyvault-network-access-restrictions' => ['AC-3'],
    'keyvault-logging-enabled' => ['AU-2'],
    'keyvault-private-endpoint' => ['SC-7'],
    'uami-exists-and-active' => ['IA-2'],
    'uami-role-assignments-principle-of-least-privilege' => ['AC-6'],
    'uami-federated-credentials-configuration' => ['IA-2'],
    'resourcegroup-resource-locks' => ['CP-9'],
    'vnet-nsg-associations' => ['SC-7'],
    'vnet-peering-security' => ['SC-7'],
    'vnet-ddos-protection' => ['SC-5']
  }.freeze

  # Get compliance mappings for a control
  def self.get_mappings_for_control(control_id)
    {
      'CIS' => CIS_MAPPINGS[control_id] || [],
      'Azure Security Benchmark' => ASB_MAPPINGS[control_id] || [],
      'NIST' => NIST_MAPPINGS[control_id] || []
    }
  end

  # Get all controls for a specific framework
  def self.get_controls_for_framework(framework)
    case framework.upcase
    when 'CIS'
      CIS_MAPPINGS.keys
    when 'ASB', 'AZURE SECURITY BENCHMARK'
      ASB_MAPPINGS.keys
    when 'NIST'
      NIST_MAPPINGS.keys
    else
      []
    end
  end

  # Generate compliance report
  def self.generate_compliance_report(results, frameworks = ['CIS', 'ASB', 'NIST'])
    report = {}
    
    frameworks.each do |framework|
      report[framework] = {
        'total_controls' => 0,
        'passed_controls' => 0,
        'failed_controls' => 0,
        'skipped_controls' => 0,
        'compliance_percentage' => 0.0,
        'control_results' => []
      }
    end

    results.each do |result|
      control_id = result[:control_id]
      status = result[:status] # 'passed', 'failed', 'skipped'
      
      frameworks.each do |framework|
        mappings = get_mappings_for_control(control_id)
        next if mappings[framework].empty?
        
        report[framework]['total_controls'] += 1
        report[framework]["#{status}_controls"] += 1
        report[framework]['control_results'] << {
          'control_id' => control_id,
          'status' => status,
          'framework_mappings' => mappings[framework]
        }
      end
    end

    # Calculate compliance percentages
    frameworks.each do |framework|
      total = report[framework]['total_controls']
      passed = report[framework]['passed_controls']
      
      if total > 0
        report[framework]['compliance_percentage'] = (passed.to_f / total * 100).round(2)
      end
    end

    report
  end

  # Validate framework coverage
  def self.validate_framework_coverage(profile_controls, required_frameworks)
    coverage_report = {}
    
    required_frameworks.each do |framework|
      framework_controls = get_controls_for_framework(framework)
      covered_controls = profile_controls & framework_controls
      
      coverage_report[framework] = {
        'total_framework_controls' => framework_controls.length,
        'covered_controls' => covered_controls.length,
        'coverage_percentage' => framework_controls.empty? ? 0 : (covered_controls.length.to_f / framework_controls.length * 100).round(2),
        'missing_controls' => framework_controls - covered_controls
      }
    end
    
    coverage_report
  end
end
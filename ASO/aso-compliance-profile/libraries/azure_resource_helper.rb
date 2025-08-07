# Azure Resource Helper Library
# Provides custom helper methods for Azure resource testing

class AzureResourceHelper
  # Check if a resource has all required tags
  def self.has_required_tags?(resource_tags, required_tags)
    return false if resource_tags.nil? || required_tags.nil?
    
    required_tags.all? do |tag|
      resource_tags.key?(tag) && !resource_tags[tag].nil? && !resource_tags[tag].empty?
    end
  end

  # Validate resource naming convention
  def self.follows_naming_convention?(resource_name, pattern)
    return false if resource_name.nil? || pattern.nil?
    
    resource_name.match?(Regexp.new(pattern))
  end

  # Check if resource is in approved regions
  def self.in_approved_region?(resource_location, approved_regions)
    return false if resource_location.nil? || approved_regions.nil?
    
    approved_regions.include?(resource_location.downcase)
  end

  # Convert CIDR to subnet size
  def self.cidr_to_host_count(cidr)
    return 0 if cidr.nil?
    
    prefix_length = cidr.split('/').last.to_i
    host_bits = 32 - prefix_length
    (2 ** host_bits) - 2  # Subtract network and broadcast addresses
  end

  # Check if IP range is private (RFC 1918)
  def self.is_private_ip_range?(ip_range)
    return false if ip_range.nil?
    
    private_ranges = [
      /^10\./,
      /^172\.(1[6-9]|2[0-9]|3[0-1])\./,
      /^192\.168\./
    ]
    
    private_ranges.any? { |range| ip_range.match(range) }
  end

  # Validate Azure resource ID format
  def self.valid_azure_resource_id?(resource_id)
    return false if resource_id.nil?
    
    # Azure resource ID pattern
    pattern = %r{^/subscriptions/[a-f0-9-]+/resourceGroups/[^/]+/providers/[^/]+/[^/]+/[^/]+}
    resource_id.match?(pattern)
  end

  # Check if a role is considered high-privilege
  def self.is_high_privilege_role?(role_name)
    high_privilege_roles = [
      'Owner',
      'Contributor',
      'User Access Administrator',
      'Security Admin',
      'Global Administrator',
      'Privileged Role Administrator'
    ]
    
    high_privilege_roles.include?(role_name)
  end

  # Parse Azure resource type from resource ID
  def self.extract_resource_type(resource_id)
    return nil if resource_id.nil?
    
    parts = resource_id.split('/')
    provider_index = parts.index { |part| part == 'providers' }
    return nil if provider_index.nil? || provider_index >= parts.length - 2
    
    "#{parts[provider_index + 1]}/#{parts[provider_index + 2]}"
  end

  # Validate environment-specific requirements
  def self.validate_environment_requirements(environment, resource_config)
    case environment.downcase
    when 'prod', 'production'
      validate_production_requirements(resource_config)
    when 'staging', 'stage'
      validate_staging_requirements(resource_config)
    when 'dev', 'development'
      validate_development_requirements(resource_config)
    else
      { valid: false, errors: ["Unknown environment: #{environment}"] }
    end
  end

  private

  def self.validate_production_requirements(config)
    errors = []
    
    # Production-specific validations
    errors << "High availability should be enabled" unless config[:high_availability]
    errors << "Backup should be enabled" unless config[:backup_enabled]
    errors << "Monitoring should be enabled" unless config[:monitoring_enabled]
    errors << "Private endpoints should be used" unless config[:private_endpoints]
    
    { valid: errors.empty?, errors: errors }
  end

  def self.validate_staging_requirements(config)
    errors = []
    
    # Staging-specific validations
    errors << "Monitoring should be enabled" unless config[:monitoring_enabled]
    
    { valid: errors.empty?, errors: errors }
  end

  def self.validate_development_requirements(config)
    # Development environments have relaxed requirements
    { valid: true, errors: [] }
  end
end
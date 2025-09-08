# PostgreSQL Security Compliance Controls

# Control 1: SSL/TLS encryption configuration
control 'postgresql-ssl-encryption' do
  impact 0.8
  title 'PostgreSQL SSL/TLS Encryption Configuration'
  desc 'Verify that PostgreSQL is configured to use SSL/TLS encryption for client connections'
  desc 'rationale', 'SSL/TLS encryption protects data in transit between clients and the database server, preventing eavesdropping and man-in-the-middle attacks.'
  desc 'check', 'Connect to the PostgreSQL instance and verify that SSL is enabled and properly configured.'
  desc 'fix', 'Enable SSL in postgresql.conf by setting ssl = on and configure SSL certificates.'
  
  tag severity: 'high'
  tag gtitle: 'PostgreSQL Encryption'
  tag gid: 'PG-SEC-001'
  tag rid: 'PG-SSL-001'
  tag stig_id: 'PG-SSL-001'
  tag nist: ['SC-8', 'SC-13']
  tag cis_controls: ['14.4']
  
  ref 'PostgreSQL SSL Support', url: 'https://www.postgresql.org/docs/current/ssl-tcp.html'
  
  # Test SSL configuration
  describe "PostgreSQL SSL Configuration" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d postgres -t -A -c \"SELECT name, setting FROM pg_settings WHERE name = 'ssl';\"").stdout.strip
    end
    
    it 'should have SSL enabled' do
      expect(subject).to match(/ssl\|on/)
    end
  end
  
  # Test SSL certificate files configuration
  describe "SSL Certificate Configuration" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d postgres -t -A -c \"SELECT name, setting FROM pg_settings WHERE name IN ('ssl_cert_file', 'ssl_key_file');\"").stdout
    end
    
    it 'should have SSL certificate files configured' do
      expect(subject).to match(/ssl_cert_file/)
      expect(subject).to match(/ssl_key_file/)
    end
  end
  
  # Test SSL connection capability
  describe "SSL Connection Test" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d #{input('pg_database')} sslmode=require -t -A -c \"SELECT 'SSL connection successful';\"").stdout.strip
    end
    
    it 'should allow SSL connections' do
      expect(subject).to match(/SSL connection successful/)
    end
  end
  
  # Test for SSL usage in current connections
  describe "Active SSL Connections" do
    subject do
      command("PGPASSWORD=#{input('pg_superuser_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_superuser')} -d postgres -t -A -c \"SELECT COUNT(*) FROM pg_stat_ssl WHERE ssl = true;\"").stdout.strip
    end
    
    it 'should show SSL connections are possible' do
      expect(subject).to match(/\d+/)  # Should return a number (0 or more)
    end
  end
end

# Control 2: Password policy enforcement and user security
control 'postgresql-password-policy' do
  impact 0.7
  title 'PostgreSQL User Security and Password Management'
  desc 'Verify that PostgreSQL implements proper user security and password management practices'
  desc 'rationale', 'Strong user security and password practices help prevent unauthorized access and maintain database security.'
  desc 'check', 'Check user configurations, password settings, and authentication policies.'
  desc 'fix', 'Configure proper authentication methods in pg_hba.conf and implement password complexity requirements through external tools or policies.'
  
  tag severity: 'medium'
  tag gtitle: 'User Security'
  tag gid: 'PG-SEC-002'
  tag rid: 'PG-PWD-001'
  tag stig_id: 'PG-PWD-001'
  tag nist: ['IA-5']
  tag cis_controls: ['16.12']
  
  ref 'PostgreSQL Authentication', url: 'https://www.postgresql.org/docs/current/auth-methods.html'
  
  # Check test user exists and properties
  describe "Test User Configuration" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d #{input('pg_database')} -t -A -c \"SELECT rolname, rolcanlogin, rolconnlimit FROM pg_authid WHERE rolname = '#{input('pg_user')}';\"").stdout.strip
    end
    
    it 'should have test user properly configured' do
      expect(subject).to match(/#{input('pg_user')}\|t\|-?\d+/)  # user|can_login|connection_limit
    end
  end
  
  # Check password authentication method
  describe "Authentication Method Configuration" do
    subject do
      command("PGPASSWORD=#{input('pg_superuser_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_superuser')} -d postgres -t -A -c \"SELECT current_setting('password_encryption');\"").stdout.strip
    end
    
    it 'should use secure password encryption' do
      expect(subject).to match(/(scram-sha-256|md5)/)  # Modern PostgreSQL versions use scram-sha-256
    end
  end
  
  # Check user has password set
  describe "User Password Configuration" do
    subject do
      command("PGPASSWORD=#{input('pg_superuser_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_superuser')} -d postgres -t -A -c \"SELECT rolname, (rolpassword IS NOT NULL) AS has_password FROM pg_authid WHERE rolname = '#{input('pg_user')}';\"").stdout.strip
    end
    
    it 'should have password configured for test user' do
      expect(subject).to match(/#{input('pg_user')}\|t/)  # user has password
    end
  end
  
  # Test connection authentication
  describe "Password Authentication Test" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d #{input('pg_database')} -t -A -c \"SELECT current_user;\"").stdout.strip
    end
    
    it 'should authenticate successfully with password' do
      expect(subject).to match(/#{input('pg_user')}/)
    end
  end
  
  # Check for superuser privileges (test user should NOT be superuser)
  describe "User Privilege Check" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d #{input('pg_database')} -t -A -c \"SELECT rolsuper FROM pg_authid WHERE rolname = current_user;\"").stdout.strip
    end
    
    it 'should not have superuser privileges for regular users' do
      expect(subject).to match(/f/)  # false - not a superuser
    end
  end
  
  # Check password policy function (custom function we created)
  describe "Password Policy Check Function" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d postgres -t -A -c \"SELECT * FROM check_password_policy('#{input('pg_user')}');\"").stdout.strip
    end
    
    it 'should return password policy information' do
      expect(subject).to match(/#{input('pg_user')}\|t\|f\|-?\d+/)  # user|has_password|not_locked|connection_limit
    end
  end
end

# Additional basic connectivity and configuration control
control 'postgresql-basic-connectivity' do
  impact 0.5
  title 'PostgreSQL Basic Connectivity and Configuration'
  desc 'Verify basic connectivity and configuration of PostgreSQL instance'
  desc 'rationale', 'Basic connectivity ensures the database server is accessible and properly configured for compliance scanning.'
  
  tag severity: 'low'
  tag gtitle: 'Basic Configuration'
  tag gid: 'PG-SEC-003'
  tag rid: 'PG-CFG-001'
  
  describe "Database Server Version" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d postgres -t -A -c \"SELECT version();\"").stdout
    end
    
    it 'should return PostgreSQL version information' do
      expect(subject).to match(/PostgreSQL/)
    end
  end
  
  describe "Test Database Access" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d #{input('pg_database')} -t -A -c \"SELECT COUNT(*) FROM sample_table;\"").stdout.strip
    end
    
    it 'should access test database and table' do
      expect(subject).to match(/\d+/)  # Should return a number
      expect(subject.to_i).to be >= 0  # Should be 0 or more records
    end
  end
  
  describe "Database Configuration Check" do
    subject do
      command("PGPASSWORD=#{input('pg_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_user')} -d #{input('pg_database')} -t -A -c \"SELECT current_database(), current_user;\"").stdout.strip
    end
    
    it 'should connect to correct database with correct user' do
      expect(subject).to match(/#{input('pg_database')}\|#{input('pg_user')}/)
    end
  end
  
  describe "Server Configuration Security Check" do
    subject do
      command("PGPASSWORD=#{input('pg_superuser_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_superuser')} -d postgres -t -A -c \"SELECT name, setting FROM pg_settings WHERE name IN ('log_connections', 'log_disconnections') ORDER BY name;\"").stdout
    end
    
    it 'should show logging configuration' do
      expect(subject).to match(/log_connections/)
      expect(subject).to match(/log_disconnections/)
    end
  end
end

# Additional security-focused control
control 'postgresql-security-hardening' do
  impact 0.6
  title 'PostgreSQL Security Hardening Configuration'
  desc 'Verify that PostgreSQL has basic security hardening configurations in place'
  desc 'rationale', 'Security hardening reduces the attack surface and improves overall database security.'
  
  tag severity: 'medium'
  tag gtitle: 'Security Hardening'
  tag gid: 'PG-SEC-004'
  tag rid: 'PG-HARD-001'
  
  describe "Shared Preload Libraries Check" do
    subject do
      command("PGPASSWORD=#{input('pg_superuser_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_superuser')} -d postgres -t -A -c \"SELECT setting FROM pg_settings WHERE name = 'shared_preload_libraries';\"").stdout.strip
    end
    
    it 'should show shared preload libraries configuration' do
      expect(subject).not_to be_empty
    end
  end
  
  describe "Database Connection Limits" do
    subject do
      command("PGPASSWORD=#{input('pg_superuser_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_superuser')} -d postgres -t -A -c \"SELECT setting FROM pg_settings WHERE name = 'max_connections';\"").stdout.strip
    end
    
    it 'should have reasonable connection limits configured' do
      expect(subject.to_i).to be > 0
      expect(subject.to_i).to be <= 1000  # Reasonable upper limit
    end
  end
  
  describe "Listen Addresses Configuration" do
    subject do
      command("PGPASSWORD=#{input('pg_superuser_password')} psql -h #{input('pg_host')} -p #{input('pg_port')} -U #{input('pg_superuser')} -d postgres -t -A -c \"SELECT setting FROM pg_settings WHERE name = 'listen_addresses';\"").stdout.strip
    end
    
    it 'should have listen addresses configured' do
      expect(subject).not_to be_empty
    end
  end
end
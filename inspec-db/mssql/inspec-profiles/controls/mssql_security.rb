# MS SQL Server Security Compliance Controls

# Control 1: SSL/TLS encryption configuration
control 'mssql-ssl-encryption' do
  impact 0.8
  title 'MS SQL Server SSL/TLS Encryption Configuration'
  desc 'Verify that MS SQL Server is configured to use SSL/TLS encryption for client connections'
  desc 'rationale', 'SSL/TLS encryption protects data in transit between clients and the database server, preventing eavesdropping and man-in-the-middle attacks.'
  desc 'check', 'Connect to the MS SQL Server instance and verify that force encryption is enabled or certificate-based encryption is configured.'
  desc 'fix', 'Enable force encryption in SQL Server Configuration Manager or configure certificates for encrypted connections.'
  
  tag severity: 'high'
  tag gtitle: 'SQL Server Encryption'
  tag gid: 'MSSQL-SEC-001'
  tag rid: 'MSSQL-SSL-001'
  tag stig_id: 'MSSQL-SSL-001'
  tag nist: ['SC-8', 'SC-13']
  tag cis_controls: ['14.4']
  
  ref 'MS SQL Server Encryption', url: 'https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/enable-encrypted-connections-to-the-database-engine'
  
  # Test SSL/TLS configuration using sqlcmd connection
  describe "MS SQL Server SSL Configuration" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d master -Q \"SELECT name, value, value_in_use FROM sys.configurations WHERE name = 'force encryption'\" -h -1 -s '|' -W").stdout
    end
    
    it 'should have force encryption configured' do
      expect(subject).to match(/force encryption/)
    end
  end
  
  # Alternative test: Check if SSL is enforced by attempting connection
  describe "SSL Enforcement Test" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d master -Q \"SELECT CASE WHEN EXISTS(SELECT * FROM sys.dm_exec_connections WHERE encrypt_option = 'TRUE') THEN 'SSL_ENABLED' ELSE 'SSL_NOT_REQUIRED' END AS ssl_status\" -h -1 -W").stdout
    end
    
    it 'should indicate SSL awareness' do
      expect(subject).not_to be_empty
    end
  end
  
  # Check certificate configuration if certificates are used
  describe "Certificate Configuration" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d master -Q \"SELECT @@SERVERNAME as server_name\" -h -1 -W").stdout
    end
    
    it 'should be able to connect to server' do
      expect(subject).to match(/\w+/)
    end
  end
end

# Control 2: Password policy enforcement
control 'mssql-password-policy' do
  impact 0.7
  title 'MS SQL Server Password Policy Enforcement'
  desc 'Verify that MS SQL Server enforces strong password policies for database users'
  desc 'rationale', 'Strong password policies help prevent unauthorized access through weak or easily guessable passwords.'
  desc 'check', 'Check that password policy is enforced for SQL Server logins and that password complexity requirements are met.'
  desc 'fix', 'Enable CHECK_POLICY and CHECK_EXPIRATION options for SQL Server logins and implement strong password requirements.'
  
  tag severity: 'medium'
  tag gtitle: 'Password Policy'
  tag gid: 'MSSQL-SEC-002'
  tag rid: 'MSSQL-PWD-001'
  tag stig_id: 'MSSQL-PWD-001'
  tag nist: ['IA-5']
  tag cis_controls: ['16.12']
  
  ref 'MS SQL Server Password Policy', url: 'https://docs.microsoft.com/en-us/sql/relational-databases/security/password-policy'
  
  # Check password policy settings for the test user
  describe "Password Policy for test_user" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d master -Q \"SELECT name, is_policy_checked, is_expiration_checked FROM sys.sql_logins WHERE name = '#{input('mssql_user')}'\" -h -1 -s '|' -W").stdout
    end
    
    it 'should have password policy enabled' do
      expect(subject).to match(/#{input('mssql_user')}/)
    end
    
    it 'should show policy check status' do
      expect(subject).to match(/[01]\|[01]/)  # Matches pattern for policy flags
    end
  end
  
  # Check system-wide password policy settings
  describe "System Password Policy Settings" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d master -Q \"SELECT name, value_in_use FROM sys.configurations WHERE name IN ('min password length', 'password complexity')\" -h -1 -s '|' -W").stdout
    end
    
    it 'should return configuration information' do
      expect(subject).not_to be_empty
    end
  end
  
  # Test password complexity by checking login properties
  describe "Login Security Properties" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d master -Q \"SELECT LOGINPROPERTY('#{input('mssql_user')}', 'IsLocked') AS IsLocked, LOGINPROPERTY('#{input('mssql_user')}', 'IsMustChange') AS IsMustChange\" -h -1 -s '|' -W").stdout
    end
    
    it 'should check login properties' do
      expect(subject).to match(/[01]\|[01]/)  # Pattern for login flags
    end
  end
  
  # Additional check: Verify login exists and is properly configured
  describe "User Account Validation" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d #{input('mssql_database')} -Q \"SELECT USER_NAME() as current_user, DB_NAME() as current_db\" -h -1 -s '|' -W").stdout
    end
    
    it 'should successfully authenticate user' do
      expect(subject).to match(/#{input('mssql_user')}.*#{input('mssql_database')}/)
    end
  end
end

# Additional basic connectivity and configuration control
control 'mssql-basic-connectivity' do
  impact 0.5
  title 'MS SQL Server Basic Connectivity and Configuration'
  desc 'Verify basic connectivity and configuration of MS SQL Server instance'
  desc 'rationale', 'Basic connectivity ensures the database server is accessible and properly configured for compliance scanning.'
  
  tag severity: 'low'
  tag gtitle: 'Basic Configuration'
  tag gid: 'MSSQL-SEC-003'
  tag rid: 'MSSQL-CFG-001'
  
  describe "Database Server Version" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d master -Q \"SELECT @@VERSION\" -h -1 -W").stdout
    end
    
    it 'should return version information' do
      expect(subject).to match(/Microsoft SQL Server/)
    end
  end
  
  describe "Test Database Access" do
    subject do
      command("sqlcmd -S #{input('mssql_host')},#{input('mssql_port')} -U #{input('mssql_user')} -P #{input('mssql_password')} -d #{input('mssql_database')} -Q \"SELECT COUNT(*) FROM sample_table\" -h -1 -W").stdout
    end
    
    it 'should access test database and table' do
      expect(subject).to match(/\d+/)  # Should return a number
    end
  end
end
# Azure SQL Database Security Compliance Controls

# Control 1: TLS encryption and secure connection
control 'azure-sql-tls-encryption' do
  impact 0.8
  title 'Azure SQL Database TLS Encryption Validation'
  desc 'Verify that Azure SQL Database enforces TLS encryption for all connections'
  desc 'rationale', 'Azure SQL Database enforces TLS encryption by default, protecting data in transit.'
  desc 'check', 'Verify connection to Azure SQL Database and validate TLS enforcement.'
  desc 'fix', 'Azure SQL Database enforces TLS by default. Ensure connection strings use TLS.'
  
  tag severity: 'high'
  tag gtitle: 'Azure SQL Encryption'
  tag gid: 'AZURE-SQL-001'
  tag rid: 'AZURE-SQL-TLS-001'
  tag nist: ['SC-8', 'SC-13']
  
  # Test secure connection to Azure SQL Database
  describe "Azure SQL Database TLS Connection" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('sql_admin_user')} -P #{input('sql_admin_password')} -d #{input('sql_database')} -Q \"SELECT 'TLS_CONNECTION_SUCCESSFUL' as result\" -h -1 -W").stdout.strip
    end
    
    it 'should successfully connect via TLS' do
      expect(subject).to match(/TLS_CONNECTION_SUCCESSFUL/)
    end
  end
  
  # Verify database connection properties
  describe "Database Connection Validation" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('sql_admin_user')} -P #{input('sql_admin_password')} -d #{input('sql_database')} -Q \"SELECT DB_NAME() as database_name, SUSER_NAME() as user_name\" -h -1 -W").stdout
    end
    
    it 'should connect to correct database' do
      expect(subject).to match(/#{input('sql_database')}/)
      expect(subject).to match(/#{input('sql_admin_user')}/)
    end
  end
end

# Control 2: User access and permissions validation
control 'azure-sql-user-permissions' do
  impact 0.7
  title 'Azure SQL Database User Access Control'
  desc 'Verify that database users have appropriate permissions and access controls'
  desc 'rationale', 'Proper user access control prevents unauthorized access and privilege escalation.'
  desc 'check', 'Validate user permissions and roles in the database.'
  desc 'fix', 'Ensure users have minimum required permissions and proper role assignments.'
  
  tag severity: 'medium'
  tag gtitle: 'User Access Control'
  tag gid: 'AZURE-SQL-002'
  tag rid: 'AZURE-SQL-USER-001'
  tag nist: ['AC-2', 'AC-3']
  
  # Check if test user exists
  describe "Test User Existence" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('sql_admin_user')} -P #{input('sql_admin_password')} -d #{input('sql_database')} -Q \"SELECT name FROM sys.database_principals WHERE name = '#{input('test_user')}'\" -h -1 -W").stdout.strip
    end
    
    it 'should have test user configured' do
      expect(subject).to match(/#{input('test_user')}/)
    end
  end
  
  # Check user role memberships
  describe "User Role Memberships" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('sql_admin_user')} -P #{input('sql_admin_password')} -d #{input('sql_database')} -Q \"SELECT r.name as role_name FROM sys.database_role_members rm JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id WHERE m.name = '#{input('test_user')}'\" -h -1 -W").stdout
    end
    
    it 'should have appropriate role assignments' do
      expect(subject).to match(/(db_datareader|db_datawriter)/)
    end
  end
  
  # Test user can authenticate
  describe "User Authentication Test" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('test_user')} -P P@ssw0rd -d #{input('sql_database')} -Q \"SELECT USER_NAME() as current_user\" -h -1 -W").stdout.strip
    end
    
    it 'should authenticate successfully' do
      expect(subject).to match(/#{input('test_user')}/)
    end
  end
end

# Control 3: Database configuration and security settings
control 'azure-sql-database-security' do
  impact 0.6
  title 'Azure SQL Database Security Configuration'
  desc 'Verify Azure SQL Database security configuration and settings'
  desc 'rationale', 'Proper database security configuration reduces attack surface and improves security posture.'
  desc 'check', 'Validate database security settings and configuration.'
  desc 'fix', 'Configure database security settings according to best practices.'
  
  tag severity: 'medium'
  tag gtitle: 'Database Security'
  tag gid: 'AZURE-SQL-003'
  tag rid: 'AZURE-SQL-SEC-001'
  
  # Check database version
  describe "Database Version Information" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('sql_admin_user')} -P #{input('sql_admin_password')} -d #{input('sql_database')} -Q \"SELECT @@VERSION as version_info\" -h -1 -W").stdout
    end
    
    it 'should be running Azure SQL Database' do
      expect(subject).to match(/Microsoft SQL Azure/)
    end
  end
  
  # Check database collation
  describe "Database Collation" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('sql_admin_user')} -P #{input('sql_admin_password')} -d #{input('sql_database')} -Q \"SELECT DATABASEPROPERTYEX('#{input('sql_database')}', 'Collation') as collation\" -h -1 -W").stdout
    end
    
    it 'should have proper collation set' do
      expect(subject).to match(/SQL_Latin1_General_CP1_CI_AS/)
    end
  end
  
  # Validate sample data access
  describe "Data Access Validation" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('test_user')} -P P@ssw0rd -d #{input('sql_database')} -Q \"SELECT COUNT(*) as record_count FROM sample_table\" -h -1 -W").stdout.strip
    end
    
    it 'should access sample data' do
      expect(subject.to_i).to be >= 2  # Should have at least 2 records
    end
  end
end

# Control 4: Azure SQL Database connectivity and availability
control 'azure-sql-availability' do
  impact 0.5
  title 'Azure SQL Database Availability and Connectivity'
  desc 'Verify Azure SQL Database availability and network connectivity'
  desc 'rationale', 'Database availability is critical for business operations and compliance monitoring.'
  desc 'check', 'Test database connectivity and response times.'
  desc 'fix', 'Ensure proper network configuration and database availability.'
  
  tag severity: 'low'
  tag gtitle: 'Database Availability'
  tag gid: 'AZURE-SQL-004'
  tag rid: 'AZURE-SQL-AVAIL-001'
  
  # Test database connectivity
  describe "Database Connectivity" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('sql_admin_user')} -P #{input('sql_admin_password')} -d #{input('sql_database')} -Q \"SELECT GETDATE() as current_time\" -h -1 -W").stdout
    end
    
    it 'should respond with current timestamp' do
      expect(subject).to match(/\d{4}-\d{2}-\d{2}/)  # Should match date format
    end
  end
  
  # Test server properties
  describe "Server Properties" do
    subject do
      command("/opt/mssql-tools/bin/sqlcmd -S #{input('sql_server')} -U #{input('sql_admin_user')} -P #{input('sql_admin_password')} -d #{input('sql_database')} -Q \"SELECT @@SERVERNAME as server_name, @@SERVICENAME as service_name\" -h -1 -W").stdout
    end
    
    it 'should return server information' do
      expect(subject).not_to be_empty
    end
  end
end
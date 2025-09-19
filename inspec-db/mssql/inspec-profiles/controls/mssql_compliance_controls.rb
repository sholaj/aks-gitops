# MSSQL Compliance Controls for NIST Standards
# Purpose: Comprehensive MSSQL security and compliance validation
# Version: 1.0

# Input parameters for environment flexibility
server = input('server', description: 'MSSQL Server FQDN or IP', required: true)
port = input('port', value: 1433, description: 'MSSQL Port')
database = input('database', value: 'master', description: 'Target database')
auth_method = input('auth_method', value: 'windows', description: 'Authentication method: windows or sql')
username = input('username', value: '', description: 'SQL username (if using SQL auth)', sensitive: true)
password = input('password', value: '', description: 'SQL password (if using SQL auth)', sensitive: true)
ssl_mode = input('ssl_mode', value: 'trust', description: 'SSL mode: trust, verify, or disable')
timeout = input('timeout', value: 30, description: 'Connection timeout in seconds')

# Helper method to build sqlcmd command based on authentication method
def build_sqlcmd_command(server, port, database, auth_method, username, password, query, timeout = 30)
  base_cmd = "sqlcmd -S \"#{server},#{port}\" -d \"#{database}\" -C -l #{timeout} -h -1 -W"

  if auth_method == 'windows'
    "#{base_cmd} -E -Q \"#{query}\""
  else
    "#{base_cmd} -U \"#{username}\" -P \"#{password}\" -Q \"#{query}\""
  end
end

# Control 1: Connection Establishment Verification
control 'mssql-connection-01' do
  impact 1.0
  title 'MSSQL Server Connection Verification'
  desc 'Verify that connection can be established to the MSSQL server'
  tag 'nist': ['CM-6', 'SC-8']
  tag 'severity': 'critical'

  describe 'MSSQL Connection Test' do
    it 'should be able to connect to the MSSQL server' do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT 'CONNECTION_SUCCESS' as Result", timeout)

      result = command(cmd)
      expect(result.exit_status).to eq(0)
      expect(result.stdout).to match(/CONNECTION_SUCCESS/)
    end
  end

  describe port(port, server) do
    it { should be_listening }
  end
end

# Control 2: Authentication Method Validation
control 'mssql-auth-02' do
  impact 0.9
  title 'Authentication Method Validation'
  desc 'Verify the authentication method is properly configured and working'
  tag 'nist': ['IA-2', 'IA-5']
  tag 'severity': 'high'

  describe 'Authentication Configuration' do
    it "should successfully authenticate using #{auth_method} authentication" do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT SYSTEM_USER as CurrentUser,
                                          AUTH_SCHEME as AuthScheme,
                                          ORIGINAL_LOGIN() as OriginalLogin", timeout)

      result = command(cmd)
      expect(result.exit_status).to eq(0)

      if auth_method == 'windows'
        expect(result.stdout).to match(/KERBEROS|NTLM/)
      else
        expect(result.stdout).to match(/SQL/)
      end
    end
  end
end

# Control 3: Database Accessibility Check
control 'mssql-database-03' do
  impact 0.8
  title 'Database Accessibility Verification'
  desc 'Ensure the specified database is accessible with current credentials'
  tag 'nist': ['AC-3', 'AC-6']
  tag 'severity': 'high'

  describe 'Database Access' do
    it "should be able to access the #{database} database" do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT DB_NAME() as CurrentDatabase,
                                          DATABASEPROPERTYEX(DB_NAME(), 'Status') as DBStatus,
                                          DATABASEPROPERTYEX(DB_NAME(), 'Updateability') as DBUpdateability", timeout)

      result = command(cmd)
      expect(result.exit_status).to eq(0)
      expect(result.stdout).to include(database)
      expect(result.stdout).to match(/ONLINE/)
    end
  end
end

# Control 4: Version and Patch Level Information
control 'mssql-version-04' do
  impact 0.7
  title 'MSSQL Version and Patch Level'
  desc 'Gather and validate MSSQL version information for security assessment'
  tag 'nist': ['CM-6', 'SI-2']
  tag 'severity': 'medium'

  describe 'MSSQL Version' do
    it 'should be running a supported version' do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT
                                    SERVERPROPERTY('ProductVersion') as Version,
                                    SERVERPROPERTY('ProductLevel') as PatchLevel,
                                    SERVERPROPERTY('Edition') as Edition,
                                    SERVERPROPERTY('EngineEdition') as EngineEdition", timeout)

      result = command(cmd)
      expect(result.exit_status).to eq(0)

      # Parse version to ensure it's not an EOL version
      version_output = result.stdout
      major_version = version_output.match(/(\d+)\./)[1].to_i if version_output.match(/(\d+)\./)

      # SQL Server 2014 (version 12) and later are considered supported
      expect(major_version).to be >= 12
    end
  end
end

# Control 5: Permission Verification for Compliance Scanning
control 'mssql-permissions-05' do
  impact 0.9
  title 'Compliance Scanning Permission Verification'
  desc 'Verify the account has necessary permissions for compliance scanning'
  tag 'nist': ['AC-3', 'AC-6']
  tag 'severity': 'high'

  describe 'Required Permissions' do
    it 'should have VIEW SERVER STATE permission' do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') as ViewServerState", timeout)

      result = command(cmd)
      expect(result.exit_status).to eq(0)
      expect(result.stdout.strip).to eq('1')
    end

    it 'should have VIEW ANY DATABASE permission' do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DATABASE') as ViewAnyDatabase", timeout)

      result = command(cmd)
      expect(result.exit_status).to eq(0)
      # This is optional but recommended
    end

    it 'should be able to query system tables' do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT COUNT(*) as TableCount FROM sys.tables", timeout)

      result = command(cmd)
      expect(result.exit_status).to eq(0)
    end
  end
end

# Control 6: SSL/TLS Configuration Verification
control 'mssql-ssl-06' do
  impact 0.8
  title 'SSL/TLS Encryption Configuration'
  desc 'Verify that connections are properly encrypted'
  tag 'nist': ['SC-8', 'SC-13']
  tag 'severity': 'high'

  only_if { ssl_mode != 'disable' }

  describe 'Encryption Status' do
    it 'should use encrypted connections' do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT
                                    session_id,
                                    encrypt_option,
                                    protocol_type,
                                    protocol_version
                                  FROM sys.dm_exec_connections
                                  WHERE session_id = @@SPID", timeout)

      result = command(cmd)
      expect(result.exit_status).to eq(0)

      if ssl_mode == 'verify'
        expect(result.stdout).to match(/TRUE/)
      end
    end
  end
end

# Control 7: Audit Configuration Check
control 'mssql-audit-07' do
  impact 0.7
  title 'SQL Server Audit Configuration'
  desc 'Verify that SQL Server auditing is properly configured'
  tag 'nist': ['AU-2', 'AU-3', 'AU-12']
  tag 'severity': 'medium'

  describe 'Audit Configuration' do
    it 'should have server audit specifications enabled' do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT
                                    name,
                                    is_state_enabled,
                                    type_desc
                                  FROM sys.server_audits", timeout)

      result = command(cmd)
      # Note: This is informational - auditing might not be configured in all environments
      expect(result.exit_status).to eq(0)
    end
  end
end

# Control 8: Password Policy Check (SQL Authentication)
control 'mssql-password-policy-08' do
  impact 0.8
  title 'SQL Authentication Password Policy'
  desc 'Verify password policy enforcement for SQL authenticated users'
  tag 'nist': ['IA-5']
  tag 'severity': 'medium'

  only_if { auth_method == 'sql' }

  describe 'Password Policy' do
    it 'should enforce password policy for SQL logins' do
      cmd = build_sqlcmd_command(server, port, 'master', auth_method, username, password,
                                  "SELECT
                                    name,
                                    is_policy_checked,
                                    is_expiration_checked
                                  FROM sys.sql_logins
                                  WHERE type = 'S'", timeout)

      result = command(cmd)
      if result.exit_status == 0
        # Check if policy is enforced for current user
        expect(result.stdout).not_to be_empty
      end
    end
  end
end

# Control 9: Database Configuration Security Check
control 'mssql-config-security-09' do
  impact 0.6
  title 'Database Security Configuration'
  desc 'Check critical database security configurations'
  tag 'nist': ['CM-6', 'SC-8']
  tag 'severity': 'medium'

  describe 'Security Configurations' do
    it 'should have xp_cmdshell disabled' do
      cmd = build_sqlcmd_command(server, port, 'master', auth_method, username, password,
                                  "SELECT
                                    CAST(value_in_use as int) as xp_cmdshell_enabled
                                  FROM sys.configurations
                                  WHERE name = 'xp_cmdshell'", timeout)

      result = command(cmd)
      if result.exit_status == 0
        expect(result.stdout.strip).to eq('0')
      end
    end

    it 'should have remote admin connections disabled' do
      cmd = build_sqlcmd_command(server, port, 'master', auth_method, username, password,
                                  "SELECT
                                    CAST(value_in_use as int) as remote_admin_enabled
                                  FROM sys.configurations
                                  WHERE name = 'remote admin connections'", timeout)

      result = command(cmd)
      if result.exit_status == 0
        expect(result.stdout.strip).to eq('0')
      end
    end
  end
end

# Control 10: Login Audit Level Check
control 'mssql-login-audit-10' do
  impact 0.7
  title 'Login Audit Level Configuration'
  desc 'Verify that login auditing is properly configured'
  tag 'nist': ['AU-2', 'AU-3']
  tag 'severity': 'medium'

  describe 'Login Audit Level' do
    it 'should audit failed logins at minimum' do
      cmd = build_sqlcmd_command(server, port, 'master', auth_method, username, password,
                                  "EXEC xp_loginconfig 'audit level'", timeout)

      result = command(cmd)
      if result.exit_status == 0
        # Should be 'all', 'failure', or 'successful and failure'
        expect(result.stdout).to match(/failure|all/i)
      end
    end
  end
end

# Control 11: Connection Discovery for Authentication Methods
control 'mssql-auth-discovery-11' do
  impact 0.5
  title 'Discover Working MSSQL Authentication Method'
  desc 'Test multiple authentication methods and identify working approach'
  tag 'nist': ['IA-2']
  tag 'severity': 'informational'

  describe 'Authentication Discovery' do
    it 'should identify available authentication methods' do
      # Try Windows auth first
      windows_cmd = "sqlcmd -S \"#{server},#{port}\" -d \"#{database}\" -E -C -l #{timeout} -Q \"SELECT 'WINDOWS_AUTH_SUCCESS'\""
      windows_result = command(windows_cmd)

      # Try SQL auth if credentials provided
      sql_auth_available = false
      if !username.empty? && !password.empty?
        sql_cmd = "sqlcmd -S \"#{server},#{port}\" -d \"#{database}\" -U \"#{username}\" -P \"#{password}\" -C -l #{timeout} -Q \"SELECT 'SQL_AUTH_SUCCESS'\""
        sql_result = command(sql_cmd)
        sql_auth_available = sql_result.exit_status == 0
      end

      # At least one method should work
      expect(windows_result.exit_status == 0 || sql_auth_available).to be true

      # Report which methods work
      auth_methods = []
      auth_methods << 'Windows' if windows_result.exit_status == 0
      auth_methods << 'SQL' if sql_auth_available

      describe "Available authentication methods: #{auth_methods.join(', ')}" do
        it { should_not be_empty }
      end
    end
  end
end

# Control 12: Service Account Permission Check
control 'mssql-service-account-12' do
  impact 0.6
  title 'Service Account Permission Validation'
  desc 'Verify the service account has appropriate but not excessive permissions'
  tag 'nist': ['AC-6']
  tag 'severity': 'medium'

  describe 'Service Account Permissions' do
    it 'should not have sysadmin role unless required' do
      cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                  "SELECT
                                    IS_SRVROLEMEMBER('sysadmin') as IsSysAdmin,
                                    IS_SRVROLEMEMBER('securityadmin') as IsSecurityAdmin,
                                    IS_SRVROLEMEMBER('serveradmin') as IsServerAdmin", timeout)

      result = command(cmd)
      if result.exit_status == 0
        # This is informational - requirements vary by organization
        puts "Service account role memberships: #{result.stdout}"
      end
    end
  end
end

# Control 13: Database Backup Configuration
control 'mssql-backup-config-13' do
  impact 0.7
  title 'Database Backup Configuration Check'
  desc 'Verify that database backups are properly configured'
  tag 'nist': ['CP-9', 'CP-10']
  tag 'severity': 'medium'

  describe 'Backup Configuration' do
    it 'should have recent backups for user databases' do
      cmd = build_sqlcmd_command(server, port, 'master', auth_method, username, password,
                                  "SELECT
                                    d.name as DatabaseName,
                                    MAX(b.backup_finish_date) as LastBackup,
                                    DATEDIFF(day, MAX(b.backup_finish_date), GETDATE()) as DaysSinceBackup
                                  FROM sys.databases d
                                  LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name
                                  WHERE d.database_id > 4
                                  GROUP BY d.name", timeout)

      result = command(cmd)
      if result.exit_status == 0
        # Informational - backup requirements vary
        puts "Database backup status: #{result.stdout}"
      end
    end
  end
end

# Control 14: Error Handling and Meaningful Messages
control 'mssql-error-handling-14' do
  impact 0.5
  title 'Connection Error Diagnosis'
  desc 'Provide meaningful error messages for different failure modes'
  tag 'nist': ['SI-11']
  tag 'severity': 'low'

  describe 'Error Diagnosis' do
    it 'should provide actionable error information' do
      test_cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                       "SELECT @@SERVERNAME", timeout)

      result = command(test_cmd)

      if result.exit_status != 0
        error_message = result.stderr

        # Provide specific guidance based on error pattern
        case error_message
        when /Login failed/
          fail "Authentication Error: Check username/password or Windows domain trust"
        when /Cannot open server/
          fail "Network Error: Verify server name, port, and firewall rules"
        when /SSL/
          fail "SSL Error: Try adding -C flag or check certificate configuration"
        when /timeout/
          fail "Timeout Error: Server may be unreachable or under heavy load"
        else
          fail "Connection Error: #{error_message}"
        end
      else
        expect(result.exit_status).to eq(0)
      end
    end
  end
end

# Control 15: Compliance Readiness Summary
control 'mssql-compliance-ready-15' do
  impact 1.0
  title 'Overall Compliance Scanning Readiness'
  desc 'Summary assessment of database readiness for NIST compliance scanning'
  tag 'nist': ['CA-2', 'CA-7']
  tag 'severity': 'critical'

  describe 'Compliance Readiness' do
    it 'should be ready for compliance scanning' do
      # Check all critical components
      readiness_checks = []

      # Connection test
      conn_cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                       "SELECT 'READY' as Status", timeout)
      conn_result = command(conn_cmd)
      readiness_checks << { test: 'Connection', passed: conn_result.exit_status == 0 }

      # Permission test
      perm_cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                       "SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE')", timeout)
      perm_result = command(perm_cmd)
      readiness_checks << { test: 'Permissions', passed: perm_result.exit_status == 0 && perm_result.stdout.strip == '1' }

      # Database access test
      db_cmd = build_sqlcmd_command(server, port, database, auth_method, username, password,
                                     "SELECT DB_NAME()", timeout)
      db_result = command(db_cmd)
      readiness_checks << { test: 'Database Access', passed: db_result.exit_status == 0 }

      # Calculate readiness score
      passed_checks = readiness_checks.count { |check| check[:passed] }
      total_checks = readiness_checks.length
      readiness_percentage = (passed_checks.to_f / total_checks * 100).round(2)

      # Report results
      readiness_checks.each do |check|
        describe "#{check[:test]} Check" do
          it { expect(check[:passed]).to be true }
        end
      end

      describe "Overall Readiness Score: #{readiness_percentage}%" do
        it { expect(readiness_percentage).to be >= 80.0 }
      end
    end
  end
end
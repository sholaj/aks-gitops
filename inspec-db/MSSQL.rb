# MSSQL Basic Compliance Test

# Description: Minimal InSpec controls for MSSQL connectivity and basic configuration checks

# Get input parameters

server = input(‘server’, value: ‘JABDWYCO716’)
port = input(‘port’, value: 1733)
database = input(‘database’, value: ‘Server_Guru’)

# Build connection string for sqlcmd

connection_string = “#{server},#{port}”
sqlcmd_base = “sqlcmd -S #{connection_string} -d #{database} -E -h-1”

control ‘mssql-01’ do
impact 1.0
title ‘Test MSSQL Database Connectivity’
desc ‘Verify basic database connection using Windows authentication’

describe command(”#{sqlcmd_base} -Q "SELECT ‘CONNECTIVITY_CHECK’ as test"”) do
its(‘exit_status’) { should eq 0 }
its(‘stdout’) { should match /CONNECTIVITY_CHECK/ }
end
end

control ‘mssql-02’ do
impact 0.8
title ‘Verify Database Exists’
desc ‘Confirm the specified database exists and is accessible’

describe command(”#{sqlcmd_base} -Q "SELECT name FROM sys.databases WHERE name = ‘#{database}’"”) do
its(‘exit_status’) { should eq 0 }
its(‘stdout’) { should match /#{database}/ }
end
end

control ‘mssql-03’ do
impact 0.7
title ‘Check MSSQL Server Version’
desc ‘Retrieve and validate SQL Server version information’

describe command(”#{sqlcmd_base} -Q "SELECT @@VERSION as version"”) do
its(‘exit_status’) { should eq 0 }
its(‘stdout’) { should match /Microsoft SQL Server/ }
end
end

control ‘mssql-04’ do
impact 0.6
title ‘Check Authentication Mode’
desc ‘Verify SQL Server authentication configuration’

describe command(”#{sqlcmd_base} -Q "SELECT SERVERPROPERTY(‘IsIntegratedSecurityOnly’) as auth_mode"”) do
its(‘exit_status’) { should eq 0 }
end
end

control ‘mssql-05’ do
impact 0.5
title ‘Basic System Information’
desc ‘Retrieve basic server information for compliance tracking’

describe command(”#{sqlcmd_base} -Q "SELECT @@SERVERNAME as server_name, DB_NAME() as current_db"”) do
its(‘exit_status’) { should eq 0 }
end
end
# MSSQL Testing Troubleshooting Guide

## Test Environment Details

- **Server**: JABDWYCO716 (IP: 10.103.226.88)
- **Port**: 1733
- **Database**: Server_Guru
- **Authentication**: Windows Authentication

## Common Issues and Solutions

### 1. Network Connectivity Failures

#### Symptoms

```
Network Connectivity: FAIL
telnet JABDWYCO716 1733 - Connection refused or timeout
```

#### Troubleshooting Steps

1. **Test hostname resolution**:
   
   ```bash
   nslookup JABDWYCO716
   ping JABDWYCO716
   ```
1. **Test with IP address**:
   
   ```bash
   telnet 10.103.226.88 1733
   ```
1. **Check firewall rules**:
   
   ```bash
   # Check if port is open
   nc -zv JABDWYCO716 1733
   ```
1. **Verify MSSQL service is running**:
- Contact database administrator to confirm SQL Server is running
- Verify SQL Server is configured to listen on port 1733

#### Common Causes

- Firewall blocking port 1733
- SQL Server not running or not accepting connections
- Network routing issues
- Incorrect hostname or IP address

### 2. Database Connection Failures

#### Symptoms

```
Network Connectivity: PASS
Database Connection: FAIL
Login failed for user 'DOMAIN\username'
```

#### Troubleshooting Steps

1. **Check Windows authentication**:
   
   ```bash
   # Verify current user
   whoami
   
   # Test basic connection
   sqlcmd -S JABDWYCO716,1733 -E -Q "SELECT @@VERSION"
   ```
1. **Test different connection methods**:
   
   ```bash
   # Using IP address
   sqlcmd -S 10.103.226.88,1733 -E -Q "SELECT @@VERSION"
   
   # Using hostname only
   sqlcmd -S JABDWYCO716 -E -Q "SELECT @@VERSION"
   ```
1. **Check SQL Server authentication mode**:
- Contact DBA to ensure Windows authentication is enabled
- Verify user has login permissions on SQL Server

#### Common Causes

- User account not granted login permissions
- SQL Server in SQL Authentication mode only
- Domain authentication issues
- Account locked or disabled

### 3. Database Access Failures

#### Symptoms

```
Network Connectivity: PASS
Database Connection: PASS (to master)
Cannot open database "Server_Guru" requested by the login
```

#### Troubleshooting Steps

1. **Verify database exists**:
   
   ```bash
   sqlcmd -S JABDWYCO716,1733 -E -Q "SELECT name FROM sys.databases"
   ```
1. **Check database permissions**:
   
   ```bash
   sqlcmd -S JABDWYCO716,1733 -E -Q "SELECT dp.name, dp.type_desc FROM sys.database_principals dp WHERE dp.name = SYSTEM_USER"
   ```
1. **Test with master database**:
   
   ```bash
   sqlcmd -S JABDWYCO716,1733 -d master -E -Q "SELECT 'Connection OK'"
   ```

#### Common Causes

- Database name incorrect or case-sensitive
- User lacks access permissions to specific database
- Database offline or in recovery mode

### 4. InSpec Execution Failures

#### Symptoms

```
Network Connectivity: PASS
Database Connection: PASS
InSpec Execution: FAIL
```

#### Troubleshooting Steps

1. **Check InSpec installation**:
   
   ```bash
   /usr/bin/inspec --version
   which inspec
   ```
1. **Validate Ruby profile syntax**:
   
   ```bash
   /usr/bin/inspec check mssql_basic_test.rb
   ```
1. **Test profile manually**:
   
   ```bash
   /usr/bin/inspec exec mssql_basic_test.rb \
     --input server=JABDWYCO716 port=1733 database=Server_Guru \
     --reporter=cli
   ```
1. **Check Ruby dependencies**:
   
   ```bash
   ruby --version
   gem list
   ```

#### Common Causes

- InSpec not installed or not in PATH
- Ruby profile syntax errors
- Missing Ruby gems or dependencies
- Input parameters not passed correctly

### 5. sqlcmd Command Issues

#### Symptoms

```
bash: sqlcmd: command not found
```

#### Installation Steps

```bash
# RHEL/CentOS
sudo curl https://packages.microsoft.com/config/rhel/8/prod.repo > /etc/yum.repos.d/mssql-release.repo
sudo yum install mssql-tools unixODBC-devel

# Ubuntu/Debian  
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update
sudo apt-get install mssql-tools unixodbc-dev

# Add to PATH
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc
```

## Manual Testing Commands

### Basic Connectivity Test

```bash
# Network test
telnet JABDWYCO716 1733

# Basic SQL connection
sqlcmd -S JABDWYCO716,1733 -E -Q "SELECT 'Test successful'"

# Database-specific connection
sqlcmd -S JABDWYCO716,1733 -d Server_Guru -E -Q "SELECT DB_NAME() as current_database"
```

### InSpec Manual Execution

```bash
# Run specific control
/usr/bin/inspec exec mssql_basic_test.rb \
  --input server=JABDWYCO716 port=1733 database=Server_Guru \
  --controls=mssql-01

# Run all controls with detailed output
/usr/bin/inspec exec mssql_basic_test.rb \
  --input server=JABDWYCO716 port=1733 database=Server_Guru \
  --reporter=cli \
  --reporter=json:results.json
```

## Environment Validation Checklist

### Prerequisites Check

- [ ] Ansible installed and working
- [ ] InSpec installed (`/usr/bin/inspec --version`)
- [ ] sqlcmd installed and in PATH
- [ ] Network connectivity to JABDWYCO716:1733
- [ ] Windows authentication working
- [ ] Access to Server_Guru database

### File Requirements

- [ ] `test-mssql-connection.yml` (main playbook)
- [ ] `mssql_basic_test.rb` (InSpec profile)
- [ ] Current user has appropriate permissions

### Expected File Locations

```
./
├── test-mssql-connection.yml
├── mssql_basic_test.rb
└── /tmp/mssql_test_[timestamp]/
    └── inspec_results.json
```

## Getting Help

### Log Files to Check

- `/tmp/mssql_test_*/inspec_results.json` - InSpec execution details
- Ansible output with `-vvv` flag for detailed debugging
- SQL Server error logs (contact DBA if needed)

### Information to Provide When Escalating

1. Complete error messages from playbook execution
1. Result of manual sqlcmd test
1. Output of `whoami` command
1. Network connectivity test results
1. InSpec and sqlcmd version information

### Contact Information

- **Database Issues**: Contact database administrator team
- **Network Issues**: Contact network/infrastructure team
- **Authentication Issues**: Contact Windows/Active Directory team
- **InSpec Issues**: Contact security/compliance team
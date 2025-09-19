# MSSQL Authentication Testing Framework

## Overview
This framework provides a systematic approach to testing and troubleshooting MSSQL authentication methods in corporate environments.

## Authentication Methods

### 1. Windows Authentication (Integrated Security)

#### Testing Command
```bash
# Basic Windows authentication test
sqlcmd -S [SERVER],[PORT] -d [DATABASE] -E -C -Q "SELECT @@VERSION"

# With detailed auth information
sqlcmd -S [SERVER],[PORT] -d [DATABASE] -E -C -Q "
  SELECT
    SYSTEM_USER as WindowsUser,
    AUTH_SCHEME as AuthMethod,
    ORIGINAL_LOGIN() as OriginalLogin
  FROM sys.dm_exec_connections
  WHERE session_id = @@SPID"
```

#### Common Issues and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| Login failed for user 'DOMAIN\USER' | No domain trust | 1. Verify domain membership<br>2. Check Kerberos configuration<br>3. Ensure SPN registration |
| Cannot authenticate using Kerberos | Missing SPN | Run: `setspn -L [sql_service_account]`<br>Register SPN if missing |
| SSPI context error | Time sync issue | Sync time between client and server<br>Check domain controller connectivity |
| Access denied | Insufficient permissions | Grant CONNECT permission to Windows user/group |

#### Kerberos vs NTLM Decision Flow
```
Windows Auth Attempt
├── Check domain membership
│   ├── YES → Try Kerberos
│   │   ├── SPN exists? → Use Kerberos
│   │   └── No SPN → Fall back to NTLM
│   └── NO → Local auth only
└── Result: AUTH_SCHEME shows method used
```

### 2. SQL Server Authentication

#### Testing Command
```bash
# Basic SQL authentication test
sqlcmd -S [SERVER],[PORT] -d [DATABASE] -U [username] -P [password] -C -Q "SELECT @@VERSION"

# With authentication details
sqlcmd -S [SERVER],[PORT] -d [DATABASE] -U [username] -P [password] -C -Q "
  SELECT
    SYSTEM_USER as SqlUser,
    IS_SRVROLEMEMBER('sysadmin') as IsSysAdmin,
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') as CanViewServerState"
```

#### Common Issues and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| Login failed for user 'username' | Wrong credentials | Verify username/password<br>Check for special characters |
| Password policy violation | Policy requirements | Check password complexity<br>Verify expiration status |
| SQL auth not enabled | Windows-only mode | Enable mixed mode authentication<br>Restart SQL Server service |
| Account locked | Too many attempts | Unlock account via SSMS<br>Reset password if needed |

### 3. Mixed Mode Authentication Discovery

#### Automatic Discovery Script
```bash
#!/bin/bash
# Discover available authentication methods

test_auth() {
    local server=$1
    local port=$2
    local database=$3

    echo "Testing authentication methods for $server:$port/$database"

    # Test Windows Auth
    echo -n "Windows Authentication: "
    if sqlcmd -S "$server,$port" -d "$database" -E -C -Q "SELECT 1" &>/dev/null; then
        echo "AVAILABLE"
        WINDOWS_AUTH=true
    else
        echo "NOT AVAILABLE"
        WINDOWS_AUTH=false
    fi

    # Test SQL Auth (if credentials provided)
    if [ -n "$SQL_USER" ] && [ -n "$SQL_PASS" ]; then
        echo -n "SQL Authentication: "
        if sqlcmd -S "$server,$port" -d "$database" -U "$SQL_USER" -P "$SQL_PASS" -C -Q "SELECT 1" &>/dev/null; then
            echo "AVAILABLE"
            SQL_AUTH=true
        else
            echo "NOT AVAILABLE"
            SQL_AUTH=false
        fi
    fi

    # Check server auth mode
    if $WINDOWS_AUTH; then
        echo -e "\nServer Authentication Mode:"
        sqlcmd -S "$server,$port" -d master -E -C -Q "
            SELECT CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
                WHEN 1 THEN 'Windows Authentication Only'
                WHEN 0 THEN 'Mixed Mode (Windows + SQL)'
            END as AuthMode" -h -1
    fi
}
```

## Connection String Variations

### Different Approaches for Various Scenarios

#### 1. FQDN vs IP Address
```bash
# Using FQDN (preferred for Kerberos)
sqlcmd -S "server.domain.com,1433" -E -C

# Using IP address (forces NTLM)
sqlcmd -S "10.0.0.5,1433" -E -C

# Using instance name
sqlcmd -S "server\INSTANCE" -E -C
```

#### 2. SSL/TLS Configuration
```bash
# Trust server certificate (common in dev/test)
sqlcmd -S "server,1433" -C

# Verify certificate (production)
sqlcmd -S "server,1433"

# Force encryption
sqlcmd -S "server,1433" -N

# Disable encryption (not recommended)
sqlcmd -S "server,1433" -N disable
```

#### 3. Timeout Settings
```bash
# Connection timeout (default 8 seconds)
sqlcmd -S "server,1433" -l 30

# Query timeout
sqlcmd -S "server,1433" -t 600
```

#### 4. Multi-Subnet Failover
```bash
# For AlwaysOn Availability Groups
sqlcmd -S "listener,1433" -M
```

## Progressive Testing Strategy

### Level 1: Network Connectivity
```bash
# Test 1: DNS resolution
nslookup [SERVER]

# Test 2: Port accessibility
nc -zv [SERVER] [PORT]
# or
telnet [SERVER] [PORT]

# Test 3: SQL port response
sqlcmd -S "[SERVER],[PORT]" -Q "SELECT 1" -l 5
```

### Level 2: Authentication
```bash
# Test both authentication methods
for auth in "windows" "sql"; do
    echo "Testing $auth authentication..."
    if [ "$auth" = "windows" ]; then
        sqlcmd -S "[SERVER],[PORT]" -E -C -Q "SELECT SYSTEM_USER"
    else
        sqlcmd -S "[SERVER],[PORT]" -U "$USER" -P "$PASS" -C -Q "SELECT SYSTEM_USER"
    fi
done
```

### Level 3: Database Access
```bash
# Test database connectivity
sqlcmd -S "[SERVER],[PORT]" -d "[DATABASE]" -E -C -Q "
    SELECT
        DB_NAME() as CurrentDB,
        DATABASEPROPERTYEX(DB_NAME(), 'Status') as Status"
```

### Level 4: Permission Validation
```bash
# Check required permissions
sqlcmd -S "[SERVER],[PORT]" -d "[DATABASE]" -E -C -Q "
    SELECT
        'VIEW SERVER STATE' as Permission,
        HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') as Granted
    UNION ALL
    SELECT
        'VIEW ANY DATABASE',
        HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DATABASE')
    UNION ALL
    SELECT
        'VIEW ANY DEFINITION',
        HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DEFINITION')"
```

### Level 5: Query Execution
```bash
# Test actual compliance queries
sqlcmd -S "[SERVER],[PORT]" -d "[DATABASE]" -E -C -Q "
    SELECT
        SERVERPROPERTY('ProductVersion') as Version,
        SERVERPROPERTY('Edition') as Edition,
        @@SERVERNAME as ServerName"
```

## Environment-Specific Configurations

### Corporate Network with Domain Authentication
```yaml
# Ansible variables for domain environment
mssql_server: "sqlserver.corp.domain.com"
mssql_port: 1433
auth_method: windows
ssl_mode: verify
```

### DMZ with SQL Authentication
```yaml
# Ansible variables for DMZ
mssql_server: "10.10.10.5"
mssql_port: 1733
auth_method: sql
mssql_username: "{{ vault_sql_username }}"
mssql_password: "{{ vault_sql_password }}"
ssl_mode: trust
```

### Cloud Environment
```yaml
# Ansible variables for Azure SQL
mssql_server: "server.database.windows.net"
mssql_port: 1433
auth_method: sql
ssl_mode: verify
connection_timeout: 60
```

## Quick Troubleshooting Commands

### Check Authentication Mode
```bash
sqlcmd -S [SERVER],[PORT] -E -C -Q "
    SELECT
        CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
            WHEN 1 THEN 'Windows Only'
            WHEN 0 THEN 'Mixed Mode'
        END as AuthMode"
```

### List SQL Logins
```bash
sqlcmd -S [SERVER],[PORT] -E -C -Q "
    SELECT name, type_desc, is_disabled
    FROM sys.server_principals
    WHERE type IN ('S', 'U', 'G')"
```

### Check Current Connections
```bash
sqlcmd -S [SERVER],[PORT] -E -C -Q "
    SELECT
        session_id,
        login_name,
        auth_scheme,
        client_net_address
    FROM sys.dm_exec_sessions
    WHERE is_user_process = 1"
```

### Verify SSL Configuration
```bash
sqlcmd -S [SERVER],[PORT] -E -C -Q "
    SELECT
        encrypt_option,
        protocol_type
    FROM sys.dm_exec_connections
    WHERE session_id = @@SPID"
```

## Integration Examples

### Ansible Execution
```bash
# Development environment
ansible-playbook mssql_basic_check.yml \
  -e mssql_server=dev-sql.local \
  -e mssql_port=1433 \
  -e auth_method=windows

# Production with SQL auth
ansible-playbook mssql_basic_check.yml \
  -e mssql_server=prod-sql.company.com \
  -e mssql_port=1733 \
  -e auth_method=sql \
  --ask-vault-pass

# With custom InSpec profile
ansible-playbook mssql_basic_check.yml \
  -e mssql_server=audit-sql.dmz \
  -e inspec_profile_path=/custom/profiles/mssql
```

### InSpec Execution
```bash
# Windows authentication
inspec exec mssql/inspec-profiles \
  --input server=sqlserver.local \
  --input port=1433 \
  --input auth_method=windows \
  --reporter cli json:results.json

# SQL authentication with inputs file
cat > inputs.yml <<EOF
server: sqlserver.dmz
port: 1733
auth_method: sql
username: compliance_user
password: ${SQL_PASSWORD}
EOF

inspec exec mssql/inspec-profiles \
  --input-file inputs.yml \
  --reporter cli
```

## Security Best Practices

1. **Never hardcode credentials** - Use environment variables or secret management
2. **Use certificate verification** in production (`ssl_mode: verify`)
3. **Implement least privilege** - Grant only necessary permissions
4. **Rotate credentials regularly** - Especially for service accounts
5. **Monitor failed login attempts** - Set up alerts for authentication failures
6. **Use Windows auth when possible** - More secure than SQL authentication
7. **Encrypt sensitive variables** - Use Ansible Vault for passwords
8. **Audit authentication events** - Enable SQL Server audit logs

## Common Error Reference

| Error Code | Message | Resolution |
|------------|---------|------------|
| 18456 | Login failed | Check credentials, auth mode, permissions |
| 18452 | Not associated with trusted connection | Enable mixed mode or use SQL auth |
| 233 | Connection init error | Check protocols, restart SQL service |
| 10061 | Connection refused | Verify port, firewall, SQL Browser service |
| 0x80090302 | SSPI context | Time sync, SPN, or domain issues |
| 28000 | Invalid authorization | Check password policy, account status |

## Support Scripts

### Full Authentication Test
```bash
./test_mssql_connection.sh [server] [port] [database]
```

### Quick Connectivity Check
```bash
sqlcmd -S [server],[port] -Q "SELECT 'SUCCESS'" -l 5 && echo "Connected!" || echo "Failed!"
```

### Ansible Dry Run
```bash
ansible-playbook mssql_basic_check.yml --check -vv
```
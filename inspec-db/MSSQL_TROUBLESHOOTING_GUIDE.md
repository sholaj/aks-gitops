# MSSQL Connection Troubleshooting Decision Tree

## Quick Start Troubleshooting Flow

```
START: Cannot connect to MSSQL
│
├─[1] Network Connectivity Test
│   │
│   ├── Can ping server? ──NO──> Check DNS/Network
│   │                             └── Fix: Check firewall, VPN, routing
│   └── YES
│       │
│       └── Can telnet to port? ──NO──> Port Blocked
│           │                           └── Fix: Open port in firewall
│           └── YES
│               │
├─[2] Authentication Testing
│   │
│   ├── Windows Auth ──FAILS──> Try SQL Auth
│   │   │                       └── Still fails? → Check auth mode
│   │   └── WORKS → Go to [3]
│   │
│   └── SQL Auth ──FAILS──> Authentication Issues
│       │                   └── Fix: Check credentials, account status
│       └── WORKS → Go to [3]
│
├─[3] Database Access Test
│   │
│   ├── Can access database? ──NO──> Permission Issues
│   │                               └── Fix: Grant database access
│   └── YES → Go to [4]
│
├─[4] Query Execution Test
│   │
│   ├── Can run queries? ──NO──> Insufficient Permissions
│   │                           └── Fix: Grant required permissions
│   └── YES → Go to [5]
│
└─[5] SUCCESS: Connection Working
    └── Run compliance scans
```

## Detailed Troubleshooting Sections

### Section 1: Network Connectivity Issues

#### Problem: Cannot reach MSSQL server

**Diagnostic Steps:**
```bash
# Step 1: Test DNS resolution
nslookup [SERVER_NAME]

# Step 2: Test network connectivity
ping [SERVER_IP] -c 4

# Step 3: Test port connectivity
nc -zv [SERVER] [PORT]
# or
telnet [SERVER] [PORT]

# Step 4: Check SQL Server is listening
sqlcmd -S "[SERVER],[PORT]" -Q "SELECT 1" -l 5
```

**Resolution Decision Tree:**
```
Network Test Failed
├── DNS Failure
│   ├── Action: Use IP address instead
│   └── Fix: Update /etc/hosts or DNS server
│
├── Ping Failure
│   ├── Check: Is ICMP blocked?
│   ├── Action: Try telnet/nc to SQL port directly
│   └── Fix: Check VPN connection, routing tables
│
├── Port Connection Failure
│   ├── Check: Correct port number?
│   ├── Check: SQL Server running?
│   ├── Check: SQL Server configured for TCP/IP?
│   └── Fix: Enable TCP/IP in SQL Server Configuration Manager
│
└── Firewall Blocking
    ├── Windows Firewall: New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -LocalPort [PORT] -Protocol TCP -Action Allow
    ├── Linux: sudo ufw allow [PORT]/tcp
    └── Corporate: Request firewall rule from network team
```

### Section 2: Authentication Failures

#### Problem: Login failed for user

**Diagnostic Flow:**
```
Authentication Failed
├── Windows Authentication
│   ├── Error: "Login failed for user 'DOMAIN\User'"
│   │   ├── Check: Domain membership
│   │   │   └── Command: echo %USERDOMAIN%
│   │   ├── Check: Kerberos ticket
│   │   │   └── Command: klist
│   │   ├── Check: SPN registration
│   │   │   └── Command: setspn -L [sql_service_account]
│   │   └── Fix: Grant login permission
│   │       └── SQL: CREATE LOGIN [DOMAIN\User] FROM WINDOWS
│   │
│   └── Error: "SSPI context error"
│       ├── Check: Time synchronization
│       │   └── Command: w32tm /query /status
│       ├── Check: DNS configuration
│       └── Fix: Register SPN manually
│           └── Command: setspn -A MSSQLSvc/[server]:[port] [service_account]
│
└── SQL Authentication
    ├── Error: "Login failed for user 'username'"
    │   ├── Check: Correct password?
    │   ├── Check: SQL auth enabled?
    │   │   └── Query: SELECT SERVERPROPERTY('IsIntegratedSecurityOnly')
    │   ├── Check: Account enabled?
    │   │   └── Query: SELECT is_disabled FROM sys.sql_logins WHERE name = 'username'
    │   └── Fix: Reset password or enable account
    │
    └── Error: "Password policy violation"
        ├── Check: Password complexity requirements
        ├── Check: Password expiration
        └── Fix: Update password to meet policy
```

**Authentication Mode Discovery:**
```sql
-- Check current authentication mode
SELECT
    CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
        WHEN 1 THEN 'Windows Authentication Only'
        WHEN 0 THEN 'Mixed Mode Authentication'
    END as AuthenticationMode;

-- If Windows Only, enable Mixed Mode:
-- 1. Open SQL Server Management Studio
-- 2. Right-click server → Properties → Security
-- 3. Select "SQL Server and Windows Authentication mode"
-- 4. Restart SQL Server service
```

### Section 3: SSL/Certificate Issues

#### Problem: SSL/TLS connection errors

**Diagnostic Tree:**
```
SSL/TLS Error
├── Certificate not trusted
│   ├── Option 1: Trust certificate (dev/test)
│   │   └── Add flag: -C or TrustServerCertificate=true
│   ├── Option 2: Install certificate (production)
│   │   └── Import cert to Trusted Root store
│   └── Option 3: Disable SSL (not recommended)
│       └── Use: Encrypt=false in connection string
│
├── Certificate expired
│   └── Fix: Renew server certificate
│
└── Protocol version mismatch
    ├── Check: TLS version support
    └── Fix: Enable TLS 1.2 on client/server
```

### Section 4: Permission Issues

#### Problem: Insufficient permissions for compliance scanning

**Permission Verification Checklist:**
```sql
-- Check all required permissions
SELECT
    'CONNECT' as Permission,
    HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'CONNECT') as Granted
UNION ALL
SELECT 'VIEW SERVER STATE',
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE')
UNION ALL
SELECT 'VIEW ANY DATABASE',
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DATABASE')
UNION ALL
SELECT 'VIEW ANY DEFINITION',
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DEFINITION');
```

**Grant Required Permissions:**
```sql
-- Minimum permissions for compliance scanning
USE master;
GO

-- Create login (if needed)
CREATE LOGIN [compliance_user] WITH PASSWORD = 'StrongPassword123!';
GO

-- Grant server-level permissions
GRANT VIEW SERVER STATE TO [compliance_user];
GRANT VIEW ANY DATABASE TO [compliance_user];
GRANT VIEW ANY DEFINITION TO [compliance_user];
GO

-- Grant database-level permissions
USE [YourDatabase];
GO
CREATE USER [compliance_user] FOR LOGIN [compliance_user];
GRANT CONNECT TO [compliance_user];
GRANT SELECT TO [compliance_user];
GO
```

### Section 5: Connection Timeout Issues

#### Problem: Connection times out

**Timeout Resolution Tree:**
```
Timeout Error
├── Network latency
│   ├── Test: ping -t [server]
│   ├── Action: Increase timeout value
│   └── Fix: sqlcmd -l 60 (60 second timeout)
│
├── Server overload
│   ├── Check: CPU/Memory usage on server
│   ├── Action: Try during off-peak hours
│   └── Fix: Optimize server resources
│
├── Long-running query
│   ├── Action: Increase query timeout
│   └── Fix: sqlcmd -t 600 (10 minute query timeout)
│
└── Deadlock/Blocking
    ├── Check: sp_who2 for blocking
    └── Fix: Kill blocking session if safe
```

## Common Error Codes and Quick Fixes

| Error Code | Description | Quick Fix |
|------------|-------------|-----------|
| **18456** | Login failed | Check username/password, verify account exists and is enabled |
| **18452** | Login from untrusted domain | Use SQL auth or establish domain trust |
| **18470** | Account disabled | Enable account: `ALTER LOGIN [username] ENABLE` |
| **18486** | Password expired | Change password: `ALTER LOGIN [username] WITH PASSWORD = 'NewPass'` |
| **18487** | Password must be changed | Login and change password |
| **18488** | Password policy violation | Ensure password meets complexity requirements |
| **233** | Connection initialization error | Restart SQL Server service, check protocols |
| **10061** | Connection refused | Verify SQL Server is running and port is correct |
| **10060** | Connection timeout | Increase timeout, check network latency |
| **28000** | Invalid authorization specification | Check authentication mode and credentials |
| **08001** | Unable to connect | Check server name, instance, and port |

## Environment-Specific Troubleshooting

### Corporate Network with Firewall
```bash
# Step 1: Verify internal DNS
nslookup sqlserver.corp.internal

# Step 2: Check if behind proxy
echo $HTTP_PROXY

# Step 3: Test without proxy
unset HTTP_PROXY HTTPS_PROXY
sqlcmd -S "server,port" -E -C -Q "SELECT 1"

# Step 4: If using jump host
ssh jump-host "sqlcmd -S server,port -E -Q 'SELECT 1'"
```

### Azure SQL Database
```bash
# Azure-specific connection
sqlcmd -S "server.database.windows.net,1433" \
       -d "database" \
       -U "username@server" \
       -P "password" \
       -Q "SELECT 1"

# Check firewall rules
# Azure Portal → SQL Database → Firewall settings
# Add client IP if needed
```

### Docker Container
```bash
# From container
docker exec -it [container] /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1"

# From host to container
sqlcmd -S "localhost,1433" -U sa -P "password" -Q "SELECT 1"
```

## Quick Diagnostic Commands

### One-Liner Health Check
```bash
# Complete connectivity test
echo "Network:"; nc -zv [server] [port] 2>&1 | grep succeeded && \
echo "Auth:"; sqlcmd -S "[server],[port]" -E -C -Q "SELECT 'SUCCESS'" -h -1 2>&1 | grep SUCCESS && \
echo "Permissions:"; sqlcmd -S "[server],[port]" -E -C -Q "SELECT HAS_PERMS_BY_NAME(NULL,NULL,'VIEW SERVER STATE')" -h -1
```

### Authentication Method Discovery
```bash
# Try all auth methods
for method in "-E" "-U sa -P password"; do
    echo "Testing: $method"
    sqlcmd -S "server,port" $method -C -Q "SELECT AUTH_SCHEME FROM sys.dm_exec_connections WHERE session_id = @@SPID" -h -1 2>/dev/null && break
done
```

### Permission Audit
```bash
# Check all permissions at once
sqlcmd -S "[server],[port]" -E -C -Q "
DECLARE @perms TABLE (Permission VARCHAR(50), Granted BIT);
INSERT @perms
SELECT 'VIEW SERVER STATE', HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE')
UNION ALL SELECT 'VIEW ANY DATABASE', HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DATABASE')
UNION ALL SELECT 'VIEW ANY DEFINITION', HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DEFINITION');
SELECT * FROM @perms;" -s "|" -W
```

## Automation Integration Troubleshooting

### Ansible Playbook Issues
```bash
# Debug mode
ansible-playbook mssql_basic_check.yml -vvv

# Check variables
ansible-playbook mssql_basic_check.yml -e verbose_output=true

# Test specific tags
ansible-playbook mssql_basic_check.yml --tags network,auth

# Dry run
ansible-playbook mssql_basic_check.yml --check
```

### InSpec Control Failures
```bash
# Run specific control
inspec exec mssql/inspec-profiles --controls mssql-connection-01

# Debug mode
inspec exec mssql/inspec-profiles --log-level debug

# Show backtrace on errors
inspec exec mssql/inspec-profiles --backtrace
```

## Emergency Recovery Procedures

### When Nothing Works
1. **Verify basics:**
   ```bash
   # Is SQL Server running?
   systemctl status mssql-server  # Linux
   Get-Service MSSQLSERVER        # Windows
   ```

2. **Check SQL Server logs:**
   ```bash
   # Linux
   tail -f /var/opt/mssql/log/errorlog

   # Windows
   Get-Content "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Log\ERRORLOG" -Tail 50
   ```

3. **Reset to known good state:**
   ```sql
   -- Enable SQL auth
   EXEC sp_configure 'show advanced options', 1;
   RECONFIGURE;

   -- Reset authentication
   USE master;
   ALTER LOGIN sa ENABLE;
   ALTER LOGIN sa WITH PASSWORD = 'TempPassword123!';
   ```

4. **Last resort - DAC connection:**
   ```bash
   # Dedicated Admin Connection
   sqlcmd -S "admin:server,port" -E -Q "SELECT 1"
   ```

## Support Contact Decision Tree

```
Issue Severity Assessment
├── Production Down
│   └── Contact: DBA On-Call immediately
│
├── Authentication Issues
│   ├── Domain/Windows: Contact AD/Domain Admin
│   └── SQL Auth: Contact DBA Team
│
├── Network/Firewall
│   └── Contact: Network Operations
│
├── Performance/Timeout
│   └── Contact: DBA during business hours
│
└── Permissions/Access
    └── Contact: Database Security Team
```

## Final Checklist

Before escalating, verify:
- [ ] Correct server name and port
- [ ] Network connectivity confirmed
- [ ] Authentication method appropriate for environment
- [ ] Credentials are valid and not expired
- [ ] Account is enabled and not locked
- [ ] Required permissions granted
- [ ] SSL/TLS settings match server configuration
- [ ] Firewall rules allow connection
- [ ] SQL Server service is running
- [ ] Connection string is properly formatted

## Quick Reference Card

```bash
# Template Connection Commands
# ============================

# Windows Auth
sqlcmd -S "[SERVER],[PORT]" -d "[DATABASE]" -E -C -Q "SELECT @@VERSION"

# SQL Auth
sqlcmd -S "[SERVER],[PORT]" -d "[DATABASE]" -U "[USER]" -P "[PASS]" -C -Q "SELECT @@VERSION"

# Ansible
ansible-playbook mssql_basic_check.yml -e mssql_server=[SERVER] -e mssql_port=[PORT]

# InSpec
inspec exec mssql/inspec-profiles --input server=[SERVER] --input port=[PORT]

# Manual test script
./test_mssql_connection.sh [SERVER] [PORT] [DATABASE]
```
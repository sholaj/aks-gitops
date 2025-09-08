# Database Testing Commands Reference

## PostgreSQL Connection Testing

### Basic Connection Tests
```bash
# Test TCP connectivity
telnet localhost 5432
nc -zv localhost 5432

# Test with psql
psql -h localhost -p 5432 -U test_user -d test_db -c "SELECT 1"
PGPASSWORD='P@ssw0rd' psql -h localhost -p 5432 -U test_user -d test_db -c "SELECT version()"

# Check SSL status
PGPASSWORD='P@ssw0rd' psql -h localhost -p 5432 -U test_user -d test_db -c "SHOW ssl"

# Test authentication
PGPASSWORD='P@ssw0rd' psql -h localhost -p 5432 -U test_user -d test_db -c "SELECT current_user"

# Count sample data
PGPASSWORD='P@ssw0rd' psql -h localhost -p 5432 -U test_user -d test_db -c "SELECT COUNT(*) FROM sample_table"
```

### InSpec Commands for PostgreSQL
```bash
# Run full profile
inspec exec postgresql/inspec-profiles \
  --input pg_host=localhost \
  --input pg_port=5432 \
  --input pg_user=test_user \
  --input pg_password='P@ssw0rd' \
  --input pg_database=test_db

# Run specific control
inspec exec postgresql/inspec-profiles \
  --controls postgresql-ssl-encryption \
  --input pg_host=localhost \
  --input pg_port=5432 \
  --input pg_user=test_user \
  --input pg_password='P@ssw0rd' \
  --input pg_database=test_db

# Generate JSON report
inspec exec postgresql/inspec-profiles \
  --input pg_host=localhost \
  --input pg_port=5432 \
  --input pg_user=test_user \
  --input pg_password='P@ssw0rd' \
  --input pg_database=test_db \
  --reporter json:/tmp/postgresql-compliance.json
```

## MS SQL Server / Azure SQL Connection Testing

### Basic Connection Tests
```bash
# Test TCP connectivity
telnet localhost 1433
nc -zv localhost 1433

# Test with sqlcmd (MS SQL Server)
/opt/mssql-tools/bin/sqlcmd -S localhost,1433 -U test_user -P 'P@ssw0rd' -d test_db -Q "SELECT 1"
/opt/mssql-tools/bin/sqlcmd -S localhost,1433 -U test_user -P 'P@ssw0rd' -d test_db -Q "SELECT @@VERSION"

# Azure SQL Database connection
/opt/mssql-tools/bin/sqlcmd -S sql-server.database.windows.net -U sqladmin -P 'CompliantP@ssw0rd2024!' -d test_db -Q "SELECT 1"

# Check SSL/TLS encryption
/opt/mssql-tools/bin/sqlcmd -S localhost,1433 -U test_user -P 'P@ssw0rd' -d test_db -Q "SELECT encrypt_option FROM sys.dm_exec_connections WHERE session_id = @@SPID"

# Test user permissions
/opt/mssql-tools/bin/sqlcmd -S localhost,1433 -U test_user -P 'P@ssw0rd' -d test_db -Q "SELECT USER_NAME()"
```

### InSpec Commands for MS SQL Server
```bash
# Run full profile
inspec exec mssql/inspec-profiles \
  --input mssql_host=localhost \
  --input mssql_port=1433 \
  --input mssql_user=test_user \
  --input mssql_password='P@ssw0rd' \
  --input mssql_database=test_db

# Run specific control
inspec exec mssql/inspec-profiles \
  --controls mssql-ssl-encryption \
  --input mssql_host=localhost \
  --input mssql_port=1433 \
  --input mssql_user=test_user \
  --input mssql_password='P@ssw0rd' \
  --input mssql_database=test_db

# Generate JSON report
inspec exec mssql/inspec-profiles \
  --input mssql_host=localhost \
  --input mssql_port=1433 \
  --input mssql_user=test_user \
  --input mssql_password='P@ssw0rd' \
  --input mssql_database=test_db \
  --reporter json:/tmp/mssql-compliance.json
```

## Azure SQL Database Testing

### Connection Tests
```bash
# Test TLS connection
openssl s_client -connect sql-server.database.windows.net:1433 -servername sql-server.database.windows.net < /dev/null

# Azure CLI commands
az sql db show --resource-group rg-name --server sql-server --name test_db
az sql server show --resource-group rg-name --name sql-server

# Test with sqlcmd
/opt/mssql-tools/bin/sqlcmd -S sql-server.database.windows.net -U sqladmin -P 'password' -d test_db -Q "SELECT 1" -N -C
```

### InSpec Commands for Azure SQL
```bash
# Run full profile
inspec exec azure-sql/inspec-profiles \
  --input sql_server=sql-server.database.windows.net \
  --input sql_admin_user=sqladmin \
  --input sql_admin_password='password' \
  --input sql_database=test_db

# Generate report
inspec exec azure-sql/inspec-profiles \
  --input sql_server=sql-server.database.windows.net \
  --input sql_admin_user=sqladmin \
  --input sql_admin_password='password' \
  --input sql_database=test_db \
  --reporter cli json:/tmp/azure-sql-compliance.json
```

## Ansible Playbook Execution

### PostgreSQL Compliance Scanning
```bash
# Run PostgreSQL compliance scan
ansible-playbook -i ansible-test-inventory.ini test-ansible-playbook.yml

# Run with verbose output
ansible-playbook -i ansible-test-inventory.ini test-ansible-playbook.yml -v

# Check syntax
ansible-playbook -i ansible-test-inventory.ini test-ansible-playbook.yml --syntax-check

# Dry run
ansible-playbook -i ansible-test-inventory.ini test-ansible-playbook.yml --check
```

### MS SQL Server Compliance Scanning
```bash
# Run MS SQL compliance scan
ansible-playbook -i mssql/ansible-playbooks/inventory.ini mssql/ansible-playbooks/mssql-compliance-scan.yml

# With custom variables
ansible-playbook -i mssql/ansible-playbooks/inventory.ini mssql/ansible-playbooks/mssql-compliance-scan.yml \
  -e "mssql_host=192.168.1.100" \
  -e "mssql_user=custom_user"
```

### Azure SQL Database Compliance Scanning
```bash
# Run Azure SQL compliance scan
ansible-playbook -i ansible-azure-sql-inventory.ini test-azure-sql-ansible.yml

# With vault for passwords
ansible-playbook -i ansible-azure-sql-inventory.ini test-azure-sql-ansible.yml --ask-vault-pass
```

## Troubleshooting Commands

### PostgreSQL
```bash
# Check PostgreSQL service status
systemctl status postgresql
brew services list | grep postgresql

# Check PostgreSQL logs
tail -f /opt/homebrew/var/log/postgresql@14.log

# Check pg_hba.conf configuration
cat /opt/homebrew/var/postgresql@14/pg_hba.conf

# List databases and users
psql -U postgres -c "\l"
psql -U postgres -c "\du"
```

### MS SQL Server
```bash
# Check MS SQL service status
systemctl status mssql-server

# Check MS SQL logs
sudo journalctl -u mssql-server -f

# Test SA account
/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'SApassword' -Q "SELECT name FROM sys.databases"
```

### Network Testing
```bash
# Check listening ports
netstat -an | grep -E '5432|1433'
lsof -i :5432
lsof -i :1433

# Test connectivity from remote host
curl -v telnet://hostname:5432
curl -v telnet://hostname:1433
```

## Environment Variables

### PostgreSQL
```bash
export PGHOST=localhost
export PGPORT=5432
export PGUSER=test_user
export PGPASSWORD='P@ssw0rd'
export PGDATABASE=test_db
```

### MS SQL Server
```bash
export SQLCMDSERVER=localhost,1433
export SQLCMDUSER=test_user
export SQLCMDPASSWORD='P@ssw0rd'
export SQLCMDDBNAME=test_db
```

## Quick Test Scripts

### PostgreSQL Quick Test
```bash
#!/bin/bash
echo "Testing PostgreSQL connection..."
PGPASSWORD='P@ssw0rd' psql -h localhost -p 5432 -U test_user -d test_db -c "SELECT 'Connection successful' as status, version() as version, current_user, ssl_in_use();" || echo "Connection failed"
```

### MS SQL Quick Test
```bash
#!/bin/bash
echo "Testing MS SQL connection..."
/opt/mssql-tools/bin/sqlcmd -S localhost,1433 -U test_user -P 'P@ssw0rd' -d test_db -Q "SELECT 'Connection successful' as status, @@VERSION as version, USER_NAME() as current_user" || echo "Connection failed"
```

### Azure SQL Quick Test
```bash
#!/bin/bash
echo "Testing Azure SQL connection..."
/opt/mssql-tools/bin/sqlcmd -S sql-server.database.windows.net -U sqladmin -P 'password' -d test_db -Q "SELECT 'Connection successful' as status" -N -C || echo "Connection failed"
```

## Notes

- Always use strong passwords in production environments
- Enable SSL/TLS encryption for all database connections
- Use vault or secrets management for storing credentials
- Run InSpec profiles regularly for continuous compliance monitoring
- Integrate with CI/CD pipelines for automated compliance checks
- Use AAP (Ansible Automation Platform) for enterprise-scale deployments
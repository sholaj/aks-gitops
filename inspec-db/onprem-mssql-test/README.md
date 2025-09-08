# On-Premise MS SQL Server Compliance Testing

This directory contains tools and scripts for testing MS SQL Server compliance in on-premise environments using InSpec.

## Prerequisites

- InSpec binary installed on the scanning machine
- MS SQL Server running on target host
- SQL Server command line tools (`sqlcmd`) installed
- Network connectivity to target MS SQL Server

## Files Overview

### Setup Scripts
- **`setup-mssql-test.sh`** - Sets up test database, user, and sample data
- **`simulate-onprem-scan.sh`** - Runs a simulated compliance scan for demo purposes

### Scanning Scripts
- **`run-inspec-scan.sh`** - Executes actual InSpec compliance scan
- **`test-mssql-onprem.yml`** - Ansible playbook for automated scanning

### Results Directory
- **`scan-results/`** - Contains all scan outputs (JSON, HTML, summary reports)

## Quick Start

### Option 1: Simulated Scan (Demo)
```bash
# Run simulated scan for demonstration
./simulate-onprem-scan.sh
```

### Option 2: Real Environment Scan

1. **Setup MS SQL Server environment:**
```bash
# Setup test database and user (requires SA password)
./setup-mssql-test.sh 'YourSAPassword'
```

2. **Run InSpec scan:**
```bash
# Set environment variables (optional)
export MSSQL_HOST=localhost
export MSSQL_PORT=1433
export MSSQL_USER=test_user
export MSSQL_PASSWORD='P@ssw0rd'
export MSSQL_DATABASE=test_db

# Execute scan
./run-inspec-scan.sh
```

3. **Or use Ansible:**
```bash
# Run with Ansible playbook
ansible-playbook test-mssql-onprem.yml
```

## Configuration

### Environment Variables
- `MSSQL_HOST` - Target MS SQL Server host (default: localhost)
- `MSSQL_PORT` - Target MS SQL Server port (default: 1433)
- `MSSQL_USER` - Database user for scanning (default: test_user)
- `MSSQL_PASSWORD` - Password for database user (default: P@ssw0rd)
- `MSSQL_DATABASE` - Target database name (default: test_db)

### Custom Configuration
Edit the scripts to modify connection parameters or scan settings as needed.

## Compliance Controls

The InSpec profile tests the following security controls:

1. **SSL/TLS Encryption** - Verifies Force Encryption is enabled
2. **Password Policy** - Checks password policy enforcement for SQL logins
3. **Audit Configuration** - Validates SQL Server Audit is enabled
4. **xp_cmdshell** - Ensures xp_cmdshell is disabled

## Output Formats

Each scan generates multiple output formats:
- **JSON** - Machine-readable results for integration
- **HTML** - Visual report for human review
- **Summary** - Text-based executive summary

## Example Results

**Simulated Scan Output:**
```
Profile Summary: 3 successful controls, 1 control failure, 0 controls skipped
Test Summary: 3 successful, 1 failure, 0 skipped
Status: NON-COMPLIANT (75% success rate)
```

**Common Issues:**
- SSL/TLS encryption not enforced (most common failure)
- Password policies not properly configured
- Audit logging disabled

## Troubleshooting

### Connection Issues
```bash
# Test basic connectivity
telnet localhost 1433

# Test with sqlcmd
sqlcmd -S localhost,1433 -U test_user -P 'P@ssw0rd' -Q "SELECT 1"
```

### Permission Issues
- Ensure scanning user has VIEW SERVER STATE permission
- Grant VIEW DATABASE STATE for database-level checks
- Consider using a service account with minimal required permissions

### Network Issues
- Check firewall rules for port 1433
- Verify MS SQL Server is listening on correct port
- Test from scanning host to target host

## Integration with Enterprise Systems

### Ansible Automation Platform (AAP)
- Use the provided Ansible playbook for AAP integration
- Configure inventory groups for different environments
- Set up vault for credential management

### CI/CD Integration
- Run scans as part of deployment pipeline
- Parse JSON output for automated compliance validation
- Generate compliance dashboards from scan results

### Scheduled Scanning
```bash
# Add to crontab for weekly scans
0 2 * * 1 /path/to/run-inspec-scan.sh
```

## Customization

### Adding Custom Controls
1. Modify the InSpec profile in `../mssql/inspec-profiles/`
2. Add new control definitions
3. Update expected values and thresholds

### Custom Reporting
- Modify summary templates in scripts
- Add organization-specific compliance requirements
- Integrate with external reporting systems

## Security Considerations

- Store credentials securely (use Ansible Vault or similar)
- Use dedicated scanning accounts with minimal permissions
- Encrypt scan results if they contain sensitive information
- Regularly rotate scanning account passwords
- Monitor and audit scanning activities
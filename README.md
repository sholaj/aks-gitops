# MSSQL InSpec Compliance Scanner

A production-ready Ansible solution for automated MSSQL database compliance scanning using InSpec controls, refactored from the original `NIST_for_db.ksh` Bash script.

## 🎯 Overview

This solution provides:
- **Automated MSSQL compliance scanning** using InSpec controls
- **Inventory-based architecture** with per-database credentials
- **AAP (Ansible Automation Platform) compatibility**
- **Secure credential management** via Ansible Vault
- **Scalable parallel execution** for multiple databases
- **Splunk integration** for result forwarding

## 📁 Repository Structure

```
├── mssql_inspec/                    # Ansible role for MSSQL scanning
│   ├── tasks/                       # Modular task files
│   ├── defaults/                    # Default variables
│   ├── files/MSSQL{VERSION}_ruby/   # InSpec controls by version
│   └── templates/                   # Report templates
├── convert_flatfile_to_inventory.py # Flat file to inventory converter
├── run_mssql_inspec.yml            # Main playbook
├── claude.md                       # Project context and requirements
├── .vaultpass                      # Vault password (POC mode)
└── docs/                           # Documentation
    ├── BASH_SCRIPT_ANALYSIS.md     # Original script analysis
    ├── DB_TEAM_INTEGRATION.md      # DB team integration guide
    ├── PROJECT_SUMMARY.md          # Complete project summary
    ├── INVENTORY_USAGE.md          # Inventory usage guide
    ├── FUTURE_ORACLE_TODO.md       # Oracle implementation roadmap
    └── FUTURE_SYBASE_TODO.md       # Sybase implementation roadmap
```

## 🚀 Quick Start

### 1. Convert Database Inventory
```bash
# Convert flat file to Ansible inventory
./convert_flatfile_to_inventory.py -i databases.txt -o inventory.yml --vault-template vault.yml
```

### 2. Configure Passwords
```bash
# DB team updates vault.yml with actual passwords
# Encrypt vault file
ansible-vault encrypt vault.yml --vault-password-file .vaultpass
```

### 3. Run Compliance Scans
```bash
# Scan all MSSQL databases
ansible-playbook -i inventory.yml run_mssql_inspec.yml -e @vault.yml --vault-password-file .vaultpass

# Scan specific databases
ansible-playbook -i inventory.yml run_mssql_inspec.yml --limit "server1_*"
```

## 📊 Input Format

### Flat File (6 fields, no credentials)
```
PLATFORM SERVER_NAME DB_NAME SERVICE_NAME PORT VERSION
MSSQL m02dsm3 m02dsm3 BIRS_Confidential 1733 2017
MSSQL sqlserver01 production_db null 1433 2019
```

### Generated Inventory
```yaml
all:
  children:
    mssql_databases:
      hosts:
        m02dsm3_m02dsm3_1733:
          mssql_server: m02dsm3
          mssql_port: 1733
          mssql_database: m02dsm3
          mssql_service: BIRS_Confidential
          mssql_version: "2017"
          mssql_username: nist_scan_user
```

## 🔒 Security Features

- **No credentials in flat files** - DB team provides passwords separately
- **Ansible Vault integration** - All passwords encrypted
- **Service account based** - Uses dedicated scanning accounts
- **Minimal permissions** - Read-only database access required
- **Audit logging** - Comprehensive result tracking

## 🏢 Production Deployment

### Ansible Automation Platform (AAP)
1. Upload `inventory.yml` as inventory source
2. Add encrypted `vault.yml` as extra variables
3. Configure vault password as credential
4. Enable Splunk integration via extra vars
5. Schedule scans and configure notifications

### Supported MSSQL Versions
- MSSQL 2008, 2012, 2014, 2016, 2017, 2018, 2019
- Version-specific InSpec controls
- Automatic control selection based on database version

## 📈 Results and Reporting

- **JSON output** matching original script format
- **File naming**: `MSSQL_NIST_{PID}_{SERVER}_{DB}_{VERSION}_{TIMESTAMP}_{CONTROL}.json`
- **Summary reports** with compliance scores
- **Error handling** for connection failures
- **Splunk forwarding** for centralized analysis

## 🔧 Requirements

- Ansible 2.9+
- InSpec installed (`/usr/bin/inspec`)
- Network access to MSSQL servers
- Valid MSSQL credentials with appropriate permissions

## 📚 Documentation

- [Complete Project Summary](PROJECT_SUMMARY.md)
- [DB Team Integration Guide](DB_TEAM_INTEGRATION.md)
- [Original Script Analysis](BASH_SCRIPT_ANALYSIS.md)
- [Inventory Usage Guide](INVENTORY_USAGE.md)
- [Future Oracle Roadmap](FUTURE_ORACLE_TODO.md)
- [Future Sybase Roadmap](FUTURE_SYBASE_TODO.md)

## 🎯 Key Benefits

1. **Scalability** - Handle hundreds of databases in parallel
2. **Security** - Vault-encrypted credentials, no hardcoded secrets
3. **Flexibility** - Per-database credentials, selective scanning
4. **Integration** - Splunk forwarding, AAP compatibility
5. **Maintainability** - Modular role structure, clear documentation
6. **Compatibility** - Exact file naming and error handling as original script

## 📧 Support

- **Security Team**: Compliance scanning issues
- **DevOps Team**: Ansible/infrastructure issues
- **DB Team**: Password and permission issues

## 📄 License

Internal use only

---

**Generated with [Claude Code](https://claude.ai/code)**
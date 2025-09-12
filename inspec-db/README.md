# Database Connectivity Testing for RHEL 8.10

Complete solution for testing database connectivity to MSSQL, Oracle, and Sybase on RHEL 8.10 in airgapped environments.

## Quick Start

```bash
# One-command setup
chmod +x quick-setup.sh
./quick-setup.sh
```

## What This Provides

### 🔧 Database Client Tools
- **sqlcmd** - Microsoft SQL Server client
- **sqlplus** - Oracle database client  
- **isql/tsql** - Sybase/FreeTDS client

### 🤖 Automation
- **Ansible** - For deploying across multiple servers
- **Vagrant VM** - Local development environment
- **Testing framework** - Comprehensive validation

### 📦 Airgapped Ready
- **Direct downloads** from official sources
- **No internet required** after initial download
- **RPM packages** for offline installation

## Files Overview

### Core Scripts
- **`quick-setup.sh`** - Main setup script with menu options
- **`download-binaries.sh`** - Downloads database client tools
- **`download-ansible-binary.sh`** - Downloads Ansible for automation
- **`db-connectivity-tests.sh`** - Comprehensive testing framework
- **`test-download-urls.sh`** - Validates all download URLs

### Documentation
- **`database-connectivity-setup.md`** - Detailed installation guide
- **`updated-download-urls.md`** - Current working URLs (tested Jan 2025)
- **`rhel-8.10-vm-setup.md`** - VM setup instructions
- **`URL_VALIDATION_REPORT.md`** - Latest URL validation results

### VM Development
- **`vagrant-vm-setup/`** - Automated VM creation with Vagrantfile

## Setup Options

### Option 1: Download Only (for Airgapped Transfer)
```bash
./quick-setup.sh
# Choose option 1: Database clients only
# Choose option 2: Ansible only  
# Choose option 3: Both downloads
```

### Option 2: Local VM Development
```bash
./quick-setup.sh
# Choose option 4: Setup local VM
```

### Option 3: Complete Setup
```bash
./quick-setup.sh
# Choose option 5: Download everything + VM
```

## Manual Installation

### Database Clients Only
```bash
# Download
chmod +x download-binaries.sh
./download-binaries.sh

# Transfer to airgapped system
scp db-binaries-*.tar.gz user@target-system:

# Install on target system
tar xzf db-binaries-*.tar.gz
cd db-binaries-*
./install.sh
source ~/.bashrc

# Test
sqlcmd -?
sqlplus -version
isql --version
```

### With Ansible Automation
```bash
# Download both database clients and Ansible
./download-binaries.sh
./download-ansible-binary.sh

# Transfer both archives to control node
scp *.tar.gz ansible-control-node:

# Install Ansible on control node
tar xzf ansible-binaries-*.tar.gz
cd ansible-binaries-*
./install-ansible.sh

# Deploy database clients to target servers
ansible-playbook install-db-clients.yml -i inventory.ini
```

## Testing

### Basic Testing
```bash
chmod +x db-connectivity-tests.sh
./db-connectivity-tests.sh
```

### Network Connectivity Testing  
```bash
./db-connectivity-tests.sh --test-servers \
  --mssql-server sqlserver.example.com:1433 \
  --oracle-server oracle.example.com:1521 \
  --sybase-server sybase.example.com:5000
```

### Live Connection Testing
```bash
./db-connectivity-tests.sh --test-connections \
  --mssql-conn "server,1433|username|password" \
  --oracle-conn "user/pass@//host:1521/service" \
  --sybase-conn "host|5000|user|pass"
```

## Package Versions (Current as of Jan 2025)

| Component | Version | Source |
|-----------|---------|--------|
| MSSQL Tools | 18.3.1.1-1 | Microsoft |
| Oracle Client | 21.13.0.0.0-1 | Oracle |
| FreeTDS | 1.4.23-1.el8 | EPEL |
| Ansible | 9.2.0-1.el8 | EPEL |

## URL Validation

All download URLs are regularly tested. Last validation: **January 12, 2025**

To test current URLs:
```bash
chmod +x test-download-urls.sh
./test-download-urls.sh
```

## Architecture

```
Internet-Connected System          Airgapped RHEL 8.10 System(s)
├── download-binaries.sh          ├── db-binaries-YYYYMMDD.tar.gz
├── download-ansible-binary.sh    ├── ansible-binaries-YYYYMMDD.tar.gz
└── Downloads packages            └── Install + Deploy
                                      ├── sqlcmd ✅
    Transfer via:                     ├── sqlplus ✅
    ├── USB drive                     ├── isql ✅
    ├── Secure file transfer          └── ansible ✅
    └── Physical media
```

## InSpec Integration

Once database connectivity is established, use with InSpec:

```ruby
# Example InSpec test
describe mssql_session(user: 'sa', password: 'pass', host: 'server') do
  its('query("SELECT @@VERSION").rows.first') { should include 'Microsoft SQL Server' }
end

describe oracledb_session(user: 'system', password: 'pass', host: 'server', service: 'ORCL') do
  its('query("SELECT * FROM v$version").rows.first') { should include 'Oracle Database' }
end
```

## Troubleshooting

### Common Issues

1. **Package not found**
   - Run `./test-download-urls.sh` to verify URLs
   - Check `URL_VALIDATION_REPORT.md` for latest status

2. **Permission denied**
   - Ensure scripts are executable: `chmod +x *.sh`
   - Check SELinux: `getenforce` (set to permissive for testing)

3. **Network timeouts**
   - URLs are tested and working as of Jan 2025
   - Try different mirror if available

4. **Vagrant issues**
   - Ensure VirtualBox is installed
   - Check available memory (4GB+ recommended)

## Support

For issues:
1. Check `URL_VALIDATION_REPORT.md` for latest URL status
2. Run `./db-connectivity-tests.sh` for diagnostics
3. Review logs in generated `*-results-*.log` files

---
**Last Updated:** January 12, 2025  
**Tested Environment:** RHEL 8.10, CentOS 8, Rocky Linux 8, AlmaLinux 8  
**URL Status:** ✅ All validated and working
# Database Connectivity Tools for RHEL 8.10 Airgapped Environments

Complete offline database connectivity solution for MSSQL, Oracle, and Sybase on airgapped RHEL 8.10 systems.

## 🚀 Quick Start - Production Ready

### Ready-to-Deploy Package (RECOMMENDED)
Use the complete airgapped installation package:

```bash
# 1. Copy to airgapped RHEL 8.10 server
unzip deliverables/db-tools-airgapped-complete.zip

# 2. Install all tools
cd airgapped-rpms
sudo ./scripts/install.sh

# 3. Configure environment  
source /etc/profile

# 4. Verify installation
sqlcmd -?           # Microsoft SQL Server
sqlplus -version    # Oracle Database
isql --version      # Sybase/FreeTDS
```

### What's Included in the Package
- **Microsoft SQL Server Tools 18** - sqlcmd, ODBC Driver
- **Oracle Instant Client 21.13** - sqlplus with full client libraries
- **FreeTDS 1.4.23** - isql/tsql for Sybase connectivity
- **All Dependencies** - 26 RPM packages, completely offline

## 📦 Deliverables

### Primary Package
- **`deliverables/db-tools-airgapped-complete.zip`** (60MB)
- Contains everything needed for offline installation
- Tested on real RHEL 8 environment
- **Ready for production deployment**

### Alternative Format
- **`deliverables/airgapped-rpms.tar.gz`** (60MB)
- Same content in tar.gz format

## 🔧 Database Connection Examples

### Microsoft SQL Server
```bash
sqlcmd -S server.example.com,1433 -U username -P password -C
```

### Oracle Database
```bash
sqlplus user/password@//server.example.com:1521/SERVICENAME
```

### Sybase Database
```bash
tsql -S server.example.com -p 5000 -U username -P password
isql -S server -U username -P password
```

## 📋 System Requirements

- **OS**: RHEL 8.10, Rocky Linux 8, AlmaLinux 8, CentOS 8
- **Architecture**: x86_64
- **Privileges**: sudo/root access for installation
- **Space**: ~200MB for installation
- **Network**: None required (fully offline)

## 🛠️ Development Tools (Optional)

For developers working on this project:

### URL Validation
```bash
./test-download-urls.sh       # Validates all package URLs
./test-db-tools-setup.sh      # Tests package availability
```

### Package Creation
```bash
./azure-rpm-downloader-fixed.sh  # Creates packages using Azure VM
```

### Legacy Scripts
- `download-binaries.sh` - Original download script
- `quick-setup.sh` - Interactive setup menu
- `db-connectivity-tests.sh` - Comprehensive testing

## 📖 Documentation

- **`AIRGAPPED_INSTALLATION_COMPLETE.md`** - Complete deployment guide
- **`deliverables/README.md`** - Package details and instructions
- **`LOCAL_DEV_SETUP_SUMMARY.md`** - Development environment summary
- **`URL_VALIDATION_REPORT.md`** - Latest package URL validation

## 🔍 Package Creation Process

The airgapped packages were created using Azure RHEL 8 VM with complete dependency resolution:

1. **Azure VM Creation** - Spins up RHEL 8 VM
2. **Repository Setup** - Configures Microsoft, EPEL, and base repos
3. **Dependency Resolution** - Downloads all required dependencies
4. **Package Testing** - Installs and tests all tools
5. **Archive Creation** - Creates deployment-ready packages
6. **Resource Cleanup** - Automatically removes Azure resources

## 🧪 Testing

### Basic Verification
The installation script automatically configures:
- PATH variables for all tools
- Oracle environment variables
- Library paths and ldconfig

### Connection Testing
Test connectivity to your database servers using the connection examples above.

## 🐛 Troubleshooting

### Installation Issues
1. **Permission denied**: Ensure you have sudo access
2. **Package conflicts**: Use `--nodeps` flag (included in install script)
3. **Missing libraries**: All dependencies are included in the package

### Connection Issues
1. **Command not found**: Run `source /etc/profile`
2. **Library errors**: Run `sudo ldconfig`
3. **Connection refused**: Verify server address and firewall settings

## 📊 Package Information

| Component | Version | Size | Source |
|-----------|---------|------|--------|
| MSSQL Tools | 18.4.1.1 | ~300KB | Microsoft |
| ODBC Driver | 18.5.1.1 | ~950KB | Microsoft |
| Oracle Client | 21.13.0.0.0 | ~56MB | Oracle |
| FreeTDS | 1.4.23 | ~400KB | EPEL |
| **Total Package** | **Multiple** | **60MB** | **Tested & Verified** |

## 🏢 Enterprise Ready

This solution is designed for:
- **Airgapped environments** with no internet access
- **Enterprise RHEL 8.10** deployments
- **Compliance requirements** with offline installation
- **Multiple server deployments** using the same package

---
**Created**: January 12, 2025  
**Tested On**: RHEL 8.10, Rocky Linux 8  
**Status**: ✅ Production Ready  
**Package Size**: 60MB (complete offline solution)
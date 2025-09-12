# Database Tools Deliverables

## Ready-to-Deploy Packages

### Primary Package
- **`db-tools-airgapped-complete.zip`** (60MB)
  - Complete offline installation package
  - 26 RPM packages with all dependencies
  - Includes installation script and documentation
  - **RECOMMENDED FOR DEPLOYMENT**

### Alternative Format
- **`airgapped-rpms.tar.gz`** (60MB)
  - Same content as zip file, tar.gz format
  - Use if zip format is not preferred

## Installation on Airgapped Server

1. **Copy package** to target RHEL 8.10 server
2. **Extract**: `unzip db-tools-airgapped-complete.zip`
3. **Install**: `sudo ./airgapped-rpms/scripts/install.sh`
4. **Configure**: `source /etc/profile`
5. **Test**: Run `sqlcmd -?`, `sqlplus -version`, `isql --version`

## Included Database Tools
- **Microsoft SQL Server** - sqlcmd, ODBC Driver 18
- **Oracle Database** - sqlplus, Instant Client 21.13
- **Sybase/SQL Server** - isql, tsql (FreeTDS 1.4.23)

## Package Details
- **Created**: January 12, 2025
- **Source**: Azure RHEL 8 VM with proper repositories
- **Target OS**: RHEL 8.10, Rocky Linux 8, AlmaLinux 8
- **Architecture**: x86_64
- **Dependencies**: All included (no internet required)

## Support
See parent directory documentation for detailed installation instructions and troubleshooting.
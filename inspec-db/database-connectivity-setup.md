# Database Connectivity Setup for RHEL 8.10
## For Airgapped Environment - InSpec Database Scanning Prerequisites

This document provides comprehensive instructions for setting up database client tools on RHEL 8.10 for testing connectivity to MSSQL, Oracle, and Sybase databases before conducting InSpec scanning.

## Required Client Tools
- **sqlcmd** - Microsoft SQL Server command-line client
- **sqlplus** - Oracle database command-line client  
- **isql** - Sybase/SAP ASE and generic ODBC command-line client

## 1. Microsoft SQL Server Client (sqlcmd)

### Required RPM Packages
Download these packages from a system with internet access:

```bash
# Microsoft Red Hat repository RPM
wget https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm

# Core packages (download from packages.microsoft.com after adding repo)
msodbcsql18-18.3.3.1-1.x86_64.rpm
mssql-tools18-18.3.1.1-1.x86_64.rpm
unixODBC-2.3.7-1.el8.x86_64.rpm
unixODBC-devel-2.3.7-1.el8.x86_64.rpm
```

### Download Commands (on internet-connected system)
```bash
# Create download directory
mkdir -p mssql-rpms
cd mssql-rpms

# Add Microsoft repository temporarily
sudo rpm -Uvh https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm

# Download packages without installing
sudo yum download --downloadonly --downloaddir=. msodbcsql18 mssql-tools18 unixODBC unixODBC-devel

# Download dependencies
sudo yum deplist msodbcsql18 mssql-tools18 | grep provider | awk '{print $2}' | sort -u | while read dep; do
    sudo yum download --downloadonly --downloaddir=. $dep
done
```

### Installation on Airgapped RHEL 8.10
```bash
# Transfer all RPMs to target system, then:
cd /path/to/mssql-rpms
sudo rpm -ivh *.rpm

# Add sqlcmd to PATH
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
```

## 2. Oracle Client (sqlplus)

### Required RPM Packages
Download Oracle Instant Client RPMs from Oracle's website (requires Oracle account):
- Visit: https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html

Required packages for RHEL 8:
```
oracle-instantclient-basic-21.13.0.0.0-1.x86_64.rpm
oracle-instantclient-sqlplus-21.13.0.0.0-1.x86_64.rpm
oracle-instantclient-devel-21.13.0.0.0-1.x86_64.rpm (optional)
```

### Download Commands (on internet-connected system)
```bash
# Create download directory
mkdir -p oracle-rpms
cd oracle-rpms

# Download dependencies
sudo yum download --downloadonly --downloaddir=. libaio libaio-devel

# Manually download Oracle RPMs from website (authentication required)
# Place downloaded Oracle RPMs in this directory
```

### Installation on Airgapped RHEL 8.10
```bash
# Transfer all RPMs to target system, then:
cd /path/to/oracle-rpms
sudo rpm -ivh libaio*.rpm
sudo rpm -ivh oracle-instantclient*.rpm

# Set Oracle environment variables
echo 'export ORACLE_HOME=/usr/lib/oracle/21/client64' >> ~/.bashrc
echo 'export PATH=$PATH:$ORACLE_HOME/bin' >> ~/.bashrc
echo 'export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc
```

## 3. Sybase/SAP ASE Client (isql)

### Required RPM Packages
For Sybase connectivity, we'll use FreeTDS which provides isql:

```bash
# FreeTDS packages
freetds-1.3.3-1.el8.x86_64.rpm
freetds-libs-1.3.3-1.el8.x86_64.rpm
freetds-devel-1.3.3-1.el8.x86_64.rpm
```

### Download Commands (on internet-connected system)
```bash
# Create download directory
mkdir -p sybase-rpms
cd sybase-rpms

# Enable EPEL repository temporarily
sudo yum install -y epel-release

# Download FreeTDS packages
sudo yum download --downloadonly --downloaddir=. freetds freetds-libs freetds-devel

# Download dependencies
sudo yum deplist freetds | grep provider | awk '{print $2}' | sort -u | while read dep; do
    sudo yum download --downloadonly --downloaddir=. $dep
done
```

### Installation on Airgapped RHEL 8.10
```bash
# Transfer all RPMs to target system, then:
cd /path/to/sybase-rpms
sudo rpm -ivh *.rpm
```

## 4. Complete Package List for Download

Create this script on an internet-connected RHEL 8.10 system to download all packages:

```bash
#!/bin/bash
# download-db-clients.sh

# Create main directory
mkdir -p db-client-packages
cd db-client-packages

# 1. Microsoft SQL Server packages
mkdir mssql
cd mssql
sudo rpm -Uvh https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm
sudo yum download --downloadonly --downloaddir=. msodbcsql18 mssql-tools18 unixODBC unixODBC-devel
cd ..

# 2. FreeTDS for Sybase
mkdir freetds
cd freetds
sudo yum install -y epel-release
sudo yum download --downloadonly --downloaddir=. freetds freetds-libs freetds-devel
cd ..

# 3. Common dependencies
mkdir common
cd common
sudo yum download --downloadonly --downloaddir=. \
    libaio libaio-devel \
    openssl openssl-libs \
    krb5-libs \
    cyrus-sasl-gssapi \
    cyrus-sasl-plain \
    readline \
    ncurses-libs
cd ..

# Create tarball for transfer
tar czf db-client-packages.tar.gz *

echo "Package download complete. Transfer db-client-packages.tar.gz to airgapped system."
```

## 5. Installation Script for Airgapped System

Create this script on the airgapped RHEL 8.10 system:

```bash
#!/bin/bash
# install-db-clients.sh

# Extract packages
tar xzf db-client-packages.tar.gz

# Install common dependencies first
cd common
sudo rpm -ivh --nodeps *.rpm
cd ..

# Install MSSQL tools
cd mssql
sudo rpm -ivh --nodeps *.rpm
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
cd ..

# Install FreeTDS
cd freetds
sudo rpm -ivh --nodeps *.rpm
cd ..

# Source new PATH
source ~/.bashrc

echo "Installation complete. Verify with:"
echo "  sqlcmd -?"
echo "  isql --version"
echo "Note: Oracle client must be installed separately due to licensing."
```

## 6. Testing Database Connectivity

### Test MSSQL Connection
```bash
# Using sqlcmd (trusted connection with encryption)
sqlcmd -S <server_name>,<port> -U <username> -P <password> -C

# Example
sqlcmd -S mssql-server.example.com,1433 -U sa -P 'YourPassword' -C -Q "SELECT @@VERSION"
```

### Test Oracle Connection
```bash
# Using sqlplus
sqlplus username/password@//hostname:port/service_name

# Example
sqlplus scott/tiger@//oracle-server.example.com:1521/ORCL
```

### Test Sybase Connection
```bash
# First configure FreeTDS
sudo vi /etc/freetds.conf

# Add server configuration:
[SYBASE_SERVER]
    host = sybase-server.example.com
    port = 5000
    tds version = 5.0

# Test with isql
isql -S SYBASE_SERVER -U username -P password

# Or use tsql
tsql -S SYBASE_SERVER -U username -P password
```

## 7. Configuration Files

### ODBC Configuration (/etc/odbcinst.ini)
```ini
[FreeTDS]
Description = FreeTDS Driver
Driver = /usr/lib64/libtdsodbc.so.0
Setup = /usr/lib64/libtdsS.so

[ODBC Driver 18 for SQL Server]
Description=Microsoft ODBC Driver 18 for SQL Server
Driver=/opt/microsoft/msodbcsql18/lib64/libmsodbcsql-18.so
```

### DSN Configuration (/etc/odbc.ini)
```ini
[MSSQLSERVER]
Driver = ODBC Driver 18 for SQL Server
Server = tcp:mssql-server.example.com,1433
TrustServerCertificate = yes

[SYBASESERVER]
Driver = FreeTDS
Server = sybase-server.example.com
Port = 5000
TDS_Version = 5.0
```

## 8. Troubleshooting

### Common Issues and Solutions

1. **Missing dependencies**
   ```bash
   # Check missing dependencies
   rpm -qpR package.rpm
   
   # Install with --nodeps if non-critical
   sudo rpm -ivh --nodeps package.rpm
   ```

2. **Library path issues**
   ```bash
   # Add library paths
   echo "/opt/microsoft/msodbcsql18/lib64" | sudo tee /etc/ld.so.conf.d/mssql.conf
   sudo ldconfig
   ```

3. **SSL/TLS certificate issues with MSSQL**
   ```bash
   # Trust server certificate (for testing only)
   sqlcmd -S server -U user -P pass -C
   
   # Or set environment variable
   export MSSQL_CERTIFICATE_CHECK=no
   ```

4. **FreeTDS version compatibility**
   ```bash
   # Test different TDS versions if connection fails
   tsql -S server -U user -P pass -T 7.0
   tsql -S server -U user -P pass -T 7.4
   ```

## 9. Verification Commands

Run these commands to verify successful installation:

```bash
# Check sqlcmd
sqlcmd -?
which sqlcmd

# Check isql (FreeTDS)
isql --version
which isql

# Check tsql (FreeTDS)
tsql -C

# Check Oracle sqlplus (if installed)
sqlplus -version
which sqlplus

# List ODBC drivers
odbcinst -q -d

# List ODBC data sources
odbcinst -q -s
```

## 10. InSpec Database Resource Examples

Once connectivity is verified, you can use InSpec database resources:

```ruby
# MSSQL example
describe mssql_session(user: 'sa', password: 'password', host: 'server', port: 1433) do
  its('query("SELECT @@VERSION").rows.first') { should include 'Microsoft SQL Server' }
end

# Oracle example
describe oracledb_session(user: 'system', password: 'password', host: 'server', service: 'ORCL') do
  its('query("SELECT * FROM v$version").rows.first') { should include 'Oracle Database' }
end
```

## Notes
- Always test connectivity in a development environment first
- Ensure firewall rules allow database ports (1433 for MSSQL, 1521 for Oracle, 5000 for Sybase)
- Keep RPM packages updated for security patches
- Document specific versions used for compliance tracking
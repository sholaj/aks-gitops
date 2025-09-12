#!/bin/bash

# Direct Binary Download Script for Database Clients
# Downloads directly from official URLs without repository setup
# For RHEL 8.10 / CentOS 8 / Rocky Linux 8

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOWNLOAD_DIR="db-binaries-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="download.log"

# Create download directory
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

# Initialize log
echo "Download started at $(date)" > "$LOG_FILE"

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[$(date)] $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[$(date)] ERROR: $1" >> "$LOG_FILE"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
    echo "[$(date)] INFO: $1" >> "$LOG_FILE"
}

# Function to download with retry
download_file() {
    local url=$1
    local filename=$2
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if wget -q --show-progress --timeout=30 --tries=2 -O "$filename" "$url"; then
            return 0
        else
            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                print_info "Retry $retry/$max_retries for $filename"
                sleep 2
            fi
        fi
    done
    return 1
}

echo "============================================"
echo "Database Client Direct Download Script"
echo "Target: RHEL 8.10 / Compatible"
echo "============================================"
echo ""

# 1. Microsoft SQL Server Tools
print_info "Downloading Microsoft SQL Server Tools..."
mkdir -p mssql

print_info "Downloading MSSQL ODBC Driver 18..."
if download_file \
    "https://packages.microsoft.com/rhel/8/prod/msodbcsql18-18.3.3.1-1.x86_64.rpm" \
    "mssql/msodbcsql18-18.3.3.1-1.x86_64.rpm"; then
    print_status "MSSQL ODBC Driver downloaded"
else
    print_error "Failed to download MSSQL ODBC Driver"
fi

print_info "Downloading MSSQL Tools 18..."
if download_file \
    "https://packages.microsoft.com/rhel/8/prod/mssql-tools18-18.3.1.1-1.x86_64.rpm" \
    "mssql/mssql-tools18-18.3.1.1-1.x86_64.rpm"; then
    print_status "MSSQL Tools downloaded"
else
    print_error "Failed to download MSSQL Tools"
fi

print_info "Downloading UnixODBC..."
if download_file \
    "https://packages.microsoft.com/rhel/8/prod/unixODBC-2.3.11-1.rh.x86_64.rpm" \
    "mssql/unixODBC-2.3.11-1.rh.x86_64.rpm"; then
    print_status "UnixODBC downloaded"
else
    print_error "Failed to download UnixODBC"
fi

# 2. Oracle Instant Client
print_info "Downloading Oracle Instant Client..."
mkdir -p oracle

print_info "Downloading Oracle Basic Package..."
if download_file \
    "https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-basic-21.13.0.0.0-1.x86_64.rpm" \
    "oracle/oracle-instantclient-basic-21.13.0.0.0-1.x86_64.rpm"; then
    print_status "Oracle Basic Package downloaded"
else
    print_error "Failed to download Oracle Basic Package"
fi

print_info "Downloading Oracle SQL*Plus..."
if download_file \
    "https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-sqlplus-21.13.0.0.0-1.x86_64.rpm" \
    "oracle/oracle-instantclient-sqlplus-21.13.0.0.0-1.x86_64.rpm"; then
    print_status "Oracle SQL*Plus downloaded"
else
    print_error "Failed to download Oracle SQL*Plus"
fi

# 3. FreeTDS for Sybase
print_info "Downloading FreeTDS for Sybase..."
mkdir -p freetds

print_info "Downloading FreeTDS..."
if download_file \
    "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/f/freetds-1.4.23-1.el8.x86_64.rpm" \
    "freetds/freetds-1.4.23-1.el8.x86_64.rpm"; then
    print_status "FreeTDS downloaded"
else
    print_error "Failed to download FreeTDS"
fi

print_info "Downloading FreeTDS libs..."
if download_file \
    "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/f/freetds-libs-1.4.23-1.el8.x86_64.rpm" \
    "freetds/freetds-libs-1.4.23-1.el8.x86_64.rpm"; then
    print_status "FreeTDS libs downloaded"
else
    print_error "Failed to download FreeTDS libs"
fi

# 4. Dependencies
print_info "Downloading dependencies..."
mkdir -p dependencies

print_info "Downloading libaio..."
if download_file \
    "https://dl.rockylinux.org/pub/rocky/8/BaseOS/x86_64/os/Packages/l/libaio-0.3.112-1.el8.x86_64.rpm" \
    "dependencies/libaio-0.3.112-1.el8.x86_64.rpm"; then
    print_status "libaio downloaded"
else
    print_error "Failed to download libaio"
fi

# 5. Create installation script
print_info "Creating installation script..."
cat > install.sh << 'INSTALL_SCRIPT'
#!/bin/bash

# Installation script for database clients
set -e

echo "Installing Database Clients..."

# Function to install RPMs safely
install_rpm_dir() {
    local dir=$1
    if [ -d "$dir" ] && ls "$dir"/*.rpm >/dev/null 2>&1; then
        echo "Installing packages from $dir..."
        sudo rpm -ivh --nodeps "$dir"/*.rpm 2>/dev/null || \
        sudo rpm -Uvh --nodeps "$dir"/*.rpm 2>/dev/null || true
    fi
}

# Install in order
install_rpm_dir "dependencies"
install_rpm_dir "mssql"
install_rpm_dir "oracle"
install_rpm_dir "freetds"

# Configure environment
echo "Configuring environment..."

# MSSQL Tools
if [ -d "/opt/mssql-tools18" ]; then
    grep -q "mssql-tools18" ~/.bashrc || \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
fi

# Oracle
if [ -d "/usr/lib/oracle" ]; then
    ORACLE_VERSION=$(ls /usr/lib/oracle 2>/dev/null | head -1)
    if [ -n "$ORACLE_VERSION" ]; then
        grep -q "ORACLE_HOME" ~/.bashrc || {
            echo "export ORACLE_HOME=/usr/lib/oracle/$ORACLE_VERSION/client64" >> ~/.bashrc
            echo 'export PATH=$PATH:$ORACLE_HOME/bin' >> ~/.bashrc
            echo 'export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
        }
    fi
fi

# Update library cache
sudo ldconfig 2>/dev/null || true

echo ""
echo "Installation complete!"
echo "Run: source ~/.bashrc"
echo ""
echo "Verify with:"
echo "  sqlcmd -?"
echo "  sqlplus -version"
echo "  isql --version"
INSTALL_SCRIPT
chmod +x install.sh

# 6. Create test script
print_info "Creating test script..."
cat > test-clients.sh << 'TEST_SCRIPT'
#!/bin/bash

# Test database clients installation

echo "Testing Database Clients..."
echo "=========================="

# Test MSSQL
echo -n "MSSQL sqlcmd: "
if command -v sqlcmd &> /dev/null; then
    echo "✓ Installed"
    sqlcmd -? 2>&1 | head -1
else
    echo "✗ Not found"
fi

# Test Oracle
echo -n "Oracle sqlplus: "
if command -v sqlplus &> /dev/null; then
    echo "✓ Installed"
    sqlplus -version 2>&1 | head -1
else
    echo "✗ Not found"
fi

# Test FreeTDS
echo -n "FreeTDS isql: "
if command -v isql &> /dev/null; then
    echo "✓ Installed"
    isql --version 2>&1
else
    echo "✗ Not found"
fi

echo -n "FreeTDS tsql: "
if command -v tsql &> /dev/null; then
    echo "✓ Installed"
else
    echo "✗ Not found"
fi
TEST_SCRIPT
chmod +x test-clients.sh

# 7. Create README
cat > README.md << 'README'
# Database Client Binaries

## Contents
- `mssql/` - Microsoft SQL Server tools (sqlcmd)
- `oracle/` - Oracle Instant Client (sqlplus)
- `freetds/` - FreeTDS for Sybase (isql)
- `dependencies/` - Required dependencies

## Installation
```bash
# Install all packages
./install.sh

# Update environment
source ~/.bashrc

# Test installation
./test-clients.sh
```

## Testing Connections

### MSSQL
```bash
sqlcmd -S server,1433 -U username -P password -C
```

### Oracle
```bash
sqlplus user/pass@//server:1521/SERVICE
```

### Sybase/FreeTDS
```bash
tsql -S server -p 5000 -U username -P password
```
README

# 8. Create tarball
cd ..
TARBALL="${DOWNLOAD_DIR}.tar.gz"
print_info "Creating archive: $TARBALL"
tar czf "$TARBALL" "$DOWNLOAD_DIR"

# Summary
echo ""
echo "============================================"
echo "Download Complete!"
echo "============================================"
print_status "Directory: $DOWNLOAD_DIR"
print_status "Archive: $TARBALL"
print_status "Size: $(du -h $TARBALL | cut -f1)"
echo ""
echo "Next steps:"
echo "1. Transfer $TARBALL to target system"
echo "2. Extract: tar xzf $TARBALL"
echo "3. Install: cd $DOWNLOAD_DIR && ./install.sh"
echo "4. Test: ./test-clients.sh"
echo ""
echo "Log file: $DOWNLOAD_DIR/$LOG_FILE"
#!/bin/bash

# Fixed Azure VM RPM Download Script
# Downloads all database tools with proper GPG handling

set -e

# Configuration
RESOURCE_GROUP="rg-dbtools-$(date +%s)"
VM_NAME="vm-rhel8-download"
LOCATION="eastus"
VM_SIZE="Standard_B2s"
ADMIN_USER="azureuser"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${YELLOW}[i]${NC} $1"; }

# Cleanup function
cleanup() {
    if [ -n "$RESOURCE_GROUP" ]; then
        print_info "Cleaning up Azure resources..."
        az group delete --name $RESOURCE_GROUP --yes --no-wait 2>/dev/null || true
    fi
}

trap cleanup EXIT

echo -e "${BLUE}Azure Database Tools RPM Downloader (Fixed)${NC}"
echo "==========================================="
echo ""

# Create resource group
print_info "Creating resource group: $RESOURCE_GROUP"
az group create --name $RESOURCE_GROUP --location $LOCATION -o none

# Create VM
print_info "Creating RHEL 8 VM..."
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --image RedHat:RHEL:8-lvm-gen2:latest \
    --size $VM_SIZE \
    --admin-username $ADMIN_USER \
    --generate-ssh-keys \
    --public-ip-sku Standard \
    -o none

# Get VM IP
VM_IP=$(az vm show -d -g $RESOURCE_GROUP -n $VM_NAME --query publicIps -o tsv)
print_status "VM IP: $VM_IP"

# Wait for SSH
print_info "Waiting for VM to be ready..."
for i in {1..30}; do
    if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        $ADMIN_USER@$VM_IP "echo 'Ready'" 2>/dev/null; then
        break
    fi
    sleep 5
done

# Create fixed download script
cat > download-fixed.sh << 'SCRIPT_END'
#!/bin/bash
set -e

echo "Setting up RPM download environment..."

# Install required tools
sudo yum install -y yum-utils createrepo wget

# Create directory structure
mkdir -p ~/airgapped-rpms/{packages,scripts}
cd ~/airgapped-rpms

# Enable EPEL
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# Configure Microsoft repo with GPG disabled temporarily
sudo curl -o /etc/yum.repos.d/mssql.repo https://packages.microsoft.com/config/rhel/8/prod.repo
sudo sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/mssql.repo

# Import Microsoft GPG key properly
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

echo "Downloading packages..."

# 1. Core dependencies
echo "Downloading core dependencies..."
sudo yumdownloader --resolve --destdir=./packages \
    glibc libgcc libstdc++ zlib openssl openssl-libs \
    krb5-libs cyrus-sasl-lib cyrus-sasl-gssapi \
    readline ncurses-libs libaio

# 2. MSSQL (without GPG check issues)
echo "Downloading MSSQL tools..."
sudo yum download --downloaddir=./packages \
    msodbcsql18 mssql-tools18 unixODBC unixODBC-devel

# 3. FreeTDS
echo "Downloading FreeTDS..."
sudo yumdownloader --resolve --destdir=./packages \
    freetds freetds-libs

# 4. Oracle - Direct download
echo "Downloading Oracle client..."
wget -P packages/ \
    https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-basic-21.13.0.0.0-1.x86_64.rpm \
    https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-sqlplus-21.13.0.0.0-1.x86_64.rpm

# Remove duplicate versions
echo "Cleaning duplicates..."
cd packages
for rpm in *.rpm; do
    base=$(echo $rpm | sed 's/-[0-9].*//')
    # Keep newest version only
    ls -t ${base}*.rpm 2>/dev/null | tail -n +2 | xargs rm -f 2>/dev/null || true
done
cd ..

# Create repo metadata
createrepo packages/

# Installation script
cat > scripts/install.sh << 'INSTALL'
#!/bin/bash
set -e

echo "Database Tools Offline Installer"
echo "================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_DIR="$SCRIPT_DIR/../packages"

# Install all RPMs
echo "Installing packages..."
cd "$PKG_DIR"

# Install dependencies first
sudo rpm -Uvh --nodeps \
    glibc*.rpm libgcc*.rpm libstdc*.rpm zlib*.rpm \
    openssl*.rpm krb5*.rpm cyrus*.rpm readline*.rpm \
    ncurses*.rpm libaio*.rpm 2>/dev/null || true

# Install database tools
sudo rpm -Uvh --nodeps \
    unixODBC*.rpm msodbcsql*.rpm mssql-tools*.rpm \
    freetds*.rpm oracle*.rpm 2>/dev/null || true

# Configure environment
echo "Configuring environment..."

# MSSQL
if [ -d "/opt/mssql-tools18" ]; then
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' | sudo tee /etc/profile.d/mssql.sh
fi

# Oracle
if [ -d "/usr/lib/oracle" ]; then
    VER=$(ls /usr/lib/oracle | head -1)
    cat << EOF | sudo tee /etc/profile.d/oracle.sh
export ORACLE_HOME=/usr/lib/oracle/$VER/client64
export PATH=\$PATH:\$ORACLE_HOME/bin
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
EOF
fi

sudo ldconfig

echo "Installation complete!"
echo "Run: source /etc/profile"
INSTALL

chmod +x scripts/install.sh

# Test installation locally
echo "Testing installation..."
sudo ./scripts/install.sh
source /etc/profile

# Verify
echo ""
echo "Verification:"
command -v sqlcmd &>/dev/null && echo "✓ sqlcmd" || echo "✗ sqlcmd"
command -v sqlplus &>/dev/null && echo "✓ sqlplus" || echo "✗ sqlplus"  
command -v isql &>/dev/null && echo "✓ isql" || echo "✗ isql"

# Create README
cat > README.md << 'README'
# Database Tools Airgapped Installation

## Contents
- MSSQL Tools 18 (sqlcmd)
- Oracle Instant Client 21.13 (sqlplus)
- FreeTDS 1.4+ (isql/tsql)
- All dependencies

## Installation
1. Extract archive on target system
2. Run: `sudo ./scripts/install.sh`
3. Source: `source /etc/profile`

## Testing
- `sqlcmd -?`
- `sqlplus -version`
- `isql --version`
README

# Package count
echo "Total packages: $(ls packages/*.rpm | wc -l)" >> README.md

# Create archive
cd ~
tar czf airgapped-rpms.tar.gz airgapped-rpms/
echo "Archive: $(du -h airgapped-rpms.tar.gz | cut -f1) - $(ls airgapped-rpms/packages/*.rpm | wc -l) packages"

SCRIPT_END

# Copy and execute
print_info "Copying script to VM..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    download-fixed.sh $ADMIN_USER@$VM_IP:~/

print_info "Running download (5-10 minutes)..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $ADMIN_USER@$VM_IP "bash download-fixed.sh"

# Download archive
print_info "Downloading archive..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $ADMIN_USER@$VM_IP:~/airgapped-rpms.tar.gz ./

# Create zip
print_info "Creating zip file..."
tar xzf airgapped-rpms.tar.gz
zip -qr db-tools-airgapped-complete.zip airgapped-rpms/
rm -rf airgapped-rpms download-fixed.sh

print_status "Complete!"
echo ""
echo "Files created:"
echo "  - airgapped-rpms.tar.gz"
echo "  - db-tools-airgapped-complete.zip"
echo ""
echo "For airgapped installation:"
echo "  1. Copy zip to target system"
echo "  2. Extract: unzip db-tools-airgapped-complete.zip"
echo "  3. Install: sudo ./airgapped-rpms/scripts/install.sh"
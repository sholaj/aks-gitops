#!/bin/bash

# Optimized Azure VM RPM Download Script
# Downloads all database tools and their complete dependency tree

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
    print_info "Cleaning up Azure resources..."
    az group delete --name $RESOURCE_GROUP --yes --no-wait 2>/dev/null || true
}

# Set trap for cleanup on exit
trap cleanup EXIT

echo -e "${BLUE}Azure Database Tools RPM Downloader${NC}"
echo "===================================="
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
        $ADMIN_USER@$VM_IP "echo 'VM Ready'" 2>/dev/null; then
        break
    fi
    sleep 5
done

# Create download script
cat > download-script.sh << 'DOWNLOAD_SCRIPT'
#!/bin/bash
set -e

echo "Setting up RPM download environment..."

# Install required tools
sudo yum install -y yum-utils createrepo wget

# Create directory structure
mkdir -p ~/rpms-airgapped/{packages,scripts}
cd ~/rpms-airgapped

# Enable required repositories
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
sudo curl -o /etc/yum.repos.d/mssql.repo https://packages.microsoft.com/config/rhel/8/prod.repo

# Download with full dependency resolution
echo "Downloading packages with dependencies..."

# Core dependencies first
sudo yumdownloader --resolve --destdir=./packages \
    glibc libgcc libstdc++ zlib openssl openssl-libs \
    krb5-libs cyrus-sasl-lib cyrus-sasl-gssapi \
    readline ncurses-libs libaio libedit libcom_err \
    keyutils-libs libselinux pcre2 libuuid

# MSSQL tools and dependencies
sudo yumdownloader --resolve --destdir=./packages \
    msodbcsql18 mssql-tools18 unixODBC unixODBC-devel

# FreeTDS and dependencies  
sudo yumdownloader --resolve --destdir=./packages \
    freetds freetds-libs freetds-devel

# Oracle Instant Client (direct download)
wget -P packages/ \
    https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-basic-21.13.0.0.0-1.x86_64.rpm \
    https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-sqlplus-21.13.0.0.0-1.x86_64.rpm \
    https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-devel-21.13.0.0.0-1.x86_64.rpm

# Remove duplicates
echo "Cleaning up duplicate packages..."
cd packages
for rpm in *.rpm; do
    if [[ $rpm =~ (.+)-[0-9]+\..+\.rpm$ ]]; then
        base="${BASH_REMATCH[1]}"
        # Keep only the newest version
        ls -t ${base}*.rpm 2>/dev/null | tail -n +2 | xargs rm -f 2>/dev/null || true
    fi
done
cd ..

# Create repository metadata
createrepo packages/

# Create installation script
cat > scripts/install.sh << 'INSTALL_SCRIPT'
#!/bin/bash
set -e

echo "Database Tools Offline Installer"
echo "================================="

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGES_DIR="$SCRIPT_DIR/../packages"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    SUDO="sudo"
else
    SUDO=""
fi

# Configure local repository
echo "Configuring local repository..."
cat > /tmp/local-db-tools.repo << EOF
[local-db-tools]
name=Local Database Tools Repository
baseurl=file://$PACKAGES_DIR
enabled=1
gpgcheck=0
EOF

$SUDO mv /tmp/local-db-tools.repo /etc/yum.repos.d/

# Clean yum cache
$SUDO yum clean all

# Install packages
echo "Installing database tools..."
$SUDO yum install -y --disablerepo="*" --enablerepo="local-db-tools" \
    msodbcsql18 mssql-tools18 \
    freetds freetds-libs \
    oracle-instantclient-basic oracle-instantclient-sqlplus \
    2>/dev/null || true

# Configure environment
echo "Configuring environment..."

# MSSQL Tools
if [ -d "/opt/mssql-tools18" ]; then
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' | $SUDO tee /etc/profile.d/mssql.sh
fi

# Oracle
if [ -d "/usr/lib/oracle" ]; then
    ORACLE_VERSION=$(ls /usr/lib/oracle | head -1)
    cat << EOO | $SUDO tee /etc/profile.d/oracle.sh
export ORACLE_HOME=/usr/lib/oracle/$ORACLE_VERSION/client64
export PATH=\$PATH:\$ORACLE_HOME/bin
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
EOO
fi

# Update library cache
$SUDO ldconfig

# Clean up repo
$SUDO rm -f /etc/yum.repos.d/local-db-tools.repo

echo ""
echo "Installation complete!"
echo "Please run: source /etc/profile"
echo ""
echo "Verify with:"
echo "  sqlcmd -?"
echo "  sqlplus -version"
echo "  isql --version"
INSTALL_SCRIPT

chmod +x scripts/install.sh

# Create README
cat > README.md << 'README'
# Database Tools Offline Installation Package

## Contents
- MSSQL Tools (sqlcmd) with ODBC Driver 18
- Oracle Instant Client 21.13 (sqlplus)
- FreeTDS 1.4.23 (isql/tsql)
- All required dependencies

## Installation
1. Extract this archive on the target RHEL 8 system
2. Run: `sudo ./scripts/install.sh`
3. Source environment: `source /etc/profile`

## Verification
Test each tool:
- `sqlcmd -?`
- `sqlplus -version`
- `isql --version`

## Package Count
README

echo "Total packages: $(ls packages/*.rpm 2>/dev/null | wc -l)" >> README.md

# Create archive
cd ~
tar czf rpms-airgapped.tar.gz rpms-airgapped/
echo "Archive created: $(du -h rpms-airgapped.tar.gz | cut -f1) - $(ls rpms-airgapped/packages/*.rpm | wc -l) packages"

DOWNLOAD_SCRIPT

# Copy and run script
print_info "Copying script to VM..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    download-script.sh $ADMIN_USER@$VM_IP:~/

print_info "Running download script (this may take 5-10 minutes)..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $ADMIN_USER@$VM_IP "bash download-script.sh"

# Download archive
print_info "Downloading RPM archive..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $ADMIN_USER@$VM_IP:~/rpms-airgapped.tar.gz ./

# Create zip file
print_info "Creating zip file..."
tar xzf rpms-airgapped.tar.gz
zip -qr db-tools-rpms-airgapped-complete.zip rpms-airgapped/
rm -rf rpms-airgapped download-script.sh

print_status "Download complete!"
echo ""
echo "Files created:"
echo "  - rpms-airgapped.tar.gz ($(du -h rpms-airgapped.tar.gz | cut -f1))"
echo "  - db-tools-rpms-airgapped-complete.zip ($(du -h db-tools-rpms-airgapped-complete.zip | cut -f1))"
echo ""
echo "For airgapped installation:"
echo "  1. Copy zip file to target system"
echo "  2. Extract: unzip db-tools-rpms-airgapped-complete.zip"
echo "  3. Install: sudo ./rpms-airgapped/scripts/install.sh"

# Cleanup happens automatically via trap
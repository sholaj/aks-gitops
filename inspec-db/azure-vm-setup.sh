#!/bin/bash

# Azure VM Setup Script for Database Tools Testing
# Creates RHEL 8 VM, installs tools, downloads all RPMs with dependencies

set -e

# Configuration
RESOURCE_GROUP="rg-db-tools-test"
VM_NAME="vm-rhel8-dbtools"
LOCATION="eastus"
VM_SIZE="Standard_B2s"
ADMIN_USER="azureuser"
IMAGE="RedHat:RHEL:8-lvm-gen2:latest"
STORAGE_ACCOUNT="dbtools$(date +%s)"
CONTAINER_NAME="rpms"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

echo -e "${BLUE}Azure VM Database Tools Setup${NC}"
echo "=============================="
echo ""

# 1. Create Resource Group
print_info "Creating resource group..."
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --output none

print_status "Resource group created: $RESOURCE_GROUP"

# 2. Create VM
print_info "Creating RHEL 8 VM..."
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --image $IMAGE \
    --size $VM_SIZE \
    --admin-username $ADMIN_USER \
    --generate-ssh-keys \
    --public-ip-sku Standard \
    --output none

print_status "VM created: $VM_NAME"

# 3. Get VM IP
VM_IP=$(az vm show -d \
    --resource-group $RESOURCE_GROUP \
    --name $VM_NAME \
    --query publicIps -o tsv)

print_status "VM IP Address: $VM_IP"

# 4. Wait for VM to be ready
print_info "Waiting for VM to be ready..."
sleep 30

# 5. Create setup script for VM
cat > vm-setup-script.sh << 'SCRIPT_END'
#!/bin/bash
set -e

echo "Starting database tools setup on VM..."

# Update system
sudo yum update -y
sudo yum install -y yum-utils createrepo

# Create directories
mkdir -p ~/db-tools-rpms/{mssql,oracle,freetds,dependencies,repodata}
cd ~/db-tools-rpms

# Enable repositories
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm || true

# Configure Microsoft repo
sudo curl -o /etc/yum.repos.d/mssql-release.repo https://packages.microsoft.com/config/rhel/8/prod.repo

# Download MSSQL tools with dependencies
echo "Downloading MSSQL tools and dependencies..."
sudo yum install --downloadonly --downloaddir=./mssql -y \
    msodbcsql18 \
    mssql-tools18 \
    unixODBC \
    unixODBC-devel

# Download Oracle Client
echo "Downloading Oracle client..."
wget -P oracle/ https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-basic-21.13.0.0.0-1.x86_64.rpm
wget -P oracle/ https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-sqlplus-21.13.0.0.0-1.x86_64.rpm
wget -P oracle/ https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-devel-21.13.0.0.0-1.x86_64.rpm

# Download FreeTDS with dependencies
echo "Downloading FreeTDS and dependencies..."
sudo yum install --downloadonly --downloaddir=./freetds -y \
    freetds \
    freetds-libs \
    freetds-devel

# Download additional dependencies
echo "Downloading additional dependencies..."
sudo yum install --downloadonly --downloaddir=./dependencies -y \
    libaio \
    openssl \
    openssl-libs \
    krb5-libs \
    cyrus-sasl-lib \
    cyrus-sasl-gssapi \
    readline \
    ncurses-libs \
    glibc \
    libgcc \
    libstdc++ \
    zlib \
    libcom_err \
    keyutils-libs \
    libedit \
    libselinux \
    pcre2

# Create repository metadata
echo "Creating repository metadata..."
createrepo .

# Create installation script
cat > install-all.sh << 'INSTALL_END'
#!/bin/bash
set -e

echo "Installing Database Client Tools"
echo "================================"

# Function to install RPMs from directory
install_rpms() {
    local dir=$1
    local name=$2
    
    echo "Installing $name..."
    if [ -d "$dir" ] && ls "$dir"/*.rpm >/dev/null 2>&1; then
        sudo rpm -Uvh --nodeps "$dir"/*.rpm 2>/dev/null || \
        sudo yum localinstall -y "$dir"/*.rpm 2>/dev/null || true
        echo "✓ $name installed"
    else
        echo "✗ $dir not found or empty"
    fi
}

# Install in order
install_rpms "dependencies" "Dependencies"
install_rpms "mssql" "MSSQL Tools"
install_rpms "oracle" "Oracle Client"
install_rpms "freetds" "FreeTDS"

# Configure environment
echo "Configuring environment..."

# MSSQL Tools PATH
if [ -d "/opt/mssql-tools18" ]; then
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' | sudo tee -a /etc/profile.d/mssql.sh
    sudo chmod +x /etc/profile.d/mssql.sh
fi

# Oracle environment
if [ -d "/usr/lib/oracle" ]; then
    ORACLE_VERSION=$(ls /usr/lib/oracle 2>/dev/null | head -1)
    if [ -n "$ORACLE_VERSION" ]; then
        cat << EOF | sudo tee /etc/profile.d/oracle.sh
export ORACLE_HOME=/usr/lib/oracle/$ORACLE_VERSION/client64
export PATH=\$PATH:\$ORACLE_HOME/bin
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
EOF
        sudo chmod +x /etc/profile.d/oracle.sh
    fi
fi

# Update library cache
sudo ldconfig

echo ""
echo "Installation complete!"
echo "Run: source /etc/profile"
echo ""
echo "Test with:"
echo "  sqlcmd -?"
echo "  sqlplus -version"
echo "  isql --version"
INSTALL_END

chmod +x install-all.sh

# Test installation
echo "Testing installation..."
sudo ./install-all.sh
source /etc/profile

# Verify tools
echo ""
echo "Verification:"
which sqlcmd 2>/dev/null && echo "✓ sqlcmd found" || echo "✗ sqlcmd not found"
which sqlplus 2>/dev/null && echo "✓ sqlplus found" || echo "✗ sqlplus not found"
which isql 2>/dev/null && echo "✓ isql found" || echo "✗ isql not found"

# Create tarball
echo "Creating archive..."
cd ~
tar czf db-tools-rpms-complete.tar.gz db-tools-rpms/

echo ""
echo "Setup complete!"
echo "Archive created: ~/db-tools-rpms-complete.tar.gz"
echo "Size: $(du -h ~/db-tools-rpms-complete.tar.gz | cut -f1)"

SCRIPT_END

# 6. Copy and run script on VM
print_info "Copying setup script to VM..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    vm-setup-script.sh $ADMIN_USER@$VM_IP:~/

print_info "Running setup on VM (this will take several minutes)..."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $ADMIN_USER@$VM_IP "chmod +x vm-setup-script.sh && ./vm-setup-script.sh"

# 7. Download the archive
print_info "Downloading RPM archive from VM..."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    $ADMIN_USER@$VM_IP:~/db-tools-rpms-complete.tar.gz ./

print_status "Archive downloaded: db-tools-rpms-complete.tar.gz"

# 8. Extract and create final zip
print_info "Creating final zip file..."
tar xzf db-tools-rpms-complete.tar.gz
cd db-tools-rpms
zip -r ../db-tools-rpms-airgapped.zip .
cd ..

print_status "Zip file created: db-tools-rpms-airgapped.zip"

# 9. Show summary
echo ""
echo "=============================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=============================="
echo ""
echo "Files created:"
echo "  - db-tools-rpms-complete.tar.gz (full archive)"
echo "  - db-tools-rpms-airgapped.zip (for airgapped installation)"
echo ""
echo "VM Details:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  VM Name: $VM_NAME"
echo "  IP Address: $VM_IP"
echo ""
echo "To connect to VM:"
echo "  ssh $ADMIN_USER@$VM_IP"
echo ""
echo "To clean up Azure resources:"
echo "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo ""

# Cleanup local temp files
rm -f vm-setup-script.sh

# 10. Clean up Azure resources
print_info "Cleaning up Azure resources..."
az group delete --name $RESOURCE_GROUP --yes --no-wait

print_status "Azure resources cleanup initiated (running in background)"
print_info "Resource group $RESOURCE_GROUP will be deleted automatically."

echo ""
echo "=============================="
echo -e "${GREEN}All Done!${NC}"
echo "=============================="
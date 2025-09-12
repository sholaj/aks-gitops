# RHEL 8.10 VM Setup Guide for Database Connectivity Testing

## Prerequisites
- Virtualization software (VMware, VirtualBox, KVM/QEMU, or Hyper-V)
- RHEL 8.10 ISO image
- Minimum 4GB RAM allocated to VM
- 20GB+ disk space
- Network connectivity for initial setup

## 1. Obtaining RHEL 8.10 ISO

### Option A: Red Hat Developer Account (Free)
1. Register at https://developers.redhat.com/register
2. Download RHEL 8.10 from https://developers.redhat.com/products/rhel/download
3. Select "Red Hat Enterprise Linux 8.10 Binary DVD"

### Option B: Evaluation
1. Visit https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux/try-it
2. Request 60-day evaluation
3. Download RHEL 8.10 ISO

### Option C: CentOS Stream 8 (Alternative)
If RHEL licensing is a concern, use CentOS Stream 8 as it's binary compatible:
```bash
wget http://mirror.centos.org/centos/8-stream/isos/x86_64/CentOS-Stream-8-x86_64-latest-dvd1.iso
```

## 2. VM Creation

### VirtualBox Setup
```bash
# Create VM
VBoxManage createvm --name "RHEL8-DB-Test" --ostype "RedHat_64" --register

# Configure VM
VBoxManage modifyvm "RHEL8-DB-Test" \
  --memory 4096 \
  --cpus 2 \
  --vram 128 \
  --nic1 nat \
  --natpf1 "ssh,tcp,,2222,,22"

# Create disk
VBoxManage createhd --filename "$HOME/VirtualBox VMs/RHEL8-DB-Test/disk.vdi" --size 20480

# Attach storage
VBoxManage storagectl "RHEL8-DB-Test" --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach "RHEL8-DB-Test" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$HOME/VirtualBox VMs/RHEL8-DB-Test/disk.vdi"

# Attach ISO
VBoxManage storageattach "RHEL8-DB-Test" --storagectl "SATA" --port 1 --device 0 --type dvddrive --medium /path/to/rhel-8.10-x86_64-dvd.iso

# Start VM
VBoxManage startvm "RHEL8-DB-Test"
```

### VMware Workstation/Fusion
1. File → New Virtual Machine
2. Select "Custom" configuration
3. Choose "Red Hat Enterprise Linux 8 64-bit"
4. Allocate 4GB RAM, 2 CPUs
5. Create 20GB disk
6. Mount RHEL 8.10 ISO
7. Power on VM

### KVM/QEMU with virt-manager
```bash
# Install virt-manager (on host)
sudo yum install virt-manager qemu-kvm libvirt

# Create VM via CLI
virt-install \
  --name rhel8-db-test \
  --ram 4096 \
  --vcpus 2 \
  --disk size=20 \
  --os-variant rhel8.10 \
  --cdrom /path/to/rhel-8.10-x86_64-dvd.iso \
  --network network=default \
  --graphics vnc \
  --noautoconsole
```

## 3. RHEL 8.10 Installation

### Installation Steps
1. Boot from ISO
2. Select "Install Red Hat Enterprise Linux 8.10"
3. Language: English
4. Installation Summary:
   - **Software Selection**: "Server with GUI" or "Server" 
   - **Installation Destination**: Use automatic partitioning
   - **Network & Hostname**: 
     - Enable network adapter
     - Set hostname: `rhel8-db-test.local`
   - **Root Password**: Set strong password
   - **User Creation**: Create admin user with sudo privileges

5. Begin Installation
6. Reboot when complete

## 4. Post-Installation Configuration

### Initial System Setup
```bash
# Login as root or your admin user
# If using developer subscription, register system
sudo subscription-manager register --username=<your-rh-username>
sudo subscription-manager attach --auto

# Update system
sudo yum update -y

# Install essential tools
sudo yum install -y \
  wget \
  curl \
  vim \
  git \
  net-tools \
  bind-utils \
  telnet \
  nc \
  tcpdump \
  firewalld

# Configure firewall for database ports
sudo firewall-cmd --permanent --add-port=1433/tcp  # MSSQL
sudo firewall-cmd --permanent --add-port=1521/tcp  # Oracle  
sudo firewall-cmd --permanent --add-port=5000/tcp  # Sybase
sudo firewall-cmd --reload

# Disable SELinux for testing (re-enable in production)
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

### Configure Network
```bash
# Set static IP (optional)
sudo nmcli con mod "System eth0" \
  ipv4.addresses "192.168.1.100/24" \
  ipv4.gateway "192.168.1.1" \
  ipv4.dns "8.8.8.8,8.8.4.4" \
  ipv4.method manual

sudo nmcli con up "System eth0"

# Verify network
ip addr show
ping -c 3 google.com
```

## 5. Database Client Installation

### Download Packages (Internet Connected)
```bash
# Use the download script we created
wget https://raw.githubusercontent.com/your-repo/download-db-clients.sh
chmod +x download-db-clients.sh
sudo ./download-db-clients.sh
```

### Manual Installation for Testing
```bash
# Install MSSQL tools
curl https://packages.microsoft.com/config/rhel/8/prod.repo | sudo tee /etc/yum.repos.d/mssql-release.repo
sudo yum remove unixODBC-utf16 unixODBC-utf16-devel
sudo ACCEPT_EULA=Y yum install -y msodbcsql18 mssql-tools18 unixODBC-devel

# Install FreeTDS
sudo yum install -y epel-release
sudo yum install -y freetds freetds-devel

# Add to PATH
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
```

## 6. Create Test Database Containers (Optional)

If you want to test against local databases in your VM:

### MSSQL Container
```bash
# Install Docker/Podman
sudo yum install -y podman

# Run MSSQL
sudo podman run -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=YourStrong@Passw0rd" \
  -p 1433:1433 --name mssql \
  -d mcr.microsoft.com/mssql/server:2022-latest

# Test connection
sqlcmd -S localhost -U SA -P 'YourStrong@Passw0rd' -Q "SELECT @@VERSION"
```

### Oracle XE Container
```bash
# Run Oracle XE
sudo podman run -d -p 1521:1521 -e ORACLE_PASSWORD=YourStrong@Passw0rd \
  --name oracle-xe \
  container-registry.oracle.com/database/express:21.3.0-xe

# Wait for initialization (check logs)
sudo podman logs -f oracle-xe

# Test connection (after ~2 minutes)
sqlplus system/YourStrong@Passw0rd@//localhost:1521/XE
```

## 7. VM Snapshot Management

### Create Snapshots
Before testing, create snapshots for easy rollback:

```bash
# VirtualBox
VBoxManage snapshot "RHEL8-DB-Test" take "clean-install"
VBoxManage snapshot "RHEL8-DB-Test" take "db-tools-installed"

# VMware
vmrun snapshot /path/to/vm.vmx "clean-install"

# KVM/QEMU
virsh snapshot-create-as rhel8-db-test --name "clean-install"
```

## 8. Simulating Airgapped Environment

### Disable Network (Airgap Simulation)
```bash
# Disable all network interfaces
sudo nmcli networking off

# Or disable specific interface
sudo ifconfig eth0 down

# Verify no connectivity
ping -c 1 google.com  # Should fail
```

### Test Offline Installation
```bash
# With network disabled, test package installation
cd /path/to/downloaded/packages
sudo rpm -ivh *.rpm

# Verify tools work offline
sqlcmd -?
isql --version
```

## 9. Automation Scripts

### VM Setup Automation
Create `setup-vm.sh`:
```bash
#!/bin/bash

# Automated VM Setup Script
set -e

echo "Starting RHEL 8.10 VM Configuration..."

# Update system
sudo yum update -y

# Install required packages
sudo yum install -y \
  wget curl vim git \
  net-tools bind-utils \
  podman firewalld

# Configure firewall
for port in 1433 1521 5000; do
  sudo firewall-cmd --permanent --add-port=${port}/tcp
done
sudo firewall-cmd --reload

# Download database client packages
wget -O download-db-clients.sh \
  https://your-repo/download-db-clients.sh
chmod +x download-db-clients.sh
./download-db-clients.sh

# Install packages
cd db-client-packages-*
./install-all.sh

# Verify installation
./verify-installation.sh

echo "VM Setup Complete!"
```

## 10. Testing Checklist

### Pre-Deployment Testing
- [ ] VM created with RHEL 8.10
- [ ] Network connectivity verified
- [ ] Database client tools downloaded
- [ ] Packages transferred to VM
- [ ] Network disabled (airgap simulation)
- [ ] Offline installation successful
- [ ] sqlcmd available and working
- [ ] isql available and working  
- [ ] sqlplus available and working (if Oracle needed)
- [ ] Test connections to sample databases
- [ ] Document package versions
- [ ] Create VM snapshot for rollback

### Connection Testing
```bash
# Create test script
cat > test-all-db.sh << 'EOF'
#!/bin/bash

echo "Testing Database Connectivity..."

# Test MSSQL
echo -n "MSSQL: "
sqlcmd -S testserver,1433 -U testuser -P testpass -Q "SELECT 1" &>/dev/null && echo "OK" || echo "FAILED"

# Test Oracle  
echo -n "Oracle: "
echo "SELECT 1 FROM DUAL;" | sqlplus -S test/test@//testserver:1521/XE &>/dev/null && echo "OK" || echo "FAILED"

# Test Sybase
echo -n "Sybase: "
echo "SELECT 1" | isql -S testserver -U testuser -P testpass &>/dev/null && echo "OK" || echo "FAILED"
EOF

chmod +x test-all-db.sh
```

## 11. Troubleshooting

### Common Issues

#### Issue: Subscription Manager Not Working
```bash
# For developer account
sudo subscription-manager clean
sudo subscription-manager register --username=<username> --password=<password>
sudo subscription-manager attach --auto
```

#### Issue: Network Not Working in VM
```bash
# Check network adapter
ip link show
sudo dhclient eth0
sudo systemctl restart NetworkManager
```

#### Issue: Package Dependencies Missing
```bash
# Force install ignoring dependencies
sudo rpm -ivh --nodeps package.rpm

# Or use yum localinstall
sudo yum localinstall *.rpm
```

#### Issue: Permission Denied
```bash
# Check SELinux
getenforce
sudo setenforce 0  # Temporary disable

# Check file permissions
ls -la /opt/mssql-tools18/bin/sqlcmd
sudo chmod +x /opt/mssql-tools18/bin/sqlcmd
```

## 12. Final Notes

### Security Considerations
- Re-enable SELinux after testing
- Use strong passwords for database connections
- Limit network access via firewall rules
- Regular security updates

### Documentation
Document the following for production:
- Exact package versions installed
- Network requirements
- Firewall rules needed
- Authentication methods used
- Connection strings for each database type

### Backup Strategy
- Export VM regularly
- Keep package repository mirror
- Document configuration changes
- Maintain installation scripts
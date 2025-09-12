#!/bin/bash

# Ansible Binary Download Script for RHEL 8.10
# Downloads Ansible and dependencies for airgapped installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOWNLOAD_DIR="ansible-binaries-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="ansible-download.log"

# Create download directory
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

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
echo "Ansible Binary Download Script"
echo "For RHEL 8.10 / CentOS 8 / Rocky Linux 8"
echo "============================================"
echo ""

# 1. Download EPEL Release (required for Ansible)
print_info "Downloading EPEL repository package..."
mkdir -p epel

if download_file \
    "https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm" \
    "epel/epel-release-latest-8.noarch.rpm"; then
    print_status "EPEL release package downloaded"
else
    print_error "Failed to download EPEL release"
fi

# 2. Download Ansible Core
print_info "Downloading Ansible packages..."
mkdir -p ansible

# Ansible package (core is now bundled - UPDATED VERSION)
if download_file \
    "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/a/ansible-9.2.0-1.el8.noarch.rpm" \
    "ansible/ansible-9.2.0-1.el8.noarch.rpm"; then
    print_status "Ansible package downloaded"
else
    print_error "Failed to download Ansible package"
fi

# 3. Download Python dependencies
print_info "Downloading Python dependencies for Ansible..."
mkdir -p python-deps

# Python3 PyYAML (from Rocky Linux)
if download_file \
    "https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/Packages/p/python3-pyyaml-3.12-12.el8.x86_64.rpm" \
    "python-deps/python3-pyyaml-3.12-12.el8.x86_64.rpm"; then
    print_status "PyYAML downloaded"
else
    print_error "Failed to download PyYAML"
fi

# Python3 Jinja2
if download_file \
    "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/python3-jinja2-2.10.1-3.el8.noarch.rpm" \
    "python-deps/python3-jinja2-2.10.1-3.el8.noarch.rpm"; then
    print_status "Jinja2 downloaded"
else
    print_error "Failed to download Jinja2"
fi

# Python3 MarkupSafe
if download_file \
    "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/python3-markupsafe-0.23-19.el8.x86_64.rpm" \
    "python-deps/python3-markupsafe-0.23-19.el8.x86_64.rpm"; then
    print_status "MarkupSafe downloaded"
else
    print_error "Failed to download MarkupSafe"
fi

# Python3 cryptography
if download_file \
    "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/python3-cryptography-3.2.1-5.el8.x86_64.rpm" \
    "python-deps/python3-cryptography-3.2.1-5.el8.x86_64.rpm"; then
    print_status "Cryptography downloaded"
else
    print_error "Failed to download Cryptography"
fi

# Python3 packaging
if download_file \
    "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/p/python3-packaging-20.4-1.el8.noarch.rpm" \
    "python-deps/python3-packaging-20.4-1.el8.noarch.rpm"; then
    print_status "Packaging downloaded"
else
    print_error "Failed to download Packaging"
fi

# Python3 resolvelib
if download_file \
    "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/p/python3-resolvelib-0.5.4-5.el8.noarch.rpm" \
    "python-deps/python3-resolvelib-0.5.4-5.el8.noarch.rpm"; then
    print_status "Resolvelib downloaded"
else
    print_error "Failed to download Resolvelib"
fi

# 4. Download additional Ansible modules
print_info "Downloading additional Ansible collections..."
mkdir -p collections

# Ansible POSIX collection
if download_file \
    "https://galaxy.ansible.com/download/ansible-posix-1.5.4.tar.gz" \
    "collections/ansible-posix-1.5.4.tar.gz"; then
    print_status "Ansible POSIX collection downloaded"
else
    print_error "Failed to download POSIX collection"
fi

# Ansible Windows collection (for mixed environments)
if download_file \
    "https://galaxy.ansible.com/download/ansible-windows-2.2.0.tar.gz" \
    "collections/ansible-windows-2.2.0.tar.gz"; then
    print_status "Ansible Windows collection downloaded"
else
    print_error "Failed to download Windows collection"
fi

# Community General collection
if download_file \
    "https://galaxy.ansible.com/download/community-general-8.2.0.tar.gz" \
    "collections/community-general-8.2.0.tar.gz"; then
    print_status "Community General collection downloaded"
else
    print_error "Failed to download Community General collection"
fi

# 5. Download SSH client dependencies
print_info "Downloading SSH dependencies..."
mkdir -p ssh-deps

# OpenSSH clients
if download_file \
    "http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/openssh-clients-8.0p1-13.el8.x86_64.rpm" \
    "ssh-deps/openssh-clients-8.0p1-13.el8.x86_64.rpm"; then
    print_status "OpenSSH clients downloaded"
else
    print_error "Failed to download OpenSSH clients"
fi

# sshpass for password authentication
if download_file \
    "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/sshpass-1.09-4.el8.x86_64.rpm" \
    "ssh-deps/sshpass-1.09-4.el8.x86_64.rpm"; then
    print_status "sshpass downloaded"
else
    print_error "Failed to download sshpass"
fi

# 6. Create installation script
print_info "Creating installation script..."
cat > install-ansible.sh << 'INSTALL_SCRIPT'
#!/bin/bash

# Ansible Installation Script for RHEL 8.10
set -e

echo "Installing Ansible and dependencies..."

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
install_rpm_dir "epel"
install_rpm_dir "python-deps"
install_rpm_dir "ssh-deps"
install_rpm_dir "ansible"

# Install Ansible collections
if [ -d "collections" ] && ls collections/*.tar.gz >/dev/null 2>&1; then
    echo "Installing Ansible collections..."
    mkdir -p ~/.ansible/collections
    for collection in collections/*.tar.gz; do
        ansible-galaxy collection install "$collection" -p ~/.ansible/collections/ 2>/dev/null || true
    done
fi

# Verify installation
echo ""
echo "Verifying Ansible installation..."
if command -v ansible &> /dev/null; then
    echo "✓ Ansible installed successfully!"
    ansible --version
else
    echo "✗ Ansible installation failed"
    exit 1
fi

# Create sample inventory
mkdir -p ~/ansible
cat > ~/ansible/inventory.ini << 'EOF'
[local]
localhost ansible_connection=local

[database_servers]
# db1.example.com ansible_host=192.168.1.10
# db2.example.com ansible_host=192.168.1.11

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

# Create sample playbook for database connectivity testing
cat > ~/ansible/test-db-connectivity.yml << 'EOF'
---
- name: Test Database Connectivity
  hosts: database_servers
  gather_facts: yes
  tasks:
    - name: Check if sqlcmd is installed
      command: which sqlcmd
      register: sqlcmd_check
      ignore_errors: yes
      
    - name: Check if sqlplus is installed
      command: which sqlplus
      register: sqlplus_check
      ignore_errors: yes
      
    - name: Check if isql is installed
      command: which isql
      register: isql_check
      ignore_errors: yes
      
    - name: Display results
      debug:
        msg:
          - "MSSQL sqlcmd: {{ 'Installed' if sqlcmd_check.rc == 0 else 'Not found' }}"
          - "Oracle sqlplus: {{ 'Installed' if sqlplus_check.rc == 0 else 'Not found' }}"
          - "FreeTDS isql: {{ 'Installed' if isql_check.rc == 0 else 'Not found' }}"
EOF

echo ""
echo "Installation complete!"
echo ""
echo "Ansible configuration:"
echo "  - Version: $(ansible --version | head -1)"
echo "  - Config: /etc/ansible/ansible.cfg"
echo "  - Inventory: ~/ansible/inventory.ini"
echo "  - Sample playbook: ~/ansible/test-db-connectivity.yml"
echo ""
echo "To test: ansible-playbook ~/ansible/test-db-connectivity.yml -i ~/ansible/inventory.ini"
INSTALL_SCRIPT
chmod +x install-ansible.sh

# 7. Create Ansible playbook for database client installation
cat > install-db-clients.yml << 'PLAYBOOK'
---
- name: Install Database Client Tools
  hosts: all
  become: yes
  vars:
    db_clients_path: /opt/db-clients
    
  tasks:
    - name: Create directory for database clients
      file:
        path: "{{ db_clients_path }}"
        state: directory
        mode: '0755'
        
    - name: Copy database client packages
      copy:
        src: "{{ item }}"
        dest: "{{ db_clients_path }}/"
      with_fileglob:
        - "../db-binaries-*/mssql/*.rpm"
        - "../db-binaries-*/oracle/*.rpm"
        - "../db-binaries-*/freetds/*.rpm"
        - "../db-binaries-*/dependencies/*.rpm"
        
    - name: Install MSSQL client packages
      yum:
        name: "{{ db_clients_path }}/mssql*.rpm"
        state: present
        disable_gpg_check: yes
      environment:
        ACCEPT_EULA: "Y"
        
    - name: Install Oracle client packages
      yum:
        name: "{{ db_clients_path }}/oracle*.rpm"
        state: present
        disable_gpg_check: yes
        
    - name: Install FreeTDS packages
      yum:
        name: "{{ db_clients_path }}/freetds*.rpm"
        state: present
        disable_gpg_check: yes
        
    - name: Configure MSSQL tools path
      lineinfile:
        path: /etc/profile.d/mssql.sh
        line: 'export PATH="$PATH:/opt/mssql-tools18/bin"'
        create: yes
        mode: '0644'
        
    - name: Configure Oracle environment
      blockinfile:
        path: /etc/profile.d/oracle.sh
        create: yes
        mode: '0644'
        block: |
          export ORACLE_HOME=/usr/lib/oracle/21/client64
          export PATH=$PATH:$ORACLE_HOME/bin
          export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
          
    - name: Update library cache
      command: ldconfig
      
    - name: Verify installations
      command: "{{ item }}"
      register: verify_results
      ignore_errors: yes
      with_items:
        - sqlcmd -?
        - sqlplus -version
        - isql --version
        
    - name: Display verification results
      debug:
        var: verify_results
PLAYBOOK

# 8. Create README
cat > README.md << 'README'
# Ansible Binary Package for RHEL 8.10

## Contents

- `epel/` - EPEL repository package
- `ansible/` - Ansible core and meta packages
- `python-deps/` - Python dependencies for Ansible
- `ssh-deps/` - SSH client dependencies
- `collections/` - Ansible Galaxy collections
- `install-ansible.sh` - Installation script
- `install-db-clients.yml` - Playbook to install database clients

## Installation

```bash
# Install Ansible
./install-ansible.sh

# Verify installation
ansible --version

# Test connectivity
ansible all -m ping -i ~/ansible/inventory.ini
```

## Using Ansible to Install Database Clients

1. First, ensure database client packages are downloaded:
   ```bash
   ../download-binaries.sh
   ```

2. Update inventory file with target hosts:
   ```bash
   vim ~/ansible/inventory.ini
   ```

3. Run the playbook to install database clients:
   ```bash
   ansible-playbook install-db-clients.yml -i ~/ansible/inventory.ini
   ```

## Ansible Commands

### Basic Commands
```bash
# Check connectivity
ansible all -m ping -i inventory.ini

# Run ad-hoc commands
ansible all -m shell -a "sqlcmd -?" -i inventory.ini

# Get system facts
ansible all -m setup -i inventory.ini
```

### Playbook Execution
```bash
# Run playbook
ansible-playbook playbook.yml -i inventory.ini

# Run with verbose output
ansible-playbook playbook.yml -i inventory.ini -vvv

# Check mode (dry run)
ansible-playbook playbook.yml -i inventory.ini --check

# Limit to specific hosts
ansible-playbook playbook.yml -i inventory.ini --limit database_servers
```

## Configuration

### Ansible Configuration File
Create `/etc/ansible/ansible.cfg` or `~/.ansible.cfg`:
```ini
[defaults]
host_key_checking = False
inventory = ~/ansible/inventory.ini
remote_user = ansible
private_key_file = ~/.ssh/id_rsa
interpreter_python = /usr/bin/python3

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

### Inventory Example
```ini
[database_servers]
mssql-server ansible_host=192.168.1.10 ansible_user=admin
oracle-server ansible_host=192.168.1.11 ansible_user=oracle
sybase-server ansible_host=192.168.1.12 ansible_port=2222

[database_servers:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

## Ansible Collections Included

- `ansible-posix` - POSIX system management
- `ansible-windows` - Windows system management
- `community-general` - General community modules

## Troubleshooting

### Python Issues
```bash
# Ensure Python 3 is default
alternatives --set python /usr/bin/python3

# Install missing Python modules
pip3 install pyyaml jinja2 cryptography
```

### SSH Issues
```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096

# Copy key to remote hosts
ssh-copy-id user@hostname

# Test SSH connection
ssh -o StrictHostKeyChecking=no user@hostname
```

### Permission Issues
```bash
# Add user to sudoers
echo "ansible ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible
```
README

# 9. Create tarball
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
echo "3. Install: cd $DOWNLOAD_DIR && ./install-ansible.sh"
echo "4. Verify: ansible --version"
echo ""
echo "To install database clients with Ansible:"
echo "  ansible-playbook install-db-clients.yml -i inventory.ini"
echo ""
echo "Log file: $DOWNLOAD_DIR/$LOG_FILE"
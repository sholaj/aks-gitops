# Vagrant VM Setup for Database Client Testing

Automated VM setup for testing database connectivity tools on RHEL 8 compatible systems.

## Prerequisites

1. **Install Vagrant**
   ```bash
   # macOS
   brew install vagrant
   
   # Windows (using Chocolatey)
   choco install vagrant
   
   # Linux
   wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install vagrant
   ```

2. **Install VirtualBox** (or VMware/libvirt)
   ```bash
   # macOS
   brew install --cask virtualbox
   
   # Windows
   choco install virtualbox
   
   # Linux
   sudo apt install virtualbox
   ```

## Quick Start

1. **Clone or download this directory**
   ```bash
   cd vagrant-vm-setup
   ```

2. **Start the VM**
   ```bash
   vagrant up
   ```
   This will:
   - Download Rocky Linux 8 base image
   - Create and configure the VM
   - Download all database client binaries
   - Install and configure the tools
   - Run verification tests

3. **Access the VM**
   ```bash
   vagrant ssh
   ```

4. **Test database clients**
   ```bash
   # Inside the VM
   sqlcmd -?
   sqlplus -version
   isql --version
   
   # Run test suite
   cd ~/db-tests
   ./test-connections.sh
   ```

## VM Details

- **OS**: Rocky Linux 8 (RHEL 8 compatible)
- **IP**: 192.168.56.10
- **Memory**: 4GB
- **CPUs**: 2
- **Hostname**: db-test-rhel8

### Port Forwarding
- **1433** → 1433 (MSSQL)
- **1521** → 1521 (Oracle)
- **5000** → 5000 (Sybase)
- **2222** → 22 (SSH)

## Directory Structure

```
vagrant-vm-setup/
├── Vagrantfile          # VM configuration
├── provision.sh         # Automated setup script
├── README.md           # This file
└── .vagrant/           # Vagrant state (auto-created)
```

Inside the VM:
```
/opt/db-clients/        # Downloaded binaries
├── mssql/             # SQL Server tools
├── oracle/            # Oracle Instant Client
├── freetds/           # Sybase/FreeTDS tools
└── dependencies/      # Required libraries

/home/vagrant/db-tests/ # Test scripts
├── test-connections.sh # Verification script
├── connect-mssql.sh   # MSSQL connection test
├── connect-oracle.sh  # Oracle connection test
└── connect-sybase.sh  # Sybase connection test
```

## Vagrant Commands

```bash
# Start VM
vagrant up

# SSH into VM
vagrant ssh

# Stop VM (preserves state)
vagrant halt

# Restart VM
vagrant reload

# Re-run provisioning
vagrant provision

# Destroy VM (removes all data)
vagrant destroy

# Check VM status
vagrant status

# Save VM state
vagrant snapshot save initial-setup

# Restore VM state
vagrant snapshot restore initial-setup
```

## Testing Database Connections

### Test MSSQL Connection
```bash
vagrant ssh
cd ~/db-tests
./connect-mssql.sh
# Enter: server-name,1433
# Enter: username
# Enter: password
```

### Test Oracle Connection
```bash
vagrant ssh
cd ~/db-tests
./connect-oracle.sh
# Enter: username/password@//hostname:1521/SERVICE
```

### Test Sybase Connection
```bash
vagrant ssh
cd ~/db-tests
./connect-sybase.sh
# Enter: server-name
# Enter: 5000
# Enter: username
# Enter: password
```

## Simulating Airgapped Environment

To test offline installation:

```bash
# Inside VM
sudo nmcli networking off  # Disable network

# Test tools still work
sqlcmd -?
sqlplus -version
isql --version

# Re-enable network
sudo nmcli networking on
```

## Customization

### Change Base Box
Edit `Vagrantfile`:
```ruby
# For CentOS 8
config.vm.box = "generic/centos8"

# For AlmaLinux 8
config.vm.box = "generic/alma8"

# For actual RHEL 8 (requires subscription)
config.vm.box = "generic/rhel8"
```

### Adjust Resources
Edit `Vagrantfile`:
```ruby
config.vm.provider "virtualbox" do |vb|
  vb.memory = "8192"  # 8GB RAM
  vb.cpus = 4         # 4 CPUs
end
```

### Add More Tools
Edit `provision.sh` to add additional downloads or configurations.

## Troubleshooting

### Issue: VM won't start
```bash
# Check VirtualBox is running
VBoxManage --version

# Check for conflicting VMs
VBoxManage list vms

# Reset Vagrant
vagrant destroy -f
vagrant up
```

### Issue: Network timeout during provisioning
```bash
# Increase timeout in Vagrantfile
config.vm.boot_timeout = 600

# Or manually provision after VM is up
vagrant up --no-provision
vagrant ssh
sudo /vagrant/provision.sh
```

### Issue: Port already in use
```bash
# Change port in Vagrantfile
config.vm.network "forwarded_port", guest: 1433, host: 11433
```

### Issue: Download failures
```bash
# SSH into VM and run manually
vagrant ssh
sudo su -
cd /opt/db-clients
wget <url>
```

## Export for Airgapped Use

To export the configured VM for use in an airgapped environment:

```bash
# Package the VM
vagrant package --output db-test-vm.box

# On target system
vagrant box add db-test db-test-vm.box
vagrant init db-test
vagrant up
```

## Clean Up

```bash
# Remove VM completely
vagrant destroy -f

# Remove downloaded box
vagrant box remove generic/rocky8

# Clean all Vagrant data
rm -rf .vagrant/
```

## Notes

- First run downloads ~500MB (base box + packages)
- Subsequent runs use cached base box
- VM disk usage: ~2GB after setup
- All tools are installed globally (available to all users)
- Environment variables are set in `/etc/profile.d/`

## Support

For issues or questions:
1. Check VM logs: `vagrant ssh -c "sudo journalctl -xe"`
2. Check provision logs: View output during `vagrant up`
3. Manual provisioning: `vagrant ssh` then run commands from `provision.sh`
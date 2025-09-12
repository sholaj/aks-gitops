#!/bin/bash

# Vagrant Provisioning Script for RHEL 8 Database Client Setup
set -e

echo "=========================================="
echo "Starting VM Provisioning..."
echo "=========================================="

# Update system
echo "Updating system packages..."
sudo yum update -y

# Install basic tools
echo "Installing basic tools..."
sudo yum install -y \
    wget \
    curl \
    vim \
    git \
    net-tools \
    bind-utils \
    nc \
    telnet \
    unzip \
    tar \
    openssl

# Create directory for database clients
sudo mkdir -p /opt/db-clients
cd /opt/db-clients

# Download database client binaries
echo "=========================================="
echo "Downloading Database Client Binaries..."
echo "=========================================="

# Create directory structure
mkdir -p mssql oracle freetds dependencies

# Download Microsoft SQL Server Tools
echo "Downloading MSSQL tools..."
wget -q -P mssql/ https://packages.microsoft.com/rhel/8/prod/msodbcsql18-18.3.3.1-1.x86_64.rpm
wget -q -P mssql/ https://packages.microsoft.com/rhel/8/prod/mssql-tools18-18.3.1.1-1.x86_64.rpm
wget -q -P mssql/ https://packages.microsoft.com/rhel/8/prod/unixODBC-2.3.11-1.rh.x86_64.rpm

# Download Oracle Instant Client
echo "Downloading Oracle client..."
wget -q -P oracle/ https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-basic-21.13.0.0.0-1.x86_64.rpm
wget -q -P oracle/ https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-sqlplus-21.13.0.0.0-1.x86_64.rpm

# Download FreeTDS
echo "Downloading FreeTDS..."
wget -q -P freetds/ https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/f/freetds-1.3.3-1.el8.x86_64.rpm
wget -q -P freetds/ https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/f/freetds-libs-1.3.3-1.el8.x86_64.rpm

# Download dependencies
echo "Downloading dependencies..."
wget -q -P dependencies/ http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/libaio-0.3.112-1.el8.x86_64.rpm

# Install all packages
echo "=========================================="
echo "Installing Database Clients..."
echo "=========================================="

# Install dependencies first
echo "Installing dependencies..."
sudo rpm -ivh --nodeps dependencies/*.rpm 2>/dev/null || true

# Install MSSQL tools
echo "Installing MSSQL tools..."
sudo ACCEPT_EULA=Y rpm -ivh --nodeps mssql/*.rpm 2>/dev/null || true

# Install Oracle client
echo "Installing Oracle client..."
sudo rpm -ivh --nodeps oracle/*.rpm 2>/dev/null || true

# Install FreeTDS
echo "Installing FreeTDS..."
sudo rpm -ivh --nodeps freetds/*.rpm 2>/dev/null || true

# Configure environment variables
echo "Configuring environment..."

# Add MSSQL tools to PATH
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' | sudo tee -a /etc/profile.d/mssql.sh
sudo chmod +x /etc/profile.d/mssql.sh

# Configure Oracle environment
if [ -d "/usr/lib/oracle" ]; then
    ORACLE_VERSION=$(ls /usr/lib/oracle | head -1)
    cat << EOF | sudo tee /etc/profile.d/oracle.sh
export ORACLE_HOME=/usr/lib/oracle/$ORACLE_VERSION/client64
export PATH=\$PATH:\$ORACLE_HOME/bin
export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:\$LD_LIBRARY_PATH
EOF
    sudo chmod +x /etc/profile.d/oracle.sh
fi

# Update library cache
sudo ldconfig

# Configure firewall
echo "Configuring firewall..."
sudo systemctl start firewalld
sudo firewall-cmd --permanent --add-port=1433/tcp  # MSSQL
sudo firewall-cmd --permanent --add-port=1521/tcp  # Oracle
sudo firewall-cmd --permanent --add-port=5000/tcp  # Sybase
sudo firewall-cmd --reload

# Create FreeTDS configuration
echo "Configuring FreeTDS..."
sudo tee /etc/freetds.conf > /dev/null << 'EOF'
[global]
    tds version = auto
    text size = 64512

[SYBASE_TEST]
    host = sybase-server
    port = 5000
    tds version = 5.0

[MSSQL_TEST]
    host = mssql-server
    port = 1433
    tds version = 7.4
EOF

# Create ODBC configuration
echo "Configuring ODBC..."
sudo tee /etc/odbcinst.ini > /dev/null << 'EOF'
[ODBC Driver 18 for SQL Server]
Description=Microsoft ODBC Driver 18 for SQL Server
Driver=/opt/microsoft/msodbcsql18/lib64/libmsodbcsql-18.so
UsageCount=1

[FreeTDS]
Description = FreeTDS unixODBC Driver
Driver = /usr/lib64/libtdsodbc.so.0
Setup = /usr/lib64/libtdsS.so
UsageCount = 1
EOF

# Create test scripts directory
mkdir -p /home/vagrant/db-tests
cd /home/vagrant/db-tests

# Create connection test script
cat > test-connections.sh << 'SCRIPT'
#!/bin/bash

echo "Database Client Test Suite"
echo "=========================="

# Test MSSQL
echo ""
echo "1. Testing MSSQL (sqlcmd)..."
if command -v sqlcmd &> /dev/null; then
    echo "   ✓ sqlcmd installed"
    sqlcmd -? 2>&1 | head -1
else
    echo "   ✗ sqlcmd not found"
fi

# Test Oracle
echo ""
echo "2. Testing Oracle (sqlplus)..."
if command -v sqlplus &> /dev/null; then
    echo "   ✓ sqlplus installed"
    sqlplus -version 2>&1
else
    echo "   ✗ sqlplus not found"
fi

# Test FreeTDS
echo ""
echo "3. Testing FreeTDS (isql/tsql)..."
if command -v isql &> /dev/null; then
    echo "   ✓ isql installed"
    isql --version 2>&1
else
    echo "   ✗ isql not found"
fi

if command -v tsql &> /dev/null; then
    echo "   ✓ tsql installed"
    tsql -C 2>&1 | grep Version
else
    echo "   ✗ tsql not found"
fi

echo ""
echo "4. ODBC Drivers:"
odbcinst -q -d 2>/dev/null || echo "   No ODBC drivers configured"

echo ""
echo "=========================="
echo "Test complete!"
SCRIPT

chmod +x test-connections.sh
chown -R vagrant:vagrant /home/vagrant/db-tests

# Create sample connection scripts
cat > /home/vagrant/db-tests/connect-mssql.sh << 'EOF'
#!/bin/bash
read -p "Enter MSSQL server: " server
read -p "Enter username: " user
read -s -p "Enter password: " pass
echo ""
sqlcmd -S $server -U $user -P $pass -C -Q "SELECT @@VERSION"
EOF

cat > /home/vagrant/db-tests/connect-oracle.sh << 'EOF'
#!/bin/bash
read -p "Enter Oracle connection string (user/pass@//host:port/service): " conn
sqlplus $conn <<< "SELECT * FROM v\$version;"
EOF

cat > /home/vagrant/db-tests/connect-sybase.sh << 'EOF'
#!/bin/bash
read -p "Enter Sybase server: " server
read -p "Enter port (default 5000): " port
port=${port:-5000}
read -p "Enter username: " user
read -s -p "Enter password: " pass
echo ""
tsql -S $server -p $port -U $user -P $pass
EOF

chmod +x /home/vagrant/db-tests/*.sh
chown -R vagrant:vagrant /home/vagrant/db-tests

# Run tests
echo ""
echo "=========================================="
echo "Running Installation Tests..."
echo "=========================================="
source /etc/profile.d/mssql.sh 2>/dev/null || true
source /etc/profile.d/oracle.sh 2>/dev/null || true
/home/vagrant/db-tests/test-connections.sh

echo ""
echo "=========================================="
echo "Provisioning Complete!"
echo "=========================================="
echo ""
echo "Database client tools are installed in:"
echo "  - /opt/db-clients/"
echo ""
echo "Test scripts available in:"
echo "  - /home/vagrant/db-tests/"
echo ""
echo "To test connections:"
echo "  ./db-tests/connect-mssql.sh"
echo "  ./db-tests/connect-oracle.sh"
echo "  ./db-tests/connect-sybase.sh"
echo "=========================================="
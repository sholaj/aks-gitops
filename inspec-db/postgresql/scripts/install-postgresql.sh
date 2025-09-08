#!/bin/bash
# PostgreSQL Installation Script for Ubuntu/CentOS VirtualBox VM

set -e

echo "PostgreSQL Installation Script"
echo "=============================="

# Configuration variables
PG_VERSION=${PG_VERSION:-"14"}
PG_PASSWORD=${PG_PASSWORD:-"P@ssw0rd123"}

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "Cannot detect OS version"
    exit 1
fi

echo "Detected OS: $OS $VERSION"
echo "PostgreSQL Version: $PG_VERSION"

# Install PostgreSQL based on OS
case $OS in
    ubuntu)
        echo "Installing PostgreSQL on Ubuntu..."
        
        # Update package list
        sudo apt-get update
        
        # Install PostgreSQL and additional packages
        sudo apt-get install -y postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION postgresql-client-$PG_VERSION
        
        # Install additional tools
        sudo apt-get install -y postgresql-server-dev-$PG_VERSION
        
        # Start and enable PostgreSQL service
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
        
        # Set postgres user password
        sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$PG_PASSWORD';"
        ;;
        
    centos|rhel)
        echo "Installing PostgreSQL on CentOS/RHEL..."
        
        # Install PostgreSQL repository
        sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$VERSION-x86_64/pgdg-redhat-repo-latest.noarch.rpm
        
        # Install PostgreSQL
        sudo yum install -y postgresql$PG_VERSION-server postgresql$PG_VERSION postgresql$PG_VERSION-contrib
        
        # Initialize database (only for first time)
        if [ ! -f /var/lib/pgsql/$PG_VERSION/data/postgresql.conf ]; then
            sudo /usr/pgsql-$PG_VERSION/bin/postgresql-$PG_VERSION-setup initdb
        fi
        
        # Start and enable PostgreSQL service
        sudo systemctl start postgresql-$PG_VERSION
        sudo systemctl enable postgresql-$PG_VERSION
        
        # Set postgres user password
        sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$PG_PASSWORD';"
        ;;
        
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Configure PostgreSQL for remote connections
echo "Configuring PostgreSQL for remote connections..."

# Find PostgreSQL configuration directory
if [ "$OS" = "ubuntu" ]; then
    PG_CONFIG_DIR="/etc/postgresql/$PG_VERSION/main"
    PG_DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
else
    PG_CONFIG_DIR="/var/lib/pgsql/$PG_VERSION/data"
    PG_DATA_DIR="/var/lib/pgsql/$PG_VERSION/data"
fi

# Configure postgresql.conf
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONFIG_DIR/postgresql.conf

# Configure pg_hba.conf for authentication
sudo cp $PG_CONFIG_DIR/pg_hba.conf $PG_CONFIG_DIR/pg_hba.conf.backup
sudo sed -i "s/#local   replication     postgres                                peer/local   replication     postgres                                md5/" $PG_CONFIG_DIR/pg_hba.conf

# Add entry for test_user connections
echo "# Entry for test_user" | sudo tee -a $PG_CONFIG_DIR/pg_hba.conf
echo "host    all             test_user       127.0.0.1/32            md5" | sudo tee -a $PG_CONFIG_DIR/pg_hba.conf
echo "host    all             test_user       ::1/128                 md5" | sudo tee -a $PG_CONFIG_DIR/pg_hba.conf
echo "host    all             postgres        127.0.0.1/32            md5" | sudo tee -a $PG_CONFIG_DIR/pg_hba.conf
echo "host    all             postgres        ::1/128                 md5" | sudo tee -a $PG_CONFIG_DIR/pg_hba.conf

# Configure SSL (basic self-signed certificate)
echo "Configuring SSL..."
sudo -u postgres openssl req -new -x509 -days 365 -nodes -text -out $PG_DATA_DIR/server.crt -keyout $PG_DATA_DIR/server.key -subj "/CN=localhost"
sudo chmod 600 $PG_DATA_DIR/server.key
sudo chown postgres:postgres $PG_DATA_DIR/server.key $PG_DATA_DIR/server.crt

# Enable SSL in postgresql.conf
sudo sed -i "s/#ssl = off/ssl = on/" $PG_CONFIG_DIR/postgresql.conf

# Restart PostgreSQL to apply configuration changes
if [ "$OS" = "ubuntu" ]; then
    sudo systemctl restart postgresql
else
    sudo systemctl restart postgresql-$PG_VERSION
fi

# Check service status
if [ "$OS" = "ubuntu" ]; then
    sudo systemctl status postgresql --no-pager
else
    sudo systemctl status postgresql-$PG_VERSION --no-pager
fi

# Display connection information
echo ""
echo "PostgreSQL installation completed!"
echo "=================================="
echo "Version: PostgreSQL $PG_VERSION"
echo "Default port: 5432"
echo "Postgres superuser password: $PG_PASSWORD"
echo "Configuration directory: $PG_CONFIG_DIR"
echo "Data directory: $PG_DATA_DIR"
echo "SSL: Enabled with self-signed certificate"
echo ""
echo "Next steps:"
echo "1. Run the database setup script to create test_db and test_user"
echo "2. Test the connection using the provided test script"
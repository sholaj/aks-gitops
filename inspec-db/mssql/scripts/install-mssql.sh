#!/bin/bash
# MS SQL Server Installation Script for Ubuntu/CentOS VirtualBox VM

set -e

echo "MS SQL Server Installation Script"
echo "=================================="

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

# Install MS SQL Server based on OS
case $OS in
    ubuntu)
        echo "Installing MS SQL Server on Ubuntu..."
        
        # Import the public repository GPG keys
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
        
        # Register the Microsoft SQL Server Ubuntu repository
        sudo add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/$VERSION/mssql-server-2022.list)"
        
        # Update package list
        sudo apt-get update
        
        # Install SQL Server
        sudo apt-get install -y mssql-server
        
        # Install SQL Server command-line tools
        curl https://packages.microsoft.com/config/ubuntu/$VERSION/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
        sudo apt-get update
        sudo apt-get install -y mssql-tools unixodbc-dev
        
        # Add tools to PATH
        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
        source ~/.bashrc
        ;;
        
    centos|rhel)
        echo "Installing MS SQL Server on CentOS/RHEL..."
        
        # Download Microsoft SQL Server 2022 Red Hat repository configuration file
        sudo curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/8/mssql-server-2022.repo
        
        # Install SQL Server
        sudo yum install -y mssql-server
        
        # Install SQL Server command-line tools
        sudo curl -o /etc/yum.repos.d/msprod.repo https://packages.microsoft.com/config/rhel/8/prod.repo
        sudo yum install -y mssql-tools unixODBC-devel
        
        # Add tools to PATH
        echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
        source ~/.bashrc
        ;;
        
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

# Configure SQL Server
echo "Configuring MS SQL Server..."
echo "You will be prompted to set the SA password. Use: P@ssw0rd123"
sudo /opt/mssql/bin/mssql-conf setup

# Enable and start SQL Server service
sudo systemctl enable mssql-server
sudo systemctl start mssql-server

# Check service status
sudo systemctl status mssql-server --no-pager

echo "MS SQL Server installation completed!"
echo "Default instance is running on port 1433"
echo "SA password should be set to: P@ssw0rd123"
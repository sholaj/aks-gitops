#!/bin/bash

# On-Premise MS SQL Server Test Setup Script
# This script simulates an on-premise MS SQL Server environment for compliance testing

set -e

echo "=================================================="
echo "On-Premise MS SQL Server Compliance Test Setup"
echo "=================================================="

# Configuration variables
MSSQL_HOST="localhost"
MSSQL_PORT="1433"
MSSQL_SA_PASSWORD="StrongP@ssw0rd2024!"
MSSQL_TEST_USER="test_user"
MSSQL_TEST_PASSWORD="P@ssw0rd"
MSSQL_DATABASE="test_db"

# Check if MS SQL Server is installed
echo "Checking MS SQL Server installation..."
if command -v /opt/mssql-tools/bin/sqlcmd &> /dev/null; then
    echo "✅ MS SQL Server tools found"
else
    echo "❌ MS SQL Server tools not found. Please install MS SQL Server first."
    echo "For Ubuntu/Debian:"
    echo "  curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -"
    echo "  curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y mssql-server mssql-tools"
    exit 1
fi

# Create SQL setup script
cat > /tmp/setup_mssql_test.sql << 'EOF'
-- Create test database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'test_db')
BEGIN
    CREATE DATABASE test_db;
    PRINT 'Database test_db created successfully';
END
ELSE
BEGIN
    PRINT 'Database test_db already exists';
END
GO

USE test_db;
GO

-- Create test user with SQL authentication
IF NOT EXISTS (SELECT name FROM sys.server_principals WHERE name = 'test_user')
BEGIN
    CREATE LOGIN test_user WITH PASSWORD = 'P@ssw0rd';
    PRINT 'Login test_user created successfully';
END
ELSE
BEGIN
    PRINT 'Login test_user already exists';
END
GO

-- Create database user
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'test_user')
BEGIN
    CREATE USER test_user FOR LOGIN test_user;
    PRINT 'Database user test_user created successfully';
END
GO

-- Grant permissions to test_user
ALTER ROLE db_datareader ADD MEMBER test_user;
ALTER ROLE db_datawriter ADD MEMBER test_user;
GRANT VIEW SERVER STATE TO test_user;
GRANT VIEW DATABASE STATE TO test_user;
GRANT VIEW DEFINITION TO test_user;
PRINT 'Permissions granted to test_user';
GO

-- Create sample table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'compliance_test_table')
BEGIN
    CREATE TABLE compliance_test_table (
        id INT PRIMARY KEY IDENTITY(1,1),
        test_data VARCHAR(100),
        created_date DATETIME DEFAULT GETDATE()
    );
    PRINT 'Table compliance_test_table created';
END
GO

-- Insert sample data
IF NOT EXISTS (SELECT * FROM compliance_test_table)
BEGIN
    INSERT INTO compliance_test_table (test_data) VALUES 
    ('Test Record 1'),
    ('Test Record 2'),
    ('Test Record 3');
    PRINT 'Sample data inserted';
END
GO

-- Check SSL/TLS configuration
SELECT 
    CASE 
        WHEN value_in_use = 1 THEN 'ENABLED'
        ELSE 'DISABLED'
    END AS 'Force Encryption Status'
FROM sys.configurations 
WHERE name = 'ForceEncryption';
GO

-- Display current security settings
PRINT '';
PRINT '=== Current Security Configuration ===';
SELECT 
    name AS 'Configuration',
    CAST(value_in_use AS VARCHAR(10)) AS 'Value'
FROM sys.configurations
WHERE name IN ('remote access', 'clr enabled', 'xp_cmdshell')
ORDER BY name;
GO

-- Check authentication mode
EXEC xp_loginconfig 'login mode';
GO

PRINT '';
PRINT 'Setup completed successfully!';
EOF

echo "Setting up MS SQL Server test environment..."

# Try to connect and run setup
if [ -z "$1" ]; then
    echo "Please provide SA password as argument: ./setup-mssql-test.sh 'YourSAPassword'"
    echo "Using default password for testing..."
    SA_PASSWORD="$MSSQL_SA_PASSWORD"
else
    SA_PASSWORD="$1"
fi

echo "Attempting to connect to MS SQL Server..."
/opt/mssql-tools/bin/sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U sa -P "$SA_PASSWORD" -i /tmp/setup_mssql_test.sql

if [ $? -eq 0 ]; then
    echo "✅ MS SQL Server setup completed successfully!"
    
    # Test the connection with test_user
    echo ""
    echo "Testing connection with test_user..."
    /opt/mssql-tools/bin/sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_TEST_USER -P "$MSSQL_TEST_PASSWORD" -d $MSSQL_DATABASE -Q "SELECT 'Connection successful' AS Status, COUNT(*) AS RecordCount FROM compliance_test_table;" -h -1
    
    if [ $? -eq 0 ]; then
        echo "✅ Test user connection verified!"
    else
        echo "❌ Test user connection failed"
    fi
else
    echo "❌ MS SQL Server setup failed. Please check your SA password and server configuration."
    exit 1
fi

echo ""
echo "=================================================="
echo "Setup Summary:"
echo "  Server: $MSSQL_HOST:$MSSQL_PORT"
echo "  Database: $MSSQL_DATABASE"
echo "  Test User: $MSSQL_TEST_USER"
echo "  Password: $MSSQL_TEST_PASSWORD"
echo "=================================================="
echo ""
echo "Ready for InSpec compliance scanning!"
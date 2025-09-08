#!/bin/bash
# MS SQL Server Connection Test Script

set -e

# Configuration
MSSQL_HOST=${MSSQL_HOST:-"localhost"}
MSSQL_PORT=${MSSQL_PORT:-"1433"}
MSSQL_USER=${MSSQL_USER:-"test_user"}
MSSQL_PASSWORD=${MSSQL_PASSWORD:-"P@ssw0rd"}
MSSQL_DATABASE=${MSSQL_DATABASE:-"test_db"}

echo "MS SQL Server Connection Test"
echo "============================="
echo "Host: $MSSQL_HOST"
echo "Port: $MSSQL_PORT"
echo "Database: $MSSQL_DATABASE"
echo "User: $MSSQL_USER"
echo ""

# Test 1: Network connectivity using telnet
echo "1. Testing network connectivity to MS SQL Server port..."
if command -v telnet >/dev/null 2>&1; then
    timeout 5 telnet $MSSQL_HOST $MSSQL_PORT && echo "✓ Port $MSSQL_PORT is reachable" || echo "✗ Port $MSSQL_PORT is not reachable"
else
    echo "Telnet not available, using nc (netcat)..."
    if command -v nc >/dev/null 2>&1; then
        nc -z -v -w5 $MSSQL_HOST $MSSQL_PORT && echo "✓ Port $MSSQL_PORT is reachable" || echo "✗ Port $MSSQL_PORT is not reachable"
    else
        echo "Neither telnet nor nc available, skipping port test"
    fi
fi
echo ""

# Test 2: SQL Server service status (if running locally)
echo "2. Checking SQL Server service status..."
if systemctl is-active --quiet mssql-server 2>/dev/null; then
    echo "✓ MS SQL Server service is running"
else
    echo "⚠ Cannot determine service status or service not running locally"
fi
echo ""

# Test 3: sqlcmd connection test
echo "3. Testing SQL Server connection with sqlcmd..."
if command -v sqlcmd >/dev/null 2>&1; then
    # Test basic connection
    echo "Testing basic connection..."
    if sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_USER -P $MSSQL_PASSWORD -Q "SELECT @@VERSION" -d $MSSQL_DATABASE >/dev/null 2>&1; then
        echo "✓ Successfully connected to MS SQL Server"
        
        # Get detailed information
        echo ""
        echo "Server Information:"
        echo "==================="
        sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_USER -P $MSSQL_PASSWORD -Q "SELECT @@VERSION AS 'SQL Server Version'" -d $MSSQL_DATABASE -h -1 -s "|" -W
        
        echo ""
        echo "Database Information:"
        echo "===================="
        sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_USER -P $MSSQL_PASSWORD -Q "SELECT DB_NAME() AS 'Current Database', USER_NAME() AS 'Current User'" -d $MSSQL_DATABASE -h -1 -s "|" -W
        
        echo ""
        echo "SSL/TLS Configuration:"
        echo "====================="
        sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_USER -P $MSSQL_PASSWORD -Q "SELECT name, value_in_use FROM sys.configurations WHERE name = 'force encryption'" -d master -h -1 -s "|" -W
        
        echo ""
        echo "Sample Data Test:"
        echo "================"
        sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_USER -P $MSSQL_PASSWORD -Q "SELECT COUNT(*) AS 'Record Count' FROM sample_table" -d $MSSQL_DATABASE -h -1 -s "|" -W
        
    else
        echo "✗ Failed to connect to MS SQL Server"
        echo "Check credentials and server status"
    fi
else
    echo "✗ sqlcmd not found. Please install mssql-tools"
    echo "Installation command:"
    echo "Ubuntu: sudo apt-get install mssql-tools"
    echo "CentOS/RHEL: sudo yum install mssql-tools"
fi
echo ""

# Test 4: Alternative connection test with curl (checking if port is open)
echo "4. Testing HTTP-level connectivity..."
if command -v curl >/dev/null 2>&1; then
    if curl -m 5 -s telnet://$MSSQL_HOST:$MSSQL_PORT >/dev/null 2>&1; then
        echo "✓ Port $MSSQL_PORT responds to connections"
    else
        echo "✗ Port $MSSQL_PORT does not respond or is filtered"
    fi
else
    echo "curl not available for additional connectivity test"
fi

echo ""
echo "Connection test completed."
echo ""
echo "Quick Manual Test Commands:"
echo "=========================="
echo "1. sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_USER -P '$MSSQL_PASSWORD' -d $MSSQL_DATABASE"
echo "2. telnet $MSSQL_HOST $MSSQL_PORT"
echo "3. nc -zv $MSSQL_HOST $MSSQL_PORT"
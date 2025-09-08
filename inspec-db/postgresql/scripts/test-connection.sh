#!/bin/bash
# PostgreSQL Connection Test Script

set -e

# Configuration
PG_HOST=${PG_HOST:-"localhost"}
PG_PORT=${PG_PORT:-"5432"}
PG_USER=${PG_USER:-"test_user"}
PG_PASSWORD=${PG_PASSWORD:-"P@ssw0rd"}
PG_DATABASE=${PG_DATABASE:-"test_db"}

echo "PostgreSQL Connection Test"
echo "=========================="
echo "Host: $PG_HOST"
echo "Port: $PG_PORT"
echo "Database: $PG_DATABASE"
echo "User: $PG_USER"
echo ""

# Test 1: Network connectivity using telnet
echo "1. Testing network connectivity to PostgreSQL port..."
if command -v telnet >/dev/null 2>&1; then
    timeout 5 telnet $PG_HOST $PG_PORT && echo "✓ Port $PG_PORT is reachable" || echo "✗ Port $PG_PORT is not reachable"
else
    echo "Telnet not available, using nc (netcat)..."
    if command -v nc >/dev/null 2>&1; then
        nc -z -v -w5 $PG_HOST $PG_PORT && echo "✓ Port $PG_PORT is reachable" || echo "✗ Port $PG_PORT is not reachable"
    else
        echo "Neither telnet nor nc available, skipping port test"
    fi
fi
echo ""

# Test 2: PostgreSQL service status (if running locally)
echo "2. Checking PostgreSQL service status..."
if systemctl is-active --quiet postgresql 2>/dev/null; then
    echo "✓ PostgreSQL service is running"
elif systemctl is-active --quiet postgresql-* 2>/dev/null; then
    echo "✓ PostgreSQL service is running (versioned service)"
else
    echo "⚠ Cannot determine service status or service not running locally"
fi
echo ""

# Test 3: psql connection test
echo "3. Testing PostgreSQL connection with psql..."
if command -v psql >/dev/null 2>&1; then
    # Set password for non-interactive connection
    export PGPASSWORD=$PG_PASSWORD
    
    # Test basic connection
    echo "Testing basic connection..."
    if psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT version();" >/dev/null 2>&1; then
        echo "✓ Successfully connected to PostgreSQL"
        
        # Get detailed information
        echo ""
        echo "Server Information:"
        echo "==================="
        psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT version();" -t -A
        
        echo ""
        echo "Database Information:"
        echo "===================="
        psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT current_database() AS current_db, current_user AS current_user;" -t -A
        
        echo ""
        echo "SSL/TLS Configuration:"
        echo "====================="
        psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d postgres -c "SELECT name, setting FROM pg_settings WHERE name IN ('ssl', 'ssl_cert_file', 'ssl_key_file');" -t -A
        
        echo ""
        echo "Connection Security Information:"
        echo "==============================="
        psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT inet_client_addr() AS client_ip, inet_server_addr() AS server_ip;" -t -A
        
        echo ""
        echo "Sample Data Test:"
        echo "================"
        psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT COUNT(*) AS record_count FROM sample_table;" -t -A
        
        echo ""
        echo "User Permissions Test:"
        echo "====================="
        psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT table_name, privilege_type FROM information_schema.table_privileges WHERE grantee = '$PG_USER' LIMIT 5;" -t -A
        
        echo ""
        echo "SSL Connection Test:"
        echo "==================="
        # Test SSL-specific connection
        if psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT ssl_is_used() AS ssl_in_use;" 2>/dev/null; then
            psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT ssl_is_used() AS ssl_in_use;" -t -A
        else
            echo "SSL function not available (older PostgreSQL version)"
        fi
        
    else
        echo "✗ Failed to connect to PostgreSQL"
        echo "Check credentials and server status"
        echo "Error details:"
        psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE -c "SELECT 1;" 2>&1 || true
    fi
    
    # Clear password from environment
    unset PGPASSWORD
    
else
    echo "✗ psql not found. Please install postgresql-client"
    echo "Installation command:"
    echo "Ubuntu: sudo apt-get install postgresql-client"
    echo "CentOS/RHEL: sudo yum install postgresql"
fi
echo ""

# Test 4: Alternative connection test with curl (checking if port is open)
echo "4. Testing HTTP-level connectivity..."
if command -v curl >/dev/null 2>&1; then
    if curl -m 5 -s telnet://$PG_HOST:$PG_PORT >/dev/null 2>&1; then
        echo "✓ Port $PG_PORT responds to connections"
    else
        echo "✗ Port $PG_PORT does not respond or is filtered"
    fi
else
    echo "curl not available for additional connectivity test"
fi
echo ""

# Test 5: SSL-specific connection test
echo "5. Testing SSL/TLS connection..."
if command -v psql >/dev/null 2>&1; then
    export PGPASSWORD=$PG_PASSWORD
    
    # Force SSL connection
    echo "Testing SSL-required connection..."
    if psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE sslmode=require -c "SELECT 'SSL connection successful';" >/dev/null 2>&1; then
        echo "✓ SSL connection successful"
    else
        echo "⚠ SSL connection failed or not configured"
        echo "Trying without SSL requirement..."
        if psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE sslmode=disable -c "SELECT 'Non-SSL connection successful';" >/dev/null 2>&1; then
            echo "✓ Non-SSL connection successful"
        else
            echo "✗ All connection attempts failed"
        fi
    fi
    
    unset PGPASSWORD
fi

echo ""
echo "Connection test completed."
echo ""
echo "Quick Manual Test Commands:"
echo "=========================="
echo "1. Basic connection:"
echo "   PGPASSWORD='$PG_PASSWORD' psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE"
echo ""
echo "2. SSL-required connection:"
echo "   PGPASSWORD='$PG_PASSWORD' psql -h $PG_HOST -p $PG_PORT -U $PG_USER -d $PG_DATABASE sslmode=require"
echo ""
echo "3. Port connectivity test:"
echo "   telnet $PG_HOST $PG_PORT"
echo "   nc -zv $PG_HOST $PG_PORT"
echo ""
echo "4. Database setup (run as postgres user):"
echo "   sudo -u postgres psql -f setup-database.sql"
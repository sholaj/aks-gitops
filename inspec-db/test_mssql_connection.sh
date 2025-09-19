#!/bin/bash

# MSSQL Connection Testing Script
# Purpose: Systematic testing of MSSQL connectivity with multiple authentication methods
# Version: 1.0
# Usage: ./test_mssql_connection.sh [server] [port] [database]

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values - override with environment variables or arguments
MSSQL_SERVER="${1:-${MSSQL_SERVER:-localhost}}"
MSSQL_PORT="${2:-${MSSQL_PORT:-1433}}"
MSSQL_DATABASE="${3:-${MSSQL_DATABASE:-master}}"
MSSQL_USERNAME="${MSSQL_USERNAME:-}"
MSSQL_PASSWORD="${MSSQL_PASSWORD:-}"
CONNECTION_TIMEOUT="${CONNECTION_TIMEOUT:-30}"
SSL_MODE="${SSL_MODE:-trust}"  # trust, verify, or disable
VERBOSE="${VERBOSE:-false}"
LOG_FILE="${LOG_FILE:-mssql_test_$(date +%Y%m%d_%H%M%S).log}"

# Test results tracking
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Function to log messages
log_message() {
    local level=$1
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"

    case $level in
        ERROR)   print_color "$RED" "✗ $message" ;;
        SUCCESS) print_color "$GREEN" "✓ $message" ;;
        WARNING) print_color "$YELLOW" "⚠ $message" ;;
        INFO)    print_color "$BLUE" "ℹ $message" ;;
        *)       echo "$message" ;;
    esac
}

# Function to print header
print_header() {
    echo
    print_color "$BLUE" "========================================"
    print_color "$BLUE" "$1"
    print_color "$BLUE" "========================================"
    echo
}

# Function to print test result
record_test_result() {
    local test_name=$1
    local result=$2
    local details=$3

    TEST_RESULTS[$test_name]=$result
    ((TOTAL_TESTS++))

    if [ "$result" = "PASS" ]; then
        ((PASSED_TESTS++))
        log_message SUCCESS "$test_name: PASSED - $details"
    else
        ((FAILED_TESTS++))
        log_message ERROR "$test_name: FAILED - $details"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if sqlcmd is installed
    if command -v sqlcmd &> /dev/null; then
        local version=$(sqlcmd -? 2>&1 | head -1)
        log_message SUCCESS "sqlcmd is installed"
        [ "$VERBOSE" = "true" ] && log_message INFO "Version: $version"
        record_test_result "Prerequisites" "PASS" "sqlcmd found"
    else
        log_message ERROR "sqlcmd is not installed"
        log_message INFO "Install with:"
        log_message INFO "  Ubuntu/Debian: sudo apt-get install mssql-tools"
        log_message INFO "  RHEL/CentOS: sudo yum install mssql-tools"
        log_message INFO "  macOS: brew install mssql-tools"
        record_test_result "Prerequisites" "FAIL" "sqlcmd not found"
        return 1
    fi

    # Check if telnet or nc is available for network testing
    if command -v telnet &> /dev/null || command -v nc &> /dev/null; then
        log_message SUCCESS "Network testing tools available"
    else
        log_message WARNING "telnet/nc not found - network testing limited"
    fi
}

# Function to test network connectivity
test_network_connectivity() {
    print_header "Testing Network Connectivity"

    log_message INFO "Testing connection to $MSSQL_SERVER:$MSSQL_PORT"

    # Try different methods to test connectivity
    if command -v nc &> /dev/null; then
        if nc -zv -w5 "$MSSQL_SERVER" "$MSSQL_PORT" &> /dev/null; then
            record_test_result "Network_Connectivity" "PASS" "Port $MSSQL_PORT is open"
            return 0
        fi
    elif command -v telnet &> /dev/null; then
        if timeout 5 bash -c "echo quit | telnet $MSSQL_SERVER $MSSQL_PORT 2>/dev/null | grep -q Connected"; then
            record_test_result "Network_Connectivity" "PASS" "Port $MSSQL_PORT is open"
            return 0
        fi
    else
        # Fallback to sqlcmd connection attempt
        if timeout "$CONNECTION_TIMEOUT" sqlcmd -S "$MSSQL_SERVER,$MSSQL_PORT" -Q "SELECT 1" &> /dev/null; then
            record_test_result "Network_Connectivity" "PASS" "Server is reachable"
            return 0
        fi
    fi

    record_test_result "Network_Connectivity" "FAIL" "Cannot reach $MSSQL_SERVER:$MSSQL_PORT"
    log_message ERROR "Troubleshooting steps:"
    log_message INFO "  1. Verify server name/IP: $MSSQL_SERVER"
    log_message INFO "  2. Check if port $MSSQL_PORT is correct"
    log_message INFO "  3. Verify firewall rules allow connection"
    log_message INFO "  4. Check DNS resolution: nslookup $MSSQL_SERVER"
    log_message INFO "  5. Test with IP address instead of hostname"
    return 1
}

# Function to build SSL flags based on mode
get_ssl_flags() {
    case "$SSL_MODE" in
        trust)
            echo "-C"  # Trust server certificate
            ;;
        verify)
            echo ""    # Verify certificate
            ;;
        disable)
            echo "-C"  # For compatibility, still use -C
            ;;
        *)
            echo "-C"
            ;;
    esac
}

# Function to test Windows authentication
test_windows_auth() {
    print_header "Testing Windows Authentication"

    log_message INFO "Attempting Windows authentication..."

    local ssl_flags=$(get_ssl_flags)
    local cmd="sqlcmd -S \"$MSSQL_SERVER,$MSSQL_PORT\" -d \"$MSSQL_DATABASE\" -E $ssl_flags -l $CONNECTION_TIMEOUT -Q \"SELECT SYSTEM_USER, AUTH_SCHEME FROM sys.dm_exec_connections WHERE session_id = @@SPID\" -h -1 -W"

    [ "$VERBOSE" = "true" ] && log_message INFO "Command: $cmd"

    if result=$(eval "$cmd" 2>&1); then
        record_test_result "Windows_Auth" "PASS" "Successfully authenticated"
        log_message INFO "Authenticated as: $(echo "$result" | head -1)"
        log_message INFO "Auth scheme: $(echo "$result" | awk '{print $2}')"
        return 0
    else
        local error_msg=$(echo "$result" | head -5)
        record_test_result "Windows_Auth" "FAIL" "Authentication failed"
        [ "$VERBOSE" = "true" ] && log_message ERROR "Error: $error_msg"

        # Provide specific troubleshooting based on error
        if echo "$error_msg" | grep -q "Login failed"; then
            log_message INFO "Troubleshooting Windows auth failure:"
            log_message INFO "  1. Verify domain trust between client and server"
            log_message INFO "  2. Check if Kerberos/NTLM is properly configured"
            log_message INFO "  3. Ensure SPN is registered: setspn -L <sql_service_account>"
            log_message INFO "  4. Verify the account has CONNECT permission"
        fi
        return 1
    fi
}

# Function to test SQL Server authentication
test_sql_auth() {
    print_header "Testing SQL Server Authentication"

    if [ -z "$MSSQL_USERNAME" ] || [ -z "$MSSQL_PASSWORD" ]; then
        log_message WARNING "SQL credentials not provided (MSSQL_USERNAME/MSSQL_PASSWORD)"
        log_message INFO "Prompting for credentials..."

        read -p "SQL Username: " MSSQL_USERNAME
        read -s -p "SQL Password: " MSSQL_PASSWORD
        echo
    fi

    log_message INFO "Attempting SQL authentication as user: $MSSQL_USERNAME"

    local ssl_flags=$(get_ssl_flags)
    local cmd="sqlcmd -S \"$MSSQL_SERVER,$MSSQL_PORT\" -d \"$MSSQL_DATABASE\" -U \"$MSSQL_USERNAME\" -P \"$MSSQL_PASSWORD\" $ssl_flags -l $CONNECTION_TIMEOUT -Q \"SELECT SYSTEM_USER, AUTH_SCHEME FROM sys.dm_exec_connections WHERE session_id = @@SPID\" -h -1 -W"

    [ "$VERBOSE" = "true" ] && log_message INFO "Command: sqlcmd -S \"$MSSQL_SERVER,$MSSQL_PORT\" -d \"$MSSQL_DATABASE\" -U \"$MSSQL_USERNAME\" -P [HIDDEN] $ssl_flags ..."

    if result=$(eval "$cmd" 2>&1); then
        record_test_result "SQL_Auth" "PASS" "Successfully authenticated"
        log_message INFO "Authenticated as: $(echo "$result" | head -1)"
        return 0
    else
        local error_msg=$(echo "$result" | head -5)
        record_test_result "SQL_Auth" "FAIL" "Authentication failed"
        [ "$VERBOSE" = "true" ] && log_message ERROR "Error: $error_msg"

        # Provide specific troubleshooting
        if echo "$error_msg" | grep -q "Login failed"; then
            log_message INFO "Troubleshooting SQL auth failure:"
            log_message INFO "  1. Verify username and password are correct"
            log_message INFO "  2. Check if SQL authentication is enabled (mixed mode)"
            log_message INFO "  3. Ensure the SQL login exists and is enabled"
            log_message INFO "  4. Verify the account has CONNECT permission"
            log_message INFO "  5. Check password policy requirements"
        fi
        return 1
    fi
}

# Function to discover authentication methods
discover_auth_methods() {
    print_header "Discovering Available Authentication Methods"

    local auth_methods=()

    # Test Windows auth
    if test_windows_auth &> /dev/null; then
        auth_methods+=("Windows")
        log_message SUCCESS "Windows authentication: AVAILABLE"
    else
        log_message WARNING "Windows authentication: NOT AVAILABLE"
    fi

    # Test SQL auth if credentials are available
    if [ -n "$MSSQL_USERNAME" ] && [ -n "$MSSQL_PASSWORD" ]; then
        if test_sql_auth &> /dev/null; then
            auth_methods+=("SQL")
            log_message SUCCESS "SQL authentication: AVAILABLE"
        else
            log_message WARNING "SQL authentication: NOT AVAILABLE"
        fi
    else
        log_message INFO "SQL authentication: NOT TESTED (no credentials)"
    fi

    if [ ${#auth_methods[@]} -gt 0 ]; then
        log_message SUCCESS "Available authentication methods: ${auth_methods[*]}"
        return 0
    else
        log_message ERROR "No authentication methods available"
        return 1
    fi
}

# Function to test database access
test_database_access() {
    print_header "Testing Database Access"

    local auth_flag=""
    local auth_params=""

    # Determine which auth method to use based on what worked
    if [ "${TEST_RESULTS[Windows_Auth]:-FAIL}" = "PASS" ]; then
        auth_flag="-E"
        auth_params=""
    elif [ "${TEST_RESULTS[SQL_Auth]:-FAIL}" = "PASS" ]; then
        auth_flag=""
        auth_params="-U \"$MSSQL_USERNAME\" -P \"$MSSQL_PASSWORD\""
    else
        log_message ERROR "No working authentication method found"
        record_test_result "Database_Access" "FAIL" "No authentication available"
        return 1
    fi

    local ssl_flags=$(get_ssl_flags)

    # Test 1: Basic database connectivity
    log_message INFO "Testing basic database connectivity..."
    local cmd="sqlcmd -S \"$MSSQL_SERVER,$MSSQL_PORT\" -d \"$MSSQL_DATABASE\" $auth_flag $auth_params $ssl_flags -l $CONNECTION_TIMEOUT -Q \"SELECT DB_NAME() as CurrentDatabase, GETDATE() as ServerTime\" -h -1 -W"

    if result=$(eval "$cmd" 2>&1); then
        log_message SUCCESS "Connected to database: $(echo "$result" | awk '{print $1}')"
        record_test_result "Database_Access" "PASS" "Can access $MSSQL_DATABASE"
    else
        log_message ERROR "Cannot access database: $MSSQL_DATABASE"
        record_test_result "Database_Access" "FAIL" "Cannot access $MSSQL_DATABASE"
        return 1
    fi

    # Test 2: Check permissions
    log_message INFO "Checking user permissions..."
    cmd="sqlcmd -S \"$MSSQL_SERVER,$MSSQL_PORT\" -d \"$MSSQL_DATABASE\" $auth_flag $auth_params $ssl_flags -l $CONNECTION_TIMEOUT -Q \"
        SELECT
            'VIEW_SERVER_STATE' as Permission,
            CASE WHEN HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') = 1
                 THEN 'GRANTED' ELSE 'DENIED' END as Status
        UNION ALL
        SELECT
            'VIEW_ANY_DATABASE' as Permission,
            CASE WHEN HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DATABASE') = 1
                 THEN 'GRANTED' ELSE 'DENIED' END as Status
        UNION ALL
        SELECT
            'VIEW_DEFINITION' as Permission,
            CASE WHEN HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DEFINITION') = 1
                 THEN 'GRANTED' ELSE 'DENIED' END as Status
    \" -h -1 -W -s '|'"

    if result=$(eval "$cmd" 2>&1); then
        log_message INFO "Permission check results:"
        echo "$result" | while IFS='|' read -r permission status; do
            if [ "$status" = "GRANTED" ]; then
                log_message SUCCESS "  $permission: $status"
            else
                log_message WARNING "  $permission: $status"
            fi
        done
        record_test_result "Permissions_Check" "PASS" "Permission check completed"
    else
        log_message WARNING "Could not check all permissions"
        record_test_result "Permissions_Check" "PARTIAL" "Limited permission visibility"
    fi
}

# Function to test query execution
test_query_execution() {
    print_header "Testing Query Execution"

    local auth_flag=""
    local auth_params=""

    # Determine which auth method to use
    if [ "${TEST_RESULTS[Windows_Auth]:-FAIL}" = "PASS" ]; then
        auth_flag="-E"
        auth_params=""
    elif [ "${TEST_RESULTS[SQL_Auth]:-FAIL}" = "PASS" ]; then
        auth_flag=""
        auth_params="-U \"$MSSQL_USERNAME\" -P \"$MSSQL_PASSWORD\""
    else
        log_message ERROR "No working authentication method found"
        record_test_result "Query_Execution" "FAIL" "No authentication available"
        return 1
    fi

    local ssl_flags=$(get_ssl_flags)

    # Test various queries relevant to compliance scanning
    log_message INFO "Testing compliance-related queries..."

    # Query 1: Server information
    local cmd="sqlcmd -S \"$MSSQL_SERVER,$MSSQL_PORT\" -d \"$MSSQL_DATABASE\" $auth_flag $auth_params $ssl_flags -l $CONNECTION_TIMEOUT -Q \"
        SELECT
            SERVERPROPERTY('ProductVersion') as Version,
            SERVERPROPERTY('ProductLevel') as PatchLevel,
            SERVERPROPERTY('Edition') as Edition,
            @@SERVERNAME as ServerName
    \" -h -1 -W -s '|'"

    if result=$(eval "$cmd" 2>&1); then
        log_message SUCCESS "Server information retrieved"
        [ "$VERBOSE" = "true" ] && echo "$result" | while IFS='|' read -r version patch edition server; do
            log_message INFO "  Version: $version"
            log_message INFO "  Patch Level: $patch"
            log_message INFO "  Edition: $edition"
            log_message INFO "  Server Name: $server"
        done
        record_test_result "Query_Execution" "PASS" "Can execute compliance queries"
    else
        log_message ERROR "Failed to execute queries"
        record_test_result "Query_Execution" "FAIL" "Cannot execute queries"
        return 1
    fi
}

# Function to generate connection strings
generate_connection_strings() {
    print_header "Connection String Examples"

    log_message INFO "Based on testing, here are working connection methods:"
    echo

    # Windows Authentication
    if [ "${TEST_RESULTS[Windows_Auth]:-FAIL}" = "PASS" ]; then
        print_color "$GREEN" "Windows Authentication:"
        echo "  sqlcmd -S \"$MSSQL_SERVER,$MSSQL_PORT\" -d \"$MSSQL_DATABASE\" -E -C"
        echo "  Connection String: Server=$MSSQL_SERVER,$MSSQL_PORT;Database=$MSSQL_DATABASE;Integrated Security=true;TrustServerCertificate=true"
        echo
    fi

    # SQL Authentication
    if [ "${TEST_RESULTS[SQL_Auth]:-FAIL}" = "PASS" ]; then
        print_color "$GREEN" "SQL Server Authentication:"
        echo "  sqlcmd -S \"$MSSQL_SERVER,$MSSQL_PORT\" -d \"$MSSQL_DATABASE\" -U \"username\" -P \"password\" -C"
        echo "  Connection String: Server=$MSSQL_SERVER,$MSSQL_PORT;Database=$MSSQL_DATABASE;User Id=username;Password=password;TrustServerCertificate=true"
        echo
    fi

    # Ansible variables
    print_color "$BLUE" "Ansible Playbook Execution:"
    echo "  ansible-playbook mssql_basic_check.yml \\"
    echo "    -e mssql_server=$MSSQL_SERVER \\"
    echo "    -e mssql_port=$MSSQL_PORT \\"
    echo "    -e mssql_database=$MSSQL_DATABASE \\"
    if [ "${TEST_RESULTS[Windows_Auth]:-FAIL}" = "PASS" ]; then
        echo "    -e auth_method=windows"
    elif [ "${TEST_RESULTS[SQL_Auth]:-FAIL}" = "PASS" ]; then
        echo "    -e auth_method=sql \\"
        echo "    -e mssql_username=your_username \\"
        echo "    -e mssql_password=your_password"
    fi
    echo

    # InSpec execution
    print_color "$BLUE" "InSpec Profile Execution:"
    echo "  inspec exec mssql/inspec-profiles \\"
    echo "    --input server=$MSSQL_SERVER \\"
    echo "    --input port=$MSSQL_PORT \\"
    echo "    --input database=$MSSQL_DATABASE \\"
    if [ "${TEST_RESULTS[Windows_Auth]:-FAIL}" = "PASS" ]; then
        echo "    --input auth_method=windows"
    elif [ "${TEST_RESULTS[SQL_Auth]:-FAIL}" = "PASS" ]; then
        echo "    --input auth_method=sql \\"
        echo "    --input username=your_username \\"
        echo "    --input password=your_password"
    fi
    echo
}

# Function to print test summary
print_summary() {
    print_header "Test Summary"

    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    log_message INFO "Total Tests: $TOTAL_TESTS"
    log_message SUCCESS "Passed: $PASSED_TESTS"
    log_message ERROR "Failed: $FAILED_TESTS"
    log_message INFO "Success Rate: ${success_rate}%"

    echo
    print_color "$BLUE" "Individual Test Results:"
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        if [ "$result" = "PASS" ]; then
            print_color "$GREEN" "  ✓ $test_name: $result"
        elif [ "$result" = "PARTIAL" ]; then
            print_color "$YELLOW" "  ⚠ $test_name: $result"
        else
            print_color "$RED" "  ✗ $test_name: $result"
        fi
    done

    echo
    log_message INFO "Detailed logs saved to: $LOG_FILE"

    # Overall assessment
    echo
    if [ $success_rate -ge 80 ]; then
        print_color "$GREEN" "✓ OVERALL: System is READY for compliance scanning"
    elif [ $success_rate -ge 50 ]; then
        print_color "$YELLOW" "⚠ OVERALL: System is PARTIALLY READY - review failed tests"
    else
        print_color "$RED" "✗ OVERALL: System is NOT READY - address critical failures"
    fi

    # Exit with appropriate code
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Function to handle script interruption
cleanup() {
    echo
    log_message WARNING "Script interrupted by user"
    print_summary
}

# Main execution
main() {
    # Set up trap for clean exit
    trap cleanup INT TERM

    # Print banner
    print_color "$BLUE" "╔══════════════════════════════════════╗"
    print_color "$BLUE" "║   MSSQL Connection Testing Script    ║"
    print_color "$BLUE" "║          Version 1.0                 ║"
    print_color "$BLUE" "╚══════════════════════════════════════╝"
    echo

    # Display configuration
    log_message INFO "Configuration:"
    log_message INFO "  Server: $MSSQL_SERVER"
    log_message INFO "  Port: $MSSQL_PORT"
    log_message INFO "  Database: $MSSQL_DATABASE"
    log_message INFO "  SSL Mode: $SSL_MODE"
    log_message INFO "  Timeout: ${CONNECTION_TIMEOUT}s"
    log_message INFO "  Log File: $LOG_FILE"
    echo

    # Run tests in sequence
    check_prerequisites || exit 1

    if test_network_connectivity; then
        # Try authentication methods
        local auth_success=false

        # Test Windows auth
        if test_windows_auth; then
            auth_success=true
        fi

        # Test SQL auth
        if [ -n "$MSSQL_USERNAME" ] || [ "$auth_success" = "false" ]; then
            if test_sql_auth; then
                auth_success=true
            fi
        fi

        # If at least one auth method works, proceed with further tests
        if [ "$auth_success" = "true" ]; then
            test_database_access
            test_query_execution
            generate_connection_strings
        else
            log_message ERROR "No authentication methods succeeded"
            log_message INFO "Run with VERBOSE=true for more details"
        fi
    fi

    # Print final summary
    print_summary
}

# Execute main function
main "$@"
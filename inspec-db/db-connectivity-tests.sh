#!/bin/bash

# Database Connectivity Testing Framework
# For validating database client installations and connections

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Log file
LOG_FILE="db-test-results-$(date +%Y%m%d-%H%M%S).log"

# Functions for colored output
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo "[$(date)] HEADER: $1" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    echo "[$(date)] SUCCESS: $1" >> "$LOG_FILE"
    ((TESTS_PASSED++))
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
    echo "[$(date)] FAILURE: $1" >> "$LOG_FILE"
    ((TESTS_FAILED++))
}

print_skip() {
    echo -e "${YELLOW}⊘${NC} $1"
    echo "[$(date)] SKIPPED: $1" >> "$LOG_FILE"
    ((TESTS_SKIPPED++))
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
    echo "[$(date)] INFO: $1" >> "$LOG_FILE"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Test binary installation
test_binary() {
    local cmd=$1
    local name=$2
    
    if command_exists "$cmd"; then
        print_success "$name binary found: $(which $cmd)"
        return 0
    else
        print_failure "$name binary not found"
        return 1
    fi
}

# Test version output
test_version() {
    local cmd=$1
    local args=$2
    local name=$3
    
    if command_exists "$cmd"; then
        local version=$($cmd $args 2>&1 | head -1)
        print_success "$name version: $version"
        return 0
    else
        print_skip "$name version check skipped (binary not found)"
        return 1
    fi
}

# Test library existence
test_library() {
    local lib=$1
    local name=$2
    
    if ldconfig -p | grep -q "$lib"; then
        print_success "$name library found in system"
        return 0
    else
        print_failure "$name library not found"
        return 1
    fi
}

# Test environment variable
test_env_var() {
    local var=$1
    local name=$2
    
    if [ -n "${!var}" ]; then
        print_success "$name environment variable set: ${!var}"
        return 0
    else
        print_failure "$name environment variable not set"
        return 1
    fi
}

# Test file existence
test_file() {
    local file=$1
    local name=$2
    
    if [ -f "$file" ]; then
        print_success "$name file exists: $file"
        return 0
    else
        print_failure "$name file not found: $file"
        return 1
    fi
}

# Test network connectivity
test_network() {
    local host=$1
    local port=$2
    local name=$3
    
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        print_success "$name port $port is reachable on $host"
        return 0
    else
        print_failure "$name port $port is not reachable on $host"
        return 1
    fi
}

# Test MSSQL connection
test_mssql_connection() {
    local server=$1
    local user=$2
    local pass=$3
    
    if command_exists sqlcmd; then
        if sqlcmd -S "$server" -U "$user" -P "$pass" -C -Q "SELECT 1" &>/dev/null; then
            print_success "MSSQL connection successful to $server"
            return 0
        else
            print_failure "MSSQL connection failed to $server"
            return 1
        fi
    else
        print_skip "MSSQL connection test skipped (sqlcmd not found)"
        return 1
    fi
}

# Test Oracle connection
test_oracle_connection() {
    local connstr=$1
    
    if command_exists sqlplus; then
        if echo "SELECT 1 FROM DUAL;" | sqlplus -S "$connstr" &>/dev/null; then
            print_success "Oracle connection successful"
            return 0
        else
            print_failure "Oracle connection failed"
            return 1
        fi
    else
        print_skip "Oracle connection test skipped (sqlplus not found)"
        return 1
    fi
}

# Test Sybase/FreeTDS connection
test_sybase_connection() {
    local host=$1
    local port=$2
    local user=$3
    local pass=$4
    
    if command_exists tsql; then
        if echo "SELECT 1\nGO" | tsql -S "$host" -p "$port" -U "$user" -P "$pass" &>/dev/null; then
            print_success "Sybase connection successful to $host:$port"
            return 0
        else
            print_failure "Sybase connection failed to $host:$port"
            return 1
        fi
    else
        print_skip "Sybase connection test skipped (tsql not found)"
        return 1
    fi
}

# Main test execution
main() {
    echo "Database Connectivity Test Suite"
    echo "================================"
    echo "Started: $(date)"
    echo "" | tee -a "$LOG_FILE"
    
    # 1. Test Binary Installations
    print_header "Binary Installation Tests"
    test_binary "sqlcmd" "MSSQL sqlcmd"
    test_binary "sqlplus" "Oracle sqlplus"
    test_binary "isql" "FreeTDS isql"
    test_binary "tsql" "FreeTDS tsql"
    test_binary "bcp" "MSSQL bcp"
    test_binary "odbcinst" "ODBC installer"
    
    # 2. Test Version Information
    print_header "Version Information Tests"
    test_version "sqlcmd" "-?" "MSSQL sqlcmd"
    test_version "sqlplus" "-version" "Oracle sqlplus"
    test_version "isql" "--version" "FreeTDS isql"
    test_version "tsql" "-C" "FreeTDS tsql"
    
    # 3. Test Libraries
    print_header "Library Installation Tests"
    test_library "libmsodbcsql" "MSSQL ODBC Driver"
    test_library "libodbcinst" "ODBC Instance"
    test_library "libtdsodbc" "FreeTDS ODBC"
    test_library "libclntsh" "Oracle Client"
    test_library "libsqlplus" "Oracle SQL*Plus"
    
    # 4. Test Environment Variables
    print_header "Environment Variable Tests"
    test_env_var "PATH" "System PATH"
    if [ -d "/usr/lib/oracle" ]; then
        test_env_var "ORACLE_HOME" "Oracle HOME"
        test_env_var "LD_LIBRARY_PATH" "Library PATH"
    fi
    
    # 5. Test Configuration Files
    print_header "Configuration File Tests"
    test_file "/etc/odbcinst.ini" "ODBC driver configuration"
    test_file "/etc/odbc.ini" "ODBC DSN configuration"
    test_file "/etc/freetds.conf" "FreeTDS configuration"
    
    # 6. Test ODBC Drivers
    print_header "ODBC Driver Tests"
    if command_exists odbcinst; then
        drivers=$(odbcinst -q -d 2>/dev/null)
        if [ -n "$drivers" ]; then
            print_success "ODBC drivers found:"
            echo "$drivers" | while read driver; do
                echo "  - $driver"
            done
        else
            print_failure "No ODBC drivers configured"
        fi
    else
        print_skip "ODBC driver test skipped (odbcinst not found)"
    fi
    
    # 7. Network Connectivity Tests (if servers provided)
    if [ -n "$TEST_SERVERS" ]; then
        print_header "Network Connectivity Tests"
        
        if [ -n "$MSSQL_SERVER" ]; then
            test_network "${MSSQL_SERVER%:*}" "${MSSQL_SERVER#*:}" "MSSQL"
        fi
        
        if [ -n "$ORACLE_SERVER" ]; then
            test_network "${ORACLE_SERVER%:*}" "${ORACLE_SERVER#*:}" "Oracle"
        fi
        
        if [ -n "$SYBASE_SERVER" ]; then
            test_network "${SYBASE_SERVER%:*}" "${SYBASE_SERVER#*:}" "Sybase"
        fi
    fi
    
    # 8. Live Connection Tests (if credentials provided)
    if [ -n "$TEST_CONNECTIONS" ]; then
        print_header "Live Connection Tests"
        
        if [ -n "$MSSQL_CONN" ]; then
            IFS='|' read -r server user pass <<< "$MSSQL_CONN"
            test_mssql_connection "$server" "$user" "$pass"
        fi
        
        if [ -n "$ORACLE_CONN" ]; then
            test_oracle_connection "$ORACLE_CONN"
        fi
        
        if [ -n "$SYBASE_CONN" ]; then
            IFS='|' read -r host port user pass <<< "$SYBASE_CONN"
            test_sybase_connection "$host" "$port" "$user" "$pass"
        fi
    fi
    
    # 9. InSpec Compatibility Test
    print_header "InSpec Compatibility Tests"
    
    # Check for Ruby (InSpec requirement)
    if command_exists ruby; then
        ruby_version=$(ruby --version)
        print_success "Ruby installed: $ruby_version"
    else
        print_info "Ruby not installed (required for InSpec)"
    fi
    
    # Check for InSpec
    if command_exists inspec; then
        inspec_version=$(inspec version)
        print_success "InSpec installed: $inspec_version"
    else
        print_info "InSpec not installed"
    fi
    
    # Summary
    print_header "Test Summary"
    echo ""
    echo "Tests Passed:  $TESTS_PASSED"
    echo "Tests Failed:  $TESTS_FAILED"
    echo "Tests Skipped: $TESTS_SKIPPED"
    echo ""
    echo "Total Tests:   $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All critical tests passed!${NC}"
        echo "System is ready for database connectivity testing."
    else
        echo -e "${RED}Some tests failed. Please review the log for details.${NC}"
    fi
    
    echo ""
    echo "Detailed log saved to: $LOG_FILE"
    echo "Completed: $(date)"
    
    # Return appropriate exit code
    [ $TESTS_FAILED -eq 0 ]
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test-servers)
            TEST_SERVERS=1
            shift
            ;;
        --mssql-server)
            MSSQL_SERVER="$2"
            shift 2
            ;;
        --oracle-server)
            ORACLE_SERVER="$2"
            shift 2
            ;;
        --sybase-server)
            SYBASE_SERVER="$2"
            shift 2
            ;;
        --test-connections)
            TEST_CONNECTIONS=1
            shift
            ;;
        --mssql-conn)
            MSSQL_CONN="$2"
            shift 2
            ;;
        --oracle-conn)
            ORACLE_CONN="$2"
            shift 2
            ;;
        --sybase-conn)
            SYBASE_CONN="$2"
            shift 2
            ;;
        --help)
            cat << EOF
Usage: $0 [OPTIONS]

Database Connectivity Testing Framework

Options:
  --test-servers           Enable network connectivity tests
  --mssql-server HOST:PORT Test MSSQL server connectivity
  --oracle-server HOST:PORT Test Oracle server connectivity
  --sybase-server HOST:PORT Test Sybase server connectivity
  
  --test-connections       Enable live connection tests
  --mssql-conn SERVER|USER|PASS  Test MSSQL connection
  --oracle-conn USER/PASS@//HOST:PORT/SERVICE  Test Oracle connection
  --sybase-conn HOST|PORT|USER|PASS  Test Sybase connection
  
  --help                   Show this help message

Examples:
  # Basic test (binaries and configuration only)
  $0
  
  # Test network connectivity
  $0 --test-servers --mssql-server sqlserver.example.com:1433
  
  # Test live connections
  $0 --test-connections --mssql-conn "server,1433|sa|password"
  
  # Full test
  $0 --test-servers --test-connections \\
     --mssql-server sqlserver:1433 \\
     --mssql-conn "sqlserver,1433|sa|password"
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main test suite
main
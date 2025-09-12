#!/bin/bash

# URL Validation Script
# Tests all download URLs to ensure they are still valid

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
URLS_VALID=0
URLS_INVALID=0
URLS_REDIRECTED=0

# Log file
LOG_FILE="url-test-results-$(date +%Y%m%d-%H%M%S).log"

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo "[$(date)] HEADER: $1" >> "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    echo "[$(date)] SUCCESS: $1" >> "$LOG_FILE"
    ((URLS_VALID++))
}

print_failure() {
    echo -e "${RED}✗${NC} $1"
    echo "[$(date)] FAILURE: $1" >> "$LOG_FILE"
    ((URLS_INVALID++))
}

print_redirect() {
    echo -e "${YELLOW}⟲${NC} $1"
    echo "[$(date)] REDIRECT: $1" >> "$LOG_FILE"
    ((URLS_REDIRECTED++))
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
    echo "[$(date)] INFO: $1" >> "$LOG_FILE"
}

# Test URL function
test_url() {
    local url=$1
    local name=$2
    local expected_size=$3
    
    echo -n "Testing $name... "
    
    # Use curl to test URL with head request
    if response=$(curl -sIL --max-time 10 "$url" 2>&1); then
        # Check HTTP status
        status=$(echo "$response" | grep -E "HTTP/[0-9.]+ [0-9]+" | tail -1 | awk '{print $2}')
        
        case $status in
            200)
                # Get content length if available
                size=$(echo "$response" | grep -i "content-length" | tail -1 | awk '{print $2}' | tr -d '\r')
                if [ -n "$size" ]; then
                    size_mb=$(echo "scale=2; $size/1024/1024" | bc 2>/dev/null || echo "unknown")
                    print_success "$name (${size_mb}MB)"
                else
                    print_success "$name (size unknown)"
                fi
                ;;
            301|302|303|307|308)
                # Handle redirects
                new_url=$(echo "$response" | grep -i "location:" | tail -1 | awk '{print $2}' | tr -d '\r')
                print_redirect "$name -> $new_url"
                ;;
            404)
                print_failure "$name (Not Found - 404)"
                ;;
            403)
                print_failure "$name (Forbidden - 403)"
                ;;
            *)
                print_failure "$name (HTTP $status)"
                ;;
        esac
    else
        print_failure "$name (Connection failed)"
    fi
}

echo "URL Validation Test Suite"
echo "========================"
echo "Started: $(date)"
echo "" | tee -a "$LOG_FILE"

# 1. Microsoft SQL Server URLs
print_header "Microsoft SQL Server URLs"

test_url "https://packages.microsoft.com/config/rhel/8/packages-microsoft-prod.rpm" "Microsoft Repo Config"
test_url "https://packages.microsoft.com/rhel/8/prod/msodbcsql18-18.3.3.1-1.x86_64.rpm" "MSSQL ODBC Driver 18"
test_url "https://packages.microsoft.com/rhel/8/prod/mssql-tools18-18.3.1.1-1.x86_64.rpm" "MSSQL Tools 18"
test_url "https://packages.microsoft.com/rhel/8/prod/unixODBC-2.3.11-1.rh.x86_64.rpm" "Microsoft UnixODBC"

# 2. Oracle URLs
print_header "Oracle Instant Client URLs"

test_url "https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-basic-21.13.0.0.0-1.x86_64.rpm" "Oracle Basic Client"
test_url "https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-sqlplus-21.13.0.0.0-1.x86_64.rpm" "Oracle SQL*Plus"
test_url "https://download.oracle.com/otn_software/linux/instantclient/2113000/oracle-instantclient-devel-21.13.0.0.0-1.x86_64.rpm" "Oracle Development"

# 3. FreeTDS URLs
print_header "FreeTDS URLs"

test_url "https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm" "EPEL Release"
test_url "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/f/freetds-1.3.3-1.el8.x86_64.rpm" "FreeTDS"
test_url "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/f/freetds-libs-1.3.3-1.el8.x86_64.rpm" "FreeTDS libs"
test_url "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/f/freetds-devel-1.3.3-1.el8.x86_64.rpm" "FreeTDS devel"

# 4. Ansible URLs
print_header "Ansible URLs"

test_url "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/a/ansible-core-2.16.2-2.el8.noarch.rpm" "Ansible Core"
test_url "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/a/ansible-8.3.0-1.el8.noarch.rpm" "Ansible Package"
test_url "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/p/python3-packaging-20.4-1.el8.noarch.rpm" "Python Packaging"
test_url "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/p/python3-resolvelib-0.5.4-5.el8.noarch.rpm" "Python Resolvelib"
test_url "https://dl.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/s/sshpass-1.09-4.el8.x86_64.rpm" "sshpass"

# 5. Ansible Galaxy Collections
print_header "Ansible Galaxy Collections"

test_url "https://galaxy.ansible.com/download/ansible-posix-1.5.4.tar.gz" "Ansible POSIX Collection"
test_url "https://galaxy.ansible.com/download/ansible-windows-2.2.0.tar.gz" "Ansible Windows Collection"
test_url "https://galaxy.ansible.com/download/community-general-8.2.0.tar.gz" "Community General Collection"

# 6. CentOS/Dependencies URLs
print_header "CentOS/Rocky Dependencies"

test_url "http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/libaio-0.3.112-1.el8.x86_64.rpm" "libaio"
test_url "http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/openssl-libs-1.1.1k-9.el8_7.x86_64.rpm" "OpenSSL libs"
test_url "http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/krb5-libs-1.18.2-22.el8_7.x86_64.rpm" "Kerberos libs"
test_url "http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/readline-7.0-10.el8.x86_64.rpm" "readline"
test_url "http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/ncurses-libs-6.1-9.20180224.el8.x86_64.rpm" "ncurses"
test_url "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/unixODBC-2.3.7-1.el8.x86_64.rpm" "CentOS UnixODBC"
test_url "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/python3-pyyaml-3.12-12.el8.x86_64.rpm" "PyYAML"
test_url "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/python3-jinja2-2.10.1-3.el8.noarch.rpm" "Jinja2"
test_url "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/python3-markupsafe-0.23-19.el8.x86_64.rpm" "MarkupSafe"
test_url "http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/python3-cryptography-3.2.1-5.el8.x86_64.rpm" "Cryptography"
test_url "http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/Packages/openssh-clients-8.0p1-13.el8.x86_64.rpm" "OpenSSH clients"

# Summary
print_header "Test Summary"
echo ""
echo "URLs Valid:      $URLS_VALID"
echo "URLs Invalid:    $URLS_INVALID"
echo "URLs Redirected: $URLS_REDIRECTED"
echo ""
echo "Total URLs:      $((URLS_VALID + URLS_INVALID + URLS_REDIRECTED))"
echo ""

if [ $URLS_INVALID -eq 0 ]; then
    echo -e "${GREEN}All URLs are accessible!${NC}"
else
    echo -e "${RED}Some URLs need to be updated. Check log for details.${NC}"
fi

echo ""
echo "Detailed log saved to: $LOG_FILE"
echo "Completed: $(date)"

# Return appropriate exit code
[ $URLS_INVALID -eq 0 ]
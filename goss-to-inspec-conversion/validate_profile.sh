#!/bin/bash

# InSpec Profile Validation Script
# This script validates the InSpec profile for syntax and dependencies

set -e

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROFILE_DIR"

echo "========================================="
echo "InSpec Profile Validation"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        return 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "ℹ $1"
}

# Check if InSpec is installed
echo "Checking prerequisites..."
if ! command -v inspec &> /dev/null; then
    echo -e "${RED}✗ InSpec is not installed${NC}"
    echo "Please install InSpec: https://docs.chef.io/inspec/install/"
    exit 1
fi
print_status 0 "InSpec is installed"

# Check InSpec version
INSPEC_VERSION=$(inspec version | grep -oP 'InSpec version \K[\d.]+')
print_info "InSpec version: $INSPEC_VERSION"

# Check for required tools
echo
echo "Checking required tools..."
command -v az &> /dev/null && print_status 0 "Azure CLI is available" || print_warning "Azure CLI not found - required for cluster validation"
command -v kubectl &> /dev/null && print_status 0 "kubectl is available" || print_warning "kubectl not found - required for Kubernetes validation"
command -v jq &> /dev/null && print_status 0 "jq is available" || print_warning "jq not found - some controls may fail"

echo
echo "Validating InSpec profile..."

# Install/update dependencies first
print_info "Installing/updating InSpec dependencies..."
if inspec vendor --overwrite . &> /dev/null; then
    print_status 0 "Dependencies installed successfully"
else
    print_warning "Failed to install dependencies - this may affect profile validation"
    echo "Running vendor with verbose output:"
    inspec vendor --overwrite .
fi

# Check profile syntax
print_info "Validating profile syntax..."
if inspec check . &> /dev/null; then
    print_status 0 "Profile syntax is valid"
else
    print_status 1 "Profile syntax validation failed"
    echo "Running detailed syntax check:"
    inspec check .
    exit 1
fi

# Verify profile structure
echo
echo "Checking profile structure..."

# Check main files
[ -f "inspec.yml" ] && print_status 0 "inspec.yml exists" || print_status 1 "inspec.yml missing"
[ -d "controls" ] && print_status 0 "controls/ directory exists" || print_status 1 "controls/ directory missing"
[ -d "inputs" ] && print_status 0 "inputs/ directory exists" || print_status 1 "inputs/ directory missing"
[ -d "libraries" ] && print_status 0 "libraries/ directory exists" || print_status 1 "libraries/ directory missing"

# Check input files
echo
echo "Checking input files..."
for env in dev staging prod; do
    if [ -f "inputs/$env.yml" ]; then
        print_status 0 "inputs/$env.yml exists"
        # Basic YAML validation
        if python3 -c "import yaml; yaml.safe_load(open('inputs/$env.yml'))" 2>/dev/null || ruby -ryaml -e "YAML.load_file('inputs/$env.yml')" 2>/dev/null; then
            print_status 0 "inputs/$env.yml is valid YAML"
        else
            print_warning "inputs/$env.yml may have YAML syntax issues"
        fi
    else
        print_warning "inputs/$env.yml not found"
    fi
done

# Check control files
echo
echo "Checking control files..."
CONTROL_COUNT=$(find controls/ -name "*.rb" -type f | wc -l)
if [ $CONTROL_COUNT -gt 0 ]; then
    print_status 0 "Found $CONTROL_COUNT control files"
    
    # Check each control file for basic Ruby syntax
    for control_file in controls/*.rb; do
        if [ -f "$control_file" ]; then
            if ruby -c "$control_file" >/dev/null 2>&1; then
                print_status 0 "$(basename "$control_file") syntax valid"
            else
                print_status 1 "$(basename "$control_file") has syntax errors"
            fi
        fi
    done
else
    print_status 1 "No control files found"
fi

# Check library files
echo
echo "Checking library files..."
if [ -f "libraries/aks_helper.rb" ]; then
    if ruby -c "libraries/aks_helper.rb" >/dev/null 2>&1; then
        print_status 0 "aks_helper.rb syntax valid"
    else
        print_status 1 "aks_helper.rb has syntax errors"
    fi
else
    print_warning "aks_helper.rb library not found"
fi

# Vendor dependencies (if exists)
echo
echo "Checking dependencies..."
if [ -f "inspec.lock" ]; then
    print_info "Found inspec.lock - dependencies have been vendored"
else
    print_info "No inspec.lock found - run 'inspec vendor' to vendor dependencies"
fi

# Test profile execution with dry-run (if input file exists)
echo
echo "Testing profile execution..."
if [ -f "inputs/dev.yml" ]; then
    print_info "Testing profile with dev inputs (dry-run)..."
    if timeout 30 inspec exec . --input-file=inputs/dev.yml --dry-run &> /dev/null; then
        print_status 0 "Profile dry-run successful"
    else
        print_warning "Profile dry-run failed or timed out - this may be expected without proper Azure/K8s access"
    fi
else
    print_warning "No dev input file found for testing"
fi

# Profile summary
echo
echo "========================================="
echo "Profile Summary"
echo "========================================="
print_info "Profile Name: $(grep '^name:' inspec.yml | cut -d' ' -f2)"
print_info "Version: $(grep '^version:' inspec.yml | cut -d' ' -f2)"
print_info "Controls: $CONTROL_COUNT control files"
print_info "Input Files: $(find inputs/ -name "*.yml" -type f 2>/dev/null | wc -l) environment configurations"

echo
echo "========================================="
echo "Validation Complete"
echo "========================================="

# Final recommendations
echo
echo "Recommendations:"
echo "1. Dependencies have been vendored automatically"
echo "2. Update input files with your environment-specific values"
echo "3. Ensure Azure CLI is authenticated: 'az login'"
echo "4. Configure kubectl context for your AKS cluster"
echo "5. Test execution: './run_tests.sh -e dev'"

echo
echo "For detailed usage instructions, see README.md"
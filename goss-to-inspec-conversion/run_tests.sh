#!/bin/bash

# InSpec AKS Compliance Test Execution Script
# This script provides easy execution of the InSpec profile with different options

set -e

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROFILE_DIR"

# Default values
ENVIRONMENT="dev"
OUTPUT_FORMAT="cli"
OUTPUT_FILE=""
CONTROLS=""
VERBOSE=""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV     Environment to test (dev|staging|prod) [default: dev]"
    echo "  -f, --format FORMAT       Output format (cli|html|json|junit) [default: cli]"
    echo "  -o, --output FILE         Output file (required for html|json|junit formats)"
    echo "  -c, --controls PATTERN    Run specific controls matching pattern"
    echo "  -v, --verbose             Verbose output"
    echo "  -d, --dry-run             Perform dry run without executing tests"
    echo "  -l, --list                List all available controls"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                     # Run all tests in dev environment"
    echo "  $0 -e prod                            # Run all tests in prod environment"
    echo "  $0 -c security                        # Run only security controls"
    echo "  $0 -e prod -f html -o report.html     # Generate HTML report for prod"
    echo "  $0 -e staging -f json -o results.json # Generate JSON report for staging"
    echo "  $0 -l                                 # List all controls"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -c|--controls)
            CONTROLS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="--log-level=debug"
            shift
            ;;
        -d|--dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        -l|--list)
            LIST_CONTROLS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# List controls if requested
if [ "$LIST_CONTROLS" = true ]; then
    echo "========================================="
    echo "Available Controls"
    echo "========================================="
    
    if command -v inspec &> /dev/null; then
        inspec exec . --dry-run --input-file=inputs/dev.yml 2>/dev/null | grep -E "Control|Title" || echo "Could not list controls - ensure InSpec is installed and profile is valid"
    else
        echo "InSpec is not available. Here are the control files:"
        find controls/ -name "*.rb" -type f | sort
    fi
    exit 0
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_info "Valid environments: dev, staging, prod"
    exit 1
fi

# Check if input file exists
INPUT_FILE="inputs/$ENVIRONMENT.yml"
if [ ! -f "$INPUT_FILE" ]; then
    print_error "Input file not found: $INPUT_FILE"
    exit 1
fi

# Validate output format
if [[ ! "$OUTPUT_FORMAT" =~ ^(cli|html|json|junit)$ ]]; then
    print_error "Invalid output format: $OUTPUT_FORMAT"
    print_info "Valid formats: cli, html, json, junit"
    exit 1
fi

# Check if output file is required
if [[ "$OUTPUT_FORMAT" != "cli" && -z "$OUTPUT_FILE" ]]; then
    print_error "Output file is required for $OUTPUT_FORMAT format"
    print_info "Use -o option to specify output file"
    exit 1
fi

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v inspec &> /dev/null; then
    print_error "InSpec is not installed"
    print_info "Install InSpec: https://docs.chef.io/inspec/install/"
    exit 1
fi

# Install/update dependencies with force overwrite
print_info "Installing InSpec dependencies..."
if ! inspec vendor --overwrite . &> /dev/null; then
    print_error "InSpec vendor command failed"
    print_info "Running with verbose output for troubleshooting:"
    inspec vendor --overwrite .
    exit 1
fi
print_success "Dependencies installed successfully"

# Validate profile
print_info "Validating InSpec profile..."
if ! inspec check . &> /dev/null; then
    print_error "InSpec profile validation failed"
    print_info "Running check with verbose output for troubleshooting:"
    inspec check .
    exit 1
fi
print_success "Profile validation passed"

# Build InSpec command
INSPEC_CMD="inspec exec ."
INSPEC_CMD+=" --input-file=$INPUT_FILE"
INSPEC_CMD+=" --chef-license=accept-silent"

if [ -n "$CONTROLS" ]; then
    INSPEC_CMD+=" --controls=$CONTROLS"
fi

if [ -n "$VERBOSE" ]; then
    INSPEC_CMD+=" $VERBOSE"
fi

if [ -n "$DRY_RUN" ]; then
    INSPEC_CMD+=" $DRY_RUN"
fi

# Add reporter based on output format
case $OUTPUT_FORMAT in
    cli)
        # Default CLI output
        ;;
    html)
        INSPEC_CMD+=" --reporter=html:$OUTPUT_FILE"
        ;;
    json)
        INSPEC_CMD+=" --reporter=json:$OUTPUT_FILE"
        ;;
    junit)
        INSPEC_CMD+=" --reporter=junit:$OUTPUT_FILE"
        ;;
esac

# Display execution info
echo "========================================="
echo "InSpec AKS Compliance Test Execution"
echo "========================================="
print_info "Environment: $ENVIRONMENT"
print_info "Input File: $INPUT_FILE"
print_info "Output Format: $OUTPUT_FORMAT"
if [ -n "$OUTPUT_FILE" ]; then
    print_info "Output File: $OUTPUT_FILE"
fi
if [ -n "$CONTROLS" ]; then
    print_info "Controls Filter: $CONTROLS"
fi

echo
print_info "Executing command: $INSPEC_CMD"
echo

# Execute InSpec
if eval "$INSPEC_CMD"; then
    EXIT_CODE=0
    echo
    print_success "InSpec execution completed successfully"
    
    if [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
        print_success "Report generated: $OUTPUT_FILE"
        
        # Display file size
        FILE_SIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
        print_info "Report size: $FILE_SIZE"
    fi
else
    EXIT_CODE=$?
    echo
    print_warning "InSpec execution completed with issues (exit code: $EXIT_CODE)"
    
    if [ -n "$OUTPUT_FILE" ] && [ -f "$OUTPUT_FILE" ]; then
        print_info "Report still generated: $OUTPUT_FILE"
    fi
fi

# Summary
echo
echo "========================================="
echo "Execution Summary"
echo "========================================="

case $EXIT_CODE in
    0)
        print_success "All tests passed successfully"
        ;;
    100)
        print_warning "Some tests failed - review the output above"
        ;;
    *)
        print_error "InSpec execution encountered errors"
        ;;
esac

# Additional information
echo
print_info "For detailed analysis:"
if [ "$OUTPUT_FORMAT" = "html" ] && [ -n "$OUTPUT_FILE" ]; then
    print_info "Open HTML report: $OUTPUT_FILE"
elif [ "$OUTPUT_FORMAT" = "json" ] && [ -n "$OUTPUT_FILE" ]; then
    print_info "Process JSON report: $OUTPUT_FILE"
fi

print_info "For help: $0 --help"
print_info "To list controls: $0 --list"

exit $EXIT_CODE
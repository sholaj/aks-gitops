#!/bin/bash

# ASO Infrastructure Compliance Test Runner
# This script provides an easy way to run compliance tests locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
OUTPUT_FORMAT="cli"
REPORT_DIR="reports"
SHOW_HELP=false
VERBOSE=false

# Help function
show_help() {
    echo "ASO Infrastructure Compliance Test Runner"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Target environment (dev, staging, prod) [default: dev]"
    echo "  -f, --format FORMAT      Output format (cli, json, html, all) [default: cli]"
    echo "  -o, --output DIR         Output directory for reports [default: reports]"
    echo "  -c, --controls PATTERN   Run specific controls (e.g., 'aks-*' or 'keyvault-*')"
    echo "  -v, --verbose            Enable verbose output"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e prod -f all                    # Run all tests for production with all output formats"
    echo "  $0 -e dev -c 'aks-*'                 # Run only AKS controls for development"
    echo "  $0 -e staging -f json -o results/    # Run staging tests with JSON output"
    echo ""
    echo "Environment Variables:"
    echo "  AZURE_SUBSCRIPTION_ID    Azure subscription ID (required)"
    echo "  AZURE_RESOURCE_GROUP     Resource group name (overrides input file)"
    echo "  AKS_CLUSTER_NAME         AKS cluster name (overrides input file)"
    echo "  KEY_VAULT_NAME           Key Vault name (overrides input file)"
    echo "  UAMI_NAME                Managed identity name (overrides input file)"
    echo "  VNET_NAME                Virtual network name (overrides input file)"
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
            REPORT_DIR="$2"
            shift 2
            ;;
        -c|--controls)
            CONTROLS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Must be 'dev', 'staging', or 'prod'.${NC}"
    exit 1
fi

# Check prerequisites
echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

# Check if InSpec is installed
if ! command -v inspec &> /dev/null; then
    echo -e "${RED}Error: InSpec is not installed. Please install it first:${NC}"
    echo "  gem install inspec"
    echo "  # or"
    echo "  brew install chef/chef/inspec"
    exit 1
fi

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed. Please install it first:${NC}"
    echo "  https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check Azure authentication
echo -e "${BLUE}🔐 Checking Azure authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not authenticated with Azure. Please run:${NC}"
    echo "  az login"
    exit 1
fi

# Display current Azure context
CURRENT_SUBSCRIPTION=$(az account show --query "name" -o tsv)
echo -e "${GREEN}✅ Authenticated with Azure${NC}"
echo -e "Current subscription: ${YELLOW}$CURRENT_SUBSCRIPTION${NC}"

# Check if InSpec profile is valid
echo -e "${BLUE}🔍 Validating InSpec profile...${NC}"
if ! inspec check . > /dev/null 2>&1; then
    echo -e "${RED}Error: InSpec profile validation failed.${NC}"
    echo "Run 'inspec check .' for details."
    exit 1
fi
echo -e "${GREEN}✅ InSpec profile is valid${NC}"

# Create report directory
mkdir -p "$REPORT_DIR"

# Prepare input file
INPUT_FILE="inputs/${ENVIRONMENT}.yml"
if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}Error: Input file '$INPUT_FILE' not found.${NC}"
    echo "Please create the input file or use environment variables."
    exit 1
fi

echo -e "${GREEN}✅ Using input file: $INPUT_FILE${NC}"

# Prepare InSpec command
INSPEC_CMD="inspec exec . -t azure:// --input-file $INPUT_FILE"

# Add controls filter if specified
if [[ -n "$CONTROLS" ]]; then
    INSPEC_CMD="$INSPEC_CMD --controls '$CONTROLS'"
    echo -e "${BLUE}🎯 Running controls matching: $CONTROLS${NC}"
fi

# Add verbose logging if requested
if [[ "$VERBOSE" == "true" ]]; then
    INSPEC_CMD="$INSPEC_CMD --log-level debug"
fi

# Configure output format
case $OUTPUT_FORMAT in
    cli)
        INSPEC_CMD="$INSPEC_CMD --reporter cli"
        ;;
    json)
        REPORT_FILE="$REPORT_DIR/inspec_${ENVIRONMENT}_report.json"
        INSPEC_CMD="$INSPEC_CMD --reporter json:$REPORT_FILE"
        ;;
    html)
        REPORT_FILE="$REPORT_DIR/inspec_${ENVIRONMENT}_report.html"
        INSPEC_CMD="$INSPEC_CMD --reporter html:$REPORT_FILE"
        ;;
    all)
        JSON_REPORT="$REPORT_DIR/inspec_${ENVIRONMENT}_report.json"
        HTML_REPORT="$REPORT_DIR/inspec_${ENVIRONMENT}_report.html"
        JUNIT_REPORT="$REPORT_DIR/inspec_${ENVIRONMENT}_junit.xml"
        INSPEC_CMD="$INSPEC_CMD --reporter cli json:$JSON_REPORT html:$HTML_REPORT junit2:$JUNIT_REPORT"
        ;;
    *)
        echo -e "${RED}Error: Invalid output format '$OUTPUT_FORMAT'. Must be 'cli', 'json', 'html', or 'all'.${NC}"
        exit 1
        ;;
esac

# Add chef license acceptance
INSPEC_CMD="$INSPEC_CMD --chef-license=accept-silent"

# Display execution info
echo ""
echo -e "${BLUE}🚀 Starting compliance tests...${NC}"
echo -e "Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "Output format: ${YELLOW}$OUTPUT_FORMAT${NC}"
if [[ "$OUTPUT_FORMAT" != "cli" ]]; then
    echo -e "Report directory: ${YELLOW}$REPORT_DIR${NC}"
fi
echo ""

# Execute InSpec tests
echo -e "${BLUE}📋 Executing InSpec compliance tests...${NC}"
echo "Command: $INSPEC_CMD"
echo ""

# Run the tests and capture exit code
set +e
eval $INSPEC_CMD
EXIT_CODE=$?
set -e

# Display results summary
echo ""
echo -e "${BLUE}📊 Test Execution Summary${NC}"
echo "=================================="

case $EXIT_CODE in
    0)
        echo -e "${GREEN}✅ All compliance tests passed!${NC}"
        ;;
    1)
        echo -e "${YELLOW}⚠️  Some tests failed or have findings.${NC}"
        echo -e "Review the output above for details."
        ;;
    100)
        echo -e "${RED}❌ InSpec execution error occurred.${NC}"
        echo -e "Check the error messages above."
        ;;
    *)
        echo -e "${RED}❌ Unexpected exit code: $EXIT_CODE${NC}"
        ;;
esac

# Show report locations if files were generated
if [[ "$OUTPUT_FORMAT" != "cli" ]]; then
    echo ""
    echo -e "${BLUE}📄 Generated Reports:${NC}"
    for report in "$REPORT_DIR"/inspec_${ENVIRONMENT}_*; do
        if [[ -f "$report" ]]; then
            echo -e "  📋 $(basename "$report"): ${YELLOW}$report${NC}"
        fi
    done
fi

# Provide next steps
echo ""
echo -e "${BLUE}💡 Next Steps:${NC}"
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "  • Your infrastructure is compliant! 🎉"
    echo "  • Consider running tests for other environments"
    echo "  • Set up automated testing in CI/CD pipeline"
else
    echo "  • Review failed controls and remediate issues"
    echo "  • Check Azure resource configurations"
    echo "  • Consult the README.md for troubleshooting guidance"
fi

echo ""
echo -e "${BLUE}📚 For more information:${NC}"
echo "  • View detailed documentation: README.md"
echo "  • Check control descriptions in controls/ directory"
echo "  • Review compliance frameworks in files/compliance_baselines.yaml"

exit $EXIT_CODE
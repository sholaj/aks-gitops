#!/bin/bash

# On-Premise MS SQL Server InSpec Compliance Scan
# Assumes InSpec is already installed on the scanning machine

set -e

echo "============================================="
echo "MS SQL Server Compliance Scan - On-Premise"
echo "============================================="
echo ""

# Configuration
MSSQL_HOST="${MSSQL_HOST:-localhost}"
MSSQL_PORT="${MSSQL_PORT:-1433}"
MSSQL_USER="${MSSQL_USER:-test_user}"
MSSQL_PASSWORD="${MSSQL_PASSWORD:-P@ssw0rd}"
MSSQL_DATABASE="${MSSQL_DATABASE:-test_db}"
SCAN_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="./scan-results"
PROFILE_PATH="../mssql/inspec-profiles"

# Create results directory
mkdir -p $RESULTS_DIR

echo "Target Configuration:"
echo "  Host: $MSSQL_HOST:$MSSQL_PORT"
echo "  Database: $MSSQL_DATABASE"
echo "  User: $MSSQL_USER"
echo "  Profile: $PROFILE_PATH"
echo ""

# Test connectivity first
echo "Testing database connectivity..."
/opt/mssql-tools/bin/sqlcmd -S $MSSQL_HOST,$MSSQL_PORT -U $MSSQL_USER -P "$MSSQL_PASSWORD" -d $MSSQL_DATABASE -Q "SELECT 'Connected' AS Status" -h -1 > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Database connection successful"
else
    echo "❌ Database connection failed. Please check your connection parameters."
    exit 1
fi

echo ""
echo "Starting InSpec compliance scan..."
echo "=================================="

# Run InSpec scan with multiple output formats
inspec exec $PROFILE_PATH \
    --input mssql_host=$MSSQL_HOST \
    --input mssql_port=$MSSQL_PORT \
    --input mssql_user=$MSSQL_USER \
    --input mssql_password="$MSSQL_PASSWORD" \
    --input mssql_database=$MSSQL_DATABASE \
    --reporter cli \
    --reporter json:$RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.json \
    --reporter html:$RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.html

SCAN_EXIT_CODE=$?

echo ""
echo "=================================="
echo "Scan Complete!"
echo ""

# Generate summary report
echo "Generating summary report..."
cat > $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt << EOF
MS SQL Server Compliance Scan Summary
=====================================
Scan Date: $(date)
Target: $MSSQL_HOST:$MSSQL_PORT
Database: $MSSQL_DATABASE

Results Files:
- JSON: $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.json
- HTML: $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.html
- Summary: $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt

EOF

# Parse JSON results for summary (if jq is available)
if command -v jq &> /dev/null; then
    echo "Parsing results..."
    
    TOTAL_CONTROLS=$(jq '.profiles[0].controls | length' $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.json)
    PASSED_CONTROLS=$(jq '[.profiles[0].controls[].results[].status | select(. == "passed")] | length' $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.json)
    FAILED_CONTROLS=$(jq '[.profiles[0].controls[].results[].status | select(. == "failed")] | length' $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.json)
    
    cat >> $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt << EOF
Compliance Statistics:
- Total Controls: $TOTAL_CONTROLS
- Passed: $PASSED_CONTROLS
- Failed: $FAILED_CONTROLS
- Success Rate: $(( PASSED_CONTROLS * 100 / (PASSED_CONTROLS + FAILED_CONTROLS) ))%

Control Results:
EOF
    
    # List control results
    jq -r '.profiles[0].controls[] | "- \(.id): \(.results[0].status // "skipped")"' \
        $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.json >> $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt
    
    echo "" >> $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt
    echo "Failed Controls Details:" >> $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt
    jq -r '.profiles[0].controls[] | select(.results[0].status == "failed") | "- \(.id): \(.title)\n  Message: \(.results[0].message)"' \
        $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.json >> $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt 2>/dev/null || echo "  None" >> $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt
else
    echo "Note: Install 'jq' for detailed JSON parsing" >> $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt
fi

echo ""
echo "Summary Report:"
echo "==============="
cat $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt

echo ""
echo "============================================="
echo "Scan Results:"
echo "  - JSON: $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.json"
echo "  - HTML: $RESULTS_DIR/mssql-compliance-$SCAN_TIMESTAMP.html"
echo "  - Summary: $RESULTS_DIR/mssql-compliance-summary-$SCAN_TIMESTAMP.txt"
echo ""

if [ $SCAN_EXIT_CODE -eq 0 ]; then
    echo "✅ Compliance scan completed successfully!"
elif [ $SCAN_EXIT_CODE -eq 100 ]; then
    echo "⚠️  Compliance scan completed with some test failures"
else
    echo "❌ Compliance scan failed with errors"
fi

echo "============================================="

exit $SCAN_EXIT_CODE
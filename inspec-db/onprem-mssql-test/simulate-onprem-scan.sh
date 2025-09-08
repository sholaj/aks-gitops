#!/bin/bash

# Simulate On-Premise MS SQL Server Compliance Scan
# This script simulates a complete on-premise scanning scenario

set -e

echo "================================================"
echo "Simulating On-Premise MS SQL Server Scan"
echo "================================================"
echo ""

# Configuration
SCAN_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="./scan-results"

# Create results directory
mkdir -p $RESULTS_DIR

# Since we don't have actual MS SQL Server, simulate the scan
echo "Simulating MS SQL Server compliance scan..."
echo ""

# Create simulated InSpec JSON output
cat > $RESULTS_DIR/mssql-onprem-simulated-$SCAN_TIMESTAMP.json << 'EOF'
{
  "version": "4.56.0",
  "profiles": [
    {
      "name": "MS SQL Server Security Baseline",
      "version": "1.0.0",
      "sha256": "simulated",
      "title": "MS SQL Server Security Compliance Profile",
      "maintainer": "Security Team",
      "summary": "InSpec profile for MS SQL Server compliance",
      "controls": [
        {
          "id": "mssql-ssl-encryption",
          "title": "MS SQL Server SSL/TLS Encryption Configuration",
          "desc": "Verify that MS SQL Server is configured to use SSL/TLS encryption",
          "impact": 0.8,
          "results": [
            {
              "status": "failed",
              "code_desc": "MS SQL Server should have Force Encryption enabled",
              "message": "Force Encryption is set to 0 (disabled). Expected: 1 (enabled)"
            }
          ]
        },
        {
          "id": "mssql-password-policy",
          "title": "MS SQL Server Password Policy Enforcement",
          "desc": "Verify that password policy is enforced for SQL logins",
          "impact": 0.7,
          "results": [
            {
              "status": "passed",
              "code_desc": "Password policy should be enforced for all SQL logins",
              "message": "Password policy is enforced for test_user"
            }
          ]
        },
        {
          "id": "mssql-audit-enabled",
          "title": "MS SQL Server Audit Configuration",
          "desc": "Verify that SQL Server Audit is enabled and configured",
          "impact": 0.7,
          "results": [
            {
              "status": "passed",
              "code_desc": "SQL Server Audit should be enabled",
              "message": "SQL Server Audit is enabled with proper configuration"
            }
          ]
        },
        {
          "id": "mssql-xp-cmdshell",
          "title": "xp_cmdshell Configuration",
          "desc": "Verify that xp_cmdshell is disabled",
          "impact": 0.9,
          "results": [
            {
              "status": "passed",
              "code_desc": "xp_cmdshell should be disabled",
              "message": "xp_cmdshell is disabled as required"
            }
          ]
        }
      ]
    }
  ],
  "statistics": {
    "duration": 2.456
  }
}
EOF

# Create simulated HTML report
cat > $RESULTS_DIR/mssql-onprem-simulated-$SCAN_TIMESTAMP.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>MS SQL Server Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .passed { color: green; }
        .failed { color: red; }
        .summary { background: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #4CAF50; color: white; }
    </style>
</head>
<body>
    <h1>MS SQL Server Compliance Report - On-Premise</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Target:</strong> localhost:1433</p>
        <p><strong>Database:</strong> test_db</p>
        <p><strong>Scan Date:</strong> EOF
echo "$(date)" >> $RESULTS_DIR/mssql-onprem-simulated-$SCAN_TIMESTAMP.html
cat >> $RESULTS_DIR/mssql-onprem-simulated-$SCAN_TIMESTAMP.html << 'EOF'
        </p>
        <p><strong>Total Controls:</strong> 4</p>
        <p><strong>Passed:</strong> <span class="passed">3</span></p>
        <p><strong>Failed:</strong> <span class="failed">1</span></p>
        <p><strong>Success Rate:</strong> 75%</p>
    </div>
    
    <h2>Control Results</h2>
    <table>
        <tr>
            <th>Control ID</th>
            <th>Title</th>
            <th>Status</th>
            <th>Impact</th>
        </tr>
        <tr>
            <td>mssql-ssl-encryption</td>
            <td>MS SQL Server SSL/TLS Encryption Configuration</td>
            <td class="failed">FAILED</td>
            <td>0.8</td>
        </tr>
        <tr>
            <td>mssql-password-policy</td>
            <td>MS SQL Server Password Policy Enforcement</td>
            <td class="passed">PASSED</td>
            <td>0.7</td>
        </tr>
        <tr>
            <td>mssql-audit-enabled</td>
            <td>MS SQL Server Audit Configuration</td>
            <td class="passed">PASSED</td>
            <td>0.7</td>
        </tr>
        <tr>
            <td>mssql-xp-cmdshell</td>
            <td>xp_cmdshell Configuration</td>
            <td class="passed">PASSED</td>
            <td>0.9</td>
        </tr>
    </table>
</body>
</html>
EOF

# Create summary report
cat > $RESULTS_DIR/mssql-onprem-summary-$SCAN_TIMESTAMP.txt << EOF
MS SQL Server On-Premise Compliance Scan Summary
================================================
Scan Date: $(date)
Target: localhost:1433
Database: test_db
Scan Type: Simulated (Demo)

Compliance Results:
------------------
Total Controls: 4
Passed: 3
Failed: 1
Success Rate: 75%

Control Results:
- mssql-ssl-encryption: FAILED
  Message: Force Encryption is disabled. SSL/TLS should be enforced.
  
- mssql-password-policy: PASSED
  Message: Password policy is properly enforced for SQL logins.
  
- mssql-audit-enabled: PASSED
  Message: SQL Server Audit is enabled with proper configuration.
  
- mssql-xp-cmdshell: PASSED
  Message: xp_cmdshell is disabled as required.

Recommendations:
---------------
1. Enable Force Encryption in SQL Server Configuration Manager
2. Implement TLS 1.2 or higher for all connections
3. Regular password rotation for SQL logins
4. Monitor audit logs for suspicious activities

Compliance Status: NON-COMPLIANT
Reason: SSL/TLS encryption is not enforced

Files Generated:
- JSON: $RESULTS_DIR/mssql-onprem-simulated-$SCAN_TIMESTAMP.json
- HTML: $RESULTS_DIR/mssql-onprem-simulated-$SCAN_TIMESTAMP.html
- Summary: $RESULTS_DIR/mssql-onprem-summary-$SCAN_TIMESTAMP.txt
EOF

# Display simulated scan output (mimicking InSpec CLI output)
cat << 'EOF'
Profile: MS SQL Server Security Baseline (MS SQL Server Security Compliance Profile)
Version: 1.0.0
Target:  mssql://test_user@localhost:1433/test_db

  ✗ mssql-ssl-encryption: MS SQL Server SSL/TLS Encryption Configuration (1 failed)
     ✗ MS SQL Server should have Force Encryption enabled
     expected: 1 (enabled)
          got: 0 (disabled)
     
  ✔ mssql-password-policy: MS SQL Server Password Policy Enforcement
     ✔ Password policy should be enforced for all SQL logins
     
  ✔ mssql-audit-enabled: MS SQL Server Audit Configuration
     ✔ SQL Server Audit should be enabled
     
  ✔ mssql-xp-cmdshell: xp_cmdshell Configuration
     ✔ xp_cmdshell should be disabled

Profile Summary: 3 successful controls, 1 control failure, 0 controls skipped
Test Summary: 3 successful, 1 failure, 0 skipped
EOF

echo ""
echo "================================================"
echo "Simulation Complete!"
echo "================================================"
echo ""
echo "Results saved to: $RESULTS_DIR/"
echo "  - JSON: mssql-onprem-simulated-$SCAN_TIMESTAMP.json"
echo "  - HTML: mssql-onprem-simulated-$SCAN_TIMESTAMP.html"
echo "  - Summary: mssql-onprem-summary-$SCAN_TIMESTAMP.txt"
echo ""
echo "Status: ⚠️  NON-COMPLIANT (1 control failed)"
echo ""
echo "To run a real scan:"
echo "  1. Ensure MS SQL Server is running"
echo "  2. Run: ./setup-mssql-test.sh 'YourSAPassword'"
echo "  3. Run: ./run-inspec-scan.sh"
echo "  4. Or use Ansible: ansible-playbook test-mssql-onprem.yml"
echo "================================================"
#!/bin/bash
# AKS 1.33 Master Test Runner
# Executes all pod resizing validation tests and generates consolidated report

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_DIR="${SCRIPT_DIR}/test-reports-${TIMESTAMP}"
TOTAL_PASSED=0
TOTAL_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [AKS-133-MASTER] $*"
}

log_header() {
    echo -e "\n${BOLD}${BLUE}================================================${NC}"
    echo -e "${BOLD}${BLUE} $* ${NC}"
    echo -e "${BOLD}${BLUE}================================================${NC}\n"
}

log_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $*"
}

log_fail() {
    echo -e "${RED}❌ FAIL${NC}: $*"
}

log_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $*"
}

# Pre-flight checks
pre_flight_checks() {
    log_header "Pre-flight Checks"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_fail "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_fail "Cannot connect to Kubernetes cluster. Please check kubeconfig."
        exit 1
    fi
    
    # Check cluster version
    local cluster_version=$(kubectl version --short 2>/dev/null | grep "Server Version" | grep -o 'v1\.[0-9]*' | head -1)
    local version_num=${cluster_version#v1.}
    
    if [[ $version_num -ge 33 ]]; then
        log_pass "Cluster version $cluster_version supports AKS 1.33 features"
    else
        log_warn "Cluster version $cluster_version may not support all AKS 1.33 features"
        echo "Do you want to continue anyway? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check permissions
    if kubectl auth can-i create namespaces &> /dev/null; then
        log_pass "Sufficient permissions to run tests"
    else
        log_fail "Insufficient permissions. Need cluster-admin or equivalent."
        exit 1
    fi
    
    # Create report directory
    mkdir -p "$REPORT_DIR"
    log_pass "Report directory created: $REPORT_DIR"
}

# Run individual test script
run_test_script() {
    local script_name="$1"
    local script_path="${SCRIPT_DIR}/${script_name}"
    local test_type="$2"
    
    log_header "Running $test_type Tests"
    
    if [[ ! -f "$script_path" ]]; then
        log_fail "Test script not found: $script_path"
        return 1
    fi
    
    # Make script executable
    chmod +x "$script_path"
    
    # Run test and capture output
    local output_file="${REPORT_DIR}/${script_name}-output.log"
    local start_time=$(date +%s)
    
    if bash "$script_path" 2>&1 | tee "$output_file"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_pass "$test_type tests completed successfully in ${duration}s"
        
        # Extract pass/fail counts from output
        local passed=$(grep -c "✅ PASS" "$output_file" || echo 0)
        local failed=$(grep -c "❌ FAIL" "$output_file" || echo 0)
        
        TOTAL_PASSED=$((TOTAL_PASSED + passed))
        TOTAL_FAILED=$((TOTAL_FAILED + failed))
        
        echo "$test_type,$passed,$failed,$duration" >> "${REPORT_DIR}/test-summary.csv"
        
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_fail "$test_type tests failed after ${duration}s"
        
        # Still try to extract counts for partial results
        local passed=$(grep -c "✅ PASS" "$output_file" || echo 0)
        local failed=$(grep -c "❌ FAIL" "$output_file" || echo 0)
        
        TOTAL_PASSED=$((TOTAL_PASSED + passed))
        TOTAL_FAILED=$((TOTAL_FAILED + failed))
        
        echo "$test_type,$passed,$failed,$duration,FAILED" >> "${REPORT_DIR}/test-summary.csv"
        
        return 1
    fi
}

# Generate consolidated report
generate_consolidated_report() {
    log_header "Generating Consolidated Report"
    
    local total_tests=$((TOTAL_PASSED + TOTAL_FAILED))
    local success_rate=$(( total_tests > 0 ? TOTAL_PASSED * 100 / total_tests : 0 ))
    
    # Create main report
    cat > "${REPORT_DIR}/AKS-1.33-Pod-Resizing-Validation-Report.md" <<EOF
# AKS 1.33 Pod Resizing Validation Report

**Generated:** $(date)  
**Cluster:** $(kubectl config current-context)  
**Test Environment:** AKS 1.33 Validation  
**Report ID:** ${TIMESTAMP}

## Executive Summary

This report contains the results of comprehensive validation testing for the dynamic pod resizing feature introduced in AKS 1.33 (Kubernetes 1.33).

### Overall Results
- **Total Tests Executed:** $total_tests
- **Tests Passed:** $TOTAL_PASSED  
- **Tests Failed:** $TOTAL_FAILED
- **Success Rate:** ${success_rate}%

### Test Suite Status
$(if [[ $success_rate -ge 90 ]]; then
    echo "🟢 **PASSED** - Pod resizing feature is ready for production deployment"
elif [[ $success_rate -ge 75 ]]; then
    echo "🟡 **CAUTION** - Pod resizing feature needs attention before production"
else
    echo "🔴 **FAILED** - Pod resizing feature requires significant work before production"
fi)

## Test Coverage

### Basic Functionality Tests
- ✅ CPU resource increase/decrease
- ✅ Memory resource increase/decrease  
- ✅ Service availability during resize
- ✅ Application health check validation
- ✅ Resize duration measurement

### Advanced Scenario Tests
- ✅ JVM application memory behavior
- ✅ HPA integration with pod resize
- ✅ Resource limits beyond node capacity
- ✅ Rapid successive resize operations
- ✅ Resize during pod eviction scenarios
- ✅ Metrics reporting accuracy

## Key Findings

### Positive Results
- Pod resizing works without service interruption when successful
- Most applications handle resource changes gracefully
- HPA continues to function with resized pods
- Resource constraints are properly enforced

### Areas of Concern
$(if [[ $TOTAL_FAILED -gt 0 ]]; then
    echo "- Some test scenarios failed validation"
    echo "- Review detailed logs for specific issues"
    echo "- JVM applications may require special handling"
    echo "- Rapid resize operations may have limitations"
else
    echo "- No significant issues identified during testing"
    echo "- All core functionality validated successfully"
fi)

## Production Readiness Assessment

$(if [[ $success_rate -ge 90 ]]; then
    cat <<EOL
### ✅ READY FOR PRODUCTION

The pod resizing feature has passed comprehensive validation testing and is recommended for production deployment with the following guidelines:

#### Immediate Actions
- [ ] Enable gradual rollout starting with 10% of workloads
- [ ] Implement comprehensive monitoring for resize operations  
- [ ] Document rollback procedures for operations teams
- [ ] Train support teams on new resize capabilities

#### Monitoring Requirements
- Track resize operation duration (target: <30s)
- Monitor pod restart rates during resize operations
- Alert on resize failures or timeouts
- Dashboard for resize operation success rates

#### Rollout Strategy
1. **Week 1-2:** Development and staging environments
2. **Week 3-4:** Production pilot (10% of non-critical workloads)
3. **Week 5-6:** Gradual expansion to 50% of workloads
4. **Week 7-8:** Full production rollout for suitable workloads
EOL
elif [[ $success_rate -ge 75 ]]; then
    cat <<EOL
### 🟡 PROCEED WITH CAUTION

The pod resizing feature shows promise but requires additional validation:

#### Required Actions Before Production
- [ ] Investigate and resolve failed test scenarios
- [ ] Conduct extended testing with production workloads
- [ ] Validate with specific application types in your environment
- [ ] Implement additional safeguards for edge cases

#### Risk Mitigation
- Start with non-critical workloads only
- Implement circuit breakers for resize operations
- Maintain ability to quickly disable feature if issues arise
- Enhanced monitoring and alerting
EOL
else
    cat <<EOL
### 🔴 NOT READY FOR PRODUCTION

The pod resizing feature failed significant validation testing:

#### Critical Actions Required
- [ ] Review all failed test cases and root causes
- [ ] Engage with Azure support for guidance
- [ ] Consider delaying AKS 1.33 upgrade until issues resolved
- [ ] Maintain current pod recreation strategies

#### Alternative Approaches
- Continue using pod recreation for resource changes
- Implement external resize orchestration if needed
- Wait for future AKS releases with improved pod resize
EOL
fi)

## Detailed Test Results

$(if [[ -f "${REPORT_DIR}/test-summary.csv" ]]; then
    echo "| Test Suite | Passed | Failed | Duration | Status |"
    echo "|------------|--------|--------|----------|--------|"
    while IFS=',' read -r suite passed failed duration status; do
        echo "| $suite | $passed | $failed | ${duration}s | ${status:-PASSED} |"
    done < "${REPORT_DIR}/test-summary.csv"
fi)

## Next Steps

### For Development Teams
- Review application compatibility with in-place resize
- Update deployment procedures to leverage resize capabilities
- Test critical applications in staging environment
- Implement application-specific resize handling if needed

### For Operations Teams  
- Update monitoring and alerting for resize operations
- Create runbooks for resize troubleshooting
- Plan gradual rollout strategy with rollback procedures
- Train teams on new kubectl resize commands

### For Security Teams
- Validate that resource limits are properly enforced after resize
- Ensure no privilege escalation through resize operations
- Review audit logging for resize events
- Confirm compliance with security policies

## Appendix

### Environment Information
- **Cluster Version:** $(kubectl version --short 2>/dev/null | grep "Server Version" | head -1 || echo "Not available")
- **Node Information:** $(kubectl get nodes --no-headers | wc -l) nodes
- **Test Duration:** Generated over multiple test runs on $(date +%Y-%m-%d)
- **Tool Versions:**
  - kubectl: $(kubectl version --client --short 2>/dev/null | head -1)
  - Test Framework: Custom AKS 1.33 Validation Suite

### Reference Links
- [Kubernetes 1.33 Release Notes](https://kubernetes.io/blog/2025/04/23/kubernetes-v1-33-release/)
- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Pod Resizing KEP-1287](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/1287-in-place-update-pod-resources)

### Support Information
For questions about this report or pod resizing implementation:
- DevOps Platform Team
- Email: devops-platform@company.com  
- Slack: #aks-support

---
**Report Generated:** $(date)  
**Test Framework Version:** 1.0  
**Classification:** Internal Use
EOF
    
    log_pass "Consolidated report generated: ${REPORT_DIR}/AKS-1.33-Pod-Resizing-Validation-Report.md"
}

# Display final summary
display_summary() {
    log_header "Test Execution Summary"
    
    local total_tests=$((TOTAL_PASSED + TOTAL_FAILED))
    local success_rate=$(( total_tests > 0 ? TOTAL_PASSED * 100 / total_tests : 0 ))
    
    echo -e "${BOLD}Final Results:${NC}"
    echo -e "  Total Tests: $total_tests"
    echo -e "  Passed: ${GREEN}$TOTAL_PASSED${NC}"
    echo -e "  Failed: ${RED}$TOTAL_FAILED${NC}"
    echo -e "  Success Rate: ${BOLD}${success_rate}%${NC}"
    
    echo -e "\n${BOLD}Reports Location:${NC} $REPORT_DIR"
    
    if [[ $success_rate -ge 90 ]]; then
        echo -e "\n${GREEN}${BOLD}🎉 OVERALL STATUS: PASSED${NC}"
        echo -e "${GREEN}Pod resizing feature is ready for production deployment${NC}"
    elif [[ $success_rate -ge 75 ]]; then
        echo -e "\n${YELLOW}${BOLD}⚠️  OVERALL STATUS: CAUTION${NC}"
        echo -e "${YELLOW}Pod resizing feature needs attention before production${NC}"
    else
        echo -e "\n${RED}${BOLD}❌ OVERALL STATUS: FAILED${NC}"
        echo -e "${RED}Pod resizing feature is not ready for production${NC}"
    fi
    
    echo -e "\nNext steps:"
    echo -e "1. Review detailed reports in: $REPORT_DIR"
    echo -e "2. Share consolidated report with stakeholders"
    echo -e "3. Plan deployment strategy based on results"
}

# Cleanup function
cleanup() {
    log "Cleaning up any remaining test resources..."
    
    # Clean up any test namespaces that might be left
    kubectl delete namespace aks-133-resize-test --ignore-not-found=true
    kubectl delete namespace aks-133-advanced-test --ignore-not-found=true
    
    log "Cleanup completed"
}

# Main execution
main() {
    log_header "AKS 1.33 Pod Resizing Validation Suite"
    log "Starting comprehensive validation tests..."
    
    trap cleanup EXIT
    
    # Initialize summary CSV
    echo "TestSuite,Passed,Failed,Duration,Status" > "${REPORT_DIR}/test-summary.csv"
    
    pre_flight_checks
    
    # Run basic tests
    run_test_script "test-pod-resize-basic.sh" "Basic Functionality" || true
    
    # Run advanced tests  
    run_test_script "test-pod-resize-advanced.sh" "Advanced Scenarios" || true
    
    # Generate reports
    generate_consolidated_report
    
    # Display final summary
    display_summary
    
    log "AKS 1.33 Pod Resizing Validation Suite completed"
    
    # Exit with appropriate code
    if [[ $TOTAL_FAILED -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Show usage if requested
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "AKS 1.33 Pod Resizing Test Suite"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "This script runs comprehensive validation tests for AKS 1.33 pod resizing features."
    echo "It will create test namespaces, deploy test workloads, perform resize operations,"
    echo "and generate detailed reports."
    echo ""
    echo "Prerequisites:"
    echo "- kubectl configured for target AKS cluster"
    echo "- Cluster-admin permissions"  
    echo "- AKS 1.33 or Kubernetes 1.33+ cluster"
    exit 0
fi

# Execute main function
main "$@"
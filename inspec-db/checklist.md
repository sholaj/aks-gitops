# NIST Database Scanning - Ansible Migration Technical Delivery Plan

## Executive Summary

This document outlines the technical delivery plan for migrating the existing bash script-based NIST database compliance scanning system to a modern Ansible automation framework. The project will modernize scanning operations for Oracle, MSSQL, and Sybase databases while maintaining full compatibility with existing infrastructure and Splunk integration.

## Project Overview

### Current State

- **Legacy System**: Complex bash scripts (NIST.ksh, NIST_for_db.ksh, test.ksh) managing database compliance scanning
- **Database Platforms**: Oracle 19c, MSSQL 2017, Sybase 16
- **Scanning Framework**: InSpec with Ruby compliance profiles
- **Password Management**: Cloakware/IBM Guardium integration
- **Output**: JSON formatted for Splunk ingestion
- **Parallelism**: Manual control up to 12 concurrent scans

### Target State

- **Modern Automation**: Ansible playbooks replacing bash scripts
- **Decoupled Architecture**: Separate connection testing, scanning, and reporting
- **Enhanced Monitoring**: Comprehensive reporting and error handling
- **Maintained Compatibility**: Same output format, directory structure, and integration points
- **Improved Maintainability**: Version-controlled, modular, testable automation

## Prerequisites and Dependencies

### Infrastructure Requirements

#### Test Environment

- [x] **Test Machine Provided**: Engineering playground server allocated
- [ ] **Network Connectivity**: Ensure test machine can reach target databases
- [ ] **Service Accounts**: Database service accounts with appropriate permissions

#### Software Prerequisites

|Component             |Version     |Installation Path                         |Purpose                     |
|----------------------|------------|------------------------------------------|----------------------------|
|**Ansible**           |2.9+        |`/usr/bin/ansible`                        |Automation orchestration    |
|**InSpec**            |Latest      |`/usr/bin/inspec`                         |Compliance testing framework|
|**Oracle Client**     |19.16.0.0-64|`/tools/ver/oracle-19.16.0.0-64`          |Oracle database connectivity|
|**MSSQL Tools**       |Latest      |`/usr/local/oracle/NIST_FILES/mssql-tools`|MSSQL database connectivity |
|**Sybase Tools**      |OCS-16_0    |`/tools/ver/sybase/OCS-16_0`              |Sybase database connectivity|
|**Cloakware/Guardium**|Current     |`/usr/local/ccms`                         |Password management system  |

#### Directory Structure Prerequisites

```
/usr/local/oracle/NIST_FILES/
├── ORACLE19_ruby/           # Oracle InSpec profiles
├── MSSQL2017_ruby/          # MSSQL InSpec profiles  
├── SYBASE16_ruby/           # Sybase InSpec profiles
├── backup/
│   ├── ORACLENIST/          # Oracle scan results (Splunk pickup)
│   ├── MSSQLNIST/           # MSSQL scan results (Splunk pickup)
│   └── SYBASENIST/          # Sybase scan results (Splunk pickup)
├── inventory_*.txt          # Existing inventory files
└── tnsnames.ora             # Oracle TNS configuration
```

#### Access and Permissions Requirements

|Component                |Access Required                                      |Validation Method         |
|-------------------------|-----------------------------------------------------|--------------------------|
|**Database Connectivity**|Network access to database servers on specified ports|`telnet <server> <port>`  |
|**Cloakware Integration**|Execute permissions on pwEcho.exe                    |`./pwEcho.exe <db> <user>`|
|**InSpec Profiles**      |Read access to Ruby profile directories              |`ls -la */ruby/`          |
|**Log Directories**      |Write permissions to backup directories              |`touch backup/*/test_file`|
|**Service Account**      |Database login credentials via Cloakware             |Test with existing scripts|

### Current System Dependencies

#### Integration Points

- **Splunk Integration**: JSON output format must remain identical
- **Scheduling Systems**: Cron jobs or Jenkins pipelines calling scripts
- **Monitoring Systems**: Log file monitoring and alerting
- **Security Infrastructure**: Cloakware password management integration

## Technical Architecture

### Component Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Ansible       │    │    Database      │    │    Reporting    │
│   Control Node  │───▶│    Targets       │───▶│    & Splunk     │
│                 │    │                  │    │    Integration  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ • Inventory     │    │ • Oracle 19c     │    │ • JSON Output   │
│ • Playbooks     │    │ • MSSQL 2017     │    │ • Log Files     │
│ • Profiles      │    │ • Sybase 16      │    │ • Status Reports│
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Ansible Playbook Architecture

|Playbook                        |Purpose                         |Target Hosts    |Dependencies             |
|--------------------------------|--------------------------------|----------------|-------------------------|
|**convert-sybase-inventory.yml**|Convert text inventories to YAML|localhost       |Existing inventory files |
|**test-oracle-methods.yml**     |Test Oracle connection methods  |oracle_databases|Oracle client, TNS config|
|**test-sybase-methods.yml**     |Test Sybase connection methods  |sybase_databases|Sybase tools, isql       |
|**test-db-connections.yml**     |Unified connection testing      |all databases   |All database clients     |
|**nist-db-scan.yml**            |Execute NIST compliance scans   |all databases   |InSpec, Ruby profiles    |

## Delivery Roadmap

### Phase 1: Environment Setup and Validation (Week 1-2)

#### Week 1: Infrastructure Preparation

**Day 1-2: Environment Assessment**

- [ ] Validate test machine specifications and access
- [ ] Inventory existing software versions and paths
- [ ] Test connectivity to target databases
- [ ] Validate Cloakware integration functionality

**Day 3-4: Software Installation and Configuration**

- [ ] Install Ansible (if not present)
- [ ] Validate InSpec installation and functionality
- [ ] Test database client tools (sqlplus, sqlcmd, isql)
- [ ] Verify Ruby profiles directory structure and content

**Day 5: Baseline Testing**

- [ ] Execute existing bash scripts to establish baseline
- [ ] Document current scan execution times and success rates
- [ ] Capture sample output formats for validation

#### Week 2: Initial Ansible Setup

**Day 1-3: Core Playbook Development**

- [ ] Deploy Ansible configuration and inventory files
- [ ] Configure ansible.cfg with appropriate settings
- [ ] Set up directory structure for playbooks and roles
- [ ] Create initial inventory based on existing text files

**Day 4-5: Basic Connectivity Testing**

- [ ] Deploy and execute connection testing playbooks
- [ ] Validate Oracle, MSSQL, and Sybase connectivity
- [ ] Document any connection issues and resolutions
- [ ] Create connectivity baseline report

### Phase 2: Database-Specific Testing and Validation (Week 3-4)

#### Week 3: Platform-Specific Testing

**Day 1-2: Oracle Testing**

- [ ] Execute test-oracle-methods.yml playbook
- [ ] Validate all three Oracle connection methods
- [ ] Test TNS_ADMIN configuration and tnsnames.ora integration
- [ ] Document recommended Oracle connection patterns

**Day 3-4: Sybase Testing**

- [ ] Execute test-sybase-methods.yml playbook
- [ ] Test both Server:Port and Server-only connection formats
- [ ] Validate isql functionality across all Sybase instances
- [ ] Create Sybase-specific troubleshooting guide

**Day 5: MSSQL Testing**

- [ ] Execute MSSQL connection tests
- [ ] Validate sqlcmd functionality and authentication
- [ ] Test connection to all MSSQL instances in inventory
- [ ] Document any MSSQL-specific requirements

#### Week 4: Inventory Management and Conversion

**Day 1-2: Inventory Conversion**

- [ ] Test convert-sybase-inventory.yml with actual files
- [ ] Validate conversion accuracy and completeness
- [ ] Create standardized inventory format documentation
- [ ] Develop inventory management procedures

**Day 3-5: Integration Testing**

- [ ] Execute unified test-db-connections.yml across all platforms
- [ ] Validate parallel execution and performance
- [ ] Compare results with bash script baseline
- [ ] Create comprehensive connectivity report

### Phase 3: NIST Scanning Implementation (Week 5-6)

#### Week 5: Core Scanning Functionality

**Day 1-3: InSpec Integration**

- [ ] Deploy nist-db-scan.yml playbook
- [ ] Test InSpec execution for each database platform
- [ ] Validate Ruby profile loading and execution
- [ ] Verify JSON output format matches existing structure

**Day 4-5: Parallelism and Performance**

- [ ] Test parallel execution with various parallelism settings
- [ ] Compare scan execution times with bash scripts
- [ ] Optimize performance and resource utilization
- [ ] Validate timeout handling and error recovery

#### Week 6: Output and Integration Validation

**Day 1-2: Splunk Integration Testing**

- [ ] Validate JSON output format compatibility
- [ ] Test file placement in Splunk pickup directories
- [ ] Verify timestamp and metadata formatting
- [ ] Compare Splunk ingestion with baseline

**Day 3-4: Error Handling and Reporting**

- [ ] Test failure scenarios and error recovery
- [ ] Validate comprehensive error reporting
- [ ] Test retry mechanisms and timeout handling
- [ ] Create operational runbooks

**Day 5: Performance and Scale Testing**

- [ ] Execute full-scale scanning across all databases
- [ ] Measure and document performance metrics
- [ ] Validate system resource utilization
- [ ] Create capacity planning recommendations

### Phase 4: Production Readiness and Handover (Week 7-8)

#### Week 7: Documentation and Training

**Day 1-2: Technical Documentation**

- [ ] Complete README.md with operational procedures
- [ ] Create troubleshooting and maintenance guides
- [ ] Document backup and recovery procedures
- [ ] Create change management procedures

**Day 3-4: Operational Training**

- [ ] Train SRE team on new Ansible procedures
- [ ] Create operational checklists and procedures
- [ ] Document monitoring and alerting requirements
- [ ] Establish support procedures

**Day 5: Migration Planning**

- [ ] Create detailed migration plan from bash to Ansible
- [ ] Define rollback procedures
- [ ] Plan parallel operation period
- [ ] Create go-live checklist

#### Week 8: Final Validation and Handover

**Day 1-3: Production Simulation**

- [ ] Execute full production simulation
- [ ] Validate all monitoring and alerting
- [ ] Test backup and recovery procedures
- [ ] Complete final performance validation

**Day 4-5: Project Handover**

- [ ] Complete all documentation handover
- [ ] Conduct final training and knowledge transfer
- [ ] Establish ongoing support procedures
- [ ] Create post-implementation review plan

## Risk Assessment and Mitigation

### Technical Risks

|Risk                             |Impact|Probability|Mitigation Strategy                                            |
|---------------------------------|------|-----------|---------------------------------------------------------------|
|**Database Connectivity Issues** |High  |Medium     |Comprehensive connection testing, multiple connection methods  |
|**InSpec Profile Compatibility** |Medium|Low        |Validate existing profiles, maintain Ruby version compatibility|
|**Cloakware Integration Failure**|High  |Low        |Test thoroughly, maintain existing pwEcho.exe integration      |
|**Performance Degradation**      |Medium|Medium     |Benchmark against existing scripts, optimize parallelism       |
|**Splunk Integration Issues**    |Medium|Low        |Maintain identical JSON format, validate field mappings        |

### Operational Risks

|Risk                    |Impact|Probability|Mitigation Strategy                                      |
|------------------------|------|-----------|---------------------------------------------------------|
|**Staff Learning Curve**|Medium|Medium     |Comprehensive training, documentation, gradual transition|
|**Rollback Complexity** |High  |Low        |Maintain parallel operation, clear rollback procedures   |
|**Schedule Delays**     |Medium|Medium     |Phased approach, early risk identification, buffer time  |
|**Resource Constraints**|Medium|Medium     |Early resource allocation, stakeholder communication     |

## Success Criteria and Acceptance Testing

### Functional Requirements

- [ ] **Database Connectivity**: All databases connect successfully using Ansible playbooks
- [ ] **Scan Execution**: All InSpec profiles execute successfully with identical results
- [ ] **Output Format**: JSON output matches existing format exactly
- [ ] **Performance**: Scan execution time within 10% of bash script baseline
- [ ] **Parallelism**: Support for configurable parallel execution up to 12 concurrent scans

### Non-Functional Requirements

- [ ] **Reliability**: 99.5% successful scan execution rate
- [ ] **Maintainability**: Modular, documented, version-controlled codebase
- [ ] **Monitoring**: Comprehensive logging and error reporting
- [ ] **Security**: No degradation of existing security controls
- [ ] **Scalability**: Easy addition of new databases and platforms

### Integration Requirements

- [ ] **Cloakware**: Seamless password retrieval integration
- [ ] **Splunk**: Identical log ingestion and parsing
- [ ] **Scheduling**: Compatible with existing cron/Jenkins integration
- [ ] **Directory Structure**: Maintains existing file organization

## Post-Implementation Plan

### Monitoring and Maintenance

- **Daily**: Automated scan execution monitoring
- **Weekly**: Performance metrics review and capacity planning
- **Monthly**: Playbook updates and security patches
- **Quarterly**: Full system health check and optimization

### Continuous Improvement

- **Feedback Collection**: Regular feedback from SRE and operations teams
- **Performance Optimization**: Ongoing performance tuning and enhancement
- **Feature Enhancement**: Addition of new features and capabilities based on requirements
- **Security Updates**: Regular security reviews and updates

### Knowledge Management

- **Documentation**: Maintain up-to-date operational documentation
- **Training**: Regular training updates and knowledge sharing sessions
- **Best Practices**: Develop and maintain Ansible best practices documentation
- **Lessons Learned**: Document and share lessons learned from implementation

## Conclusion

This technical delivery plan provides a comprehensive roadmap for migrating NIST database compliance scanning from bash scripts to Ansible automation. The phased approach ensures thorough testing, validation, and risk mitigation while maintaining operational continuity. The 8-week timeline allows for comprehensive implementation with appropriate testing and validation at each phase.

The plan addresses all technical prerequisites, provides detailed implementation steps, and establishes clear success criteria. With proper execution of this plan, the organization will have a modern, maintainable, and scalable database compliance scanning solution that maintains full compatibility with existing infrastructure while providing enhanced operational capabilities.
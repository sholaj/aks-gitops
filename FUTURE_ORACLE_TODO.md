# Oracle Database InSpec Implementation - TODO

## Overview
Future implementation to extend the current MSSQL InSpec solution to support Oracle databases, following the same modular Ansible approach.

## 📋 Implementation Tasks

### 1. **Create Oracle Ansible Role** (`oracle_inspec/`)
- [ ] **Role Structure**:
  ```
  oracle_inspec/
  ├── tasks/
  │   ├── main.yml                 # Main orchestration
  │   ├── validate.yml             # Oracle-specific validation
  │   ├── setup.yml                # Oracle environment setup
  │   ├── execute.yml              # Oracle InSpec execution
  │   ├── cleanup.yml              # Cleanup and reporting
  │   ├── process_results.yml      # Oracle result processing
  │   └── splunk_integration.yml   # Splunk forwarding
  ├── defaults/main.yml            # Oracle default variables
  ├── vars/main.yml                # Oracle role variables
  ├── files/                       # Oracle InSpec controls
  │   ├── ORACLE11g_ruby/
  │   ├── ORACLE12c_ruby/
  │   ├── ORACLE18c_ruby/
  │   └── ORACLE19c_ruby/
  └── README.md
  ```

### 2. **Oracle-Specific Variables**
- [ ] **Connection Parameters**:
  ```yaml
  oracle_server: ""
  oracle_port: 1521
  oracle_database: ""          # Oracle SID or Service Name
  oracle_service: ""           # TNS Service Name
  oracle_version: ""           # 11g, 12c, 18c, 19c
  oracle_username: ""
  oracle_password: "{{ lookup('vars', 'vault_' + oracle_host_id + '_password') }}"
  ```

### 3. **Oracle InSpec Controls**
- [ ] **Version-Specific Control Directories**:
  - `ORACLE11g_ruby/` - Oracle 11g compliance controls
  - `ORACLE12c_ruby/` - Oracle 12c compliance controls
  - `ORACLE18c_ruby/` - Oracle 18c compliance controls
  - `ORACLE19c_ruby/` - Oracle 19c compliance controls

- [ ] **Sample Oracle InSpec Control** (`trusted.rb`):
  ```ruby
  # Oracle InSpec Control Example
  oracle = oracle_session(
    user: attribute('usernm'),
    password: attribute('passwd'),
    host: attribute('hostnm'),
    port: attribute('port'),
    service: attribute('servicenm')
  )

  control 'oracle-01' do
    impact 1.0
    title 'Ensure Oracle audit trail is enabled'
    desc 'Oracle database should have audit trail enabled'

    describe oracle.query("SELECT value FROM v$parameter WHERE name = 'audit_trail'") do
      its('rows.first.VALUE') { should_not eq 'NONE' }
    end
  end
  ```

### 4. **Update Converter Script**
- [ ] **Flat File Format Support**:
  ```
  ORACLE server.com ORCL XE 1521 19c [username] [password]
  ```

- [ ] **Inventory Generation**:
  - Add Oracle hosts to `oracle_databases` group
  - Generate Oracle-specific host variables
  - Create Oracle vault password references

### 5. **Oracle Playbook** (`run_oracle_inspec.yml`)
- [ ] **Playbook Structure**:
  ```yaml
  - name: Execute InSpec Oracle Compliance Scans
    hosts: oracle_databases
    roles:
      - oracle_inspec
  ```

### 6. **Oracle-Specific Considerations**
- [ ] **TNS Connection Handling**:
  - Support for TNS_ADMIN environment variable
  - Service name vs SID connection options
  - SSL/TLS connection support

- [ ] **Oracle Version Detection**:
  - Automatic version detection from database
  - Version-specific control selection
  - Compatibility matrix documentation

- [ ] **Oracle Permissions**:
  - Required Oracle user privileges
  - Read-only scanning account setup
  - DBA vs limited user access controls

### 7. **File Naming Compatibility**
- [ ] **Original Script Pattern**:
  ```
  ORACLE_NIST_{PID}_{SERVER}_{DB}_{VERSION}_{TIMESTAMP}_{CONTROL}.json
  ```

### 8. **Testing & Validation**
- [ ] **Test Environments**:
  - Oracle 11g test instance
  - Oracle 12c test instance
  - Oracle 18c/19c test instances

- [ ] **Integration Testing**:
  - Connection validation
  - Control execution verification
  - Result format validation
  - Error handling verification

## 🔗 Dependencies

### Technical Requirements
- Oracle Instant Client libraries
- InSpec Oracle resource pack
- Oracle database connectivity
- Appropriate Oracle user privileges

### Documentation Requirements
- Oracle-specific setup guide
- Connection troubleshooting guide
- Oracle user privilege requirements
- Version compatibility matrix

## 📋 Acceptance Criteria

- [ ] Oracle role follows same modular structure as MSSQL role
- [ ] Supports multiple Oracle versions (11g, 12c, 18c, 19c)
- [ ] File naming matches original script pattern
- [ ] Error handling matches original script behavior
- [ ] Integration with existing inventory/vault structure
- [ ] AAP compatibility maintained
- [ ] Splunk integration functional
- [ ] Documentation complete and tested

## ⚡ Implementation Priority

**Phase 1**: Core Oracle role and basic connectivity
**Phase 2**: Version-specific controls and validation
**Phase 3**: Advanced features (SSL, TNS, clustering)
**Phase 4**: Testing and documentation completion

## 🎯 Success Metrics

1. **Functional**: Successfully scan Oracle databases with same reliability as MSSQL
2. **Compatible**: Seamless integration with existing inventory and vault structure
3. **Scalable**: Handle multiple Oracle databases in parallel
4. **Maintainable**: Clear, documented, modular code structure
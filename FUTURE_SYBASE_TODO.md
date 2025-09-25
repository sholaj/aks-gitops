# Sybase Database InSpec Implementation - TODO

## Overview
Future implementation to extend the current MSSQL InSpec solution to support Sybase databases, including the SSH connection handling found in the original script.

## 📋 Implementation Tasks

### 1. **Create Sybase Ansible Role** (`sybase_inspec/`)
- [ ] **Role Structure**:
  ```
  sybase_inspec/
  ├── tasks/
  │   ├── main.yml                 # Main orchestration
  │   ├── validate.yml             # Sybase-specific validation
  │   ├── setup.yml                # Sybase environment setup
  │   ├── execute.yml              # Sybase InSpec execution (with SSH)
  │   ├── cleanup.yml              # Cleanup and reporting
  │   ├── process_results.yml      # Sybase result processing
  │   ├── ssh_setup.yml            # SSH connection handling
  │   └── splunk_integration.yml   # Splunk forwarding
  ├── defaults/main.yml            # Sybase default variables
  ├── vars/main.yml                # Sybase role variables
  ├── files/                       # Sybase InSpec controls
  │   ├── SYBASE15_ruby/
  │   ├── SYBASE16_ruby/
  │   └── SSH_keys/                # SSH key management
  └── README.md
  ```

### 2. **SSH Connection Handling** (Critical Sybase Feature)
- [ ] **SSH Configuration Tasks** (`ssh_setup.yml`):
  ```yaml
  # Based on original script SSH logic:
  # --ssh://oracle:edcp!cv0576@ -o oracle/.ssh/authorized_keys

  - name: Setup SSH connection for Sybase InSpec
    block:
      - name: Ensure SSH keys directory exists
      - name: Copy SSH private key for Sybase connection
      - name: Set correct permissions on SSH key
      - name: Test SSH connectivity to Sybase host
      - name: Setup authorized_keys if needed
  ```

- [ ] **SSH Variables**:
  ```yaml
  sybase_ssh_user: "oracle"          # SSH user for connection
  sybase_ssh_key_path: ""            # Path to SSH private key
  sybase_ssh_port: 22                # SSH port
  sybase_use_ssh: true               # Enable SSH for Sybase (default)
  sybase_ssh_options: ""             # Additional SSH options
  ```

### 3. **Sybase-Specific Variables**
- [ ] **Connection Parameters**:
  ```yaml
  sybase_server: ""
  sybase_port: 5000                # Default Sybase port
  sybase_database: ""              # Sybase database name
  sybase_service: ""               # Sybase service name (e.g., SAP_ASE)
  sybase_version: ""               # 15.0, 16.0, etc.
  sybase_username: ""
  sybase_password: "{{ lookup('vars', 'vault_' + sybase_host_id + '_password') }}"

  # SSH-specific variables
  sybase_ssh_enabled: true
  sybase_ssh_user: "oracle"
  sybase_ssh_key: ""
  ```

### 4. **Modified InSpec Execution**
- [ ] **SSH InSpec Command** (from original script):
  ```bash
  # Original: /usr/bin/inspec exec $ruby_dir/$g_file
  #   --ssh://oracle:edcp!cv0576@ -o oracle/.ssh/authorized_keys
  #   --input usernm=$user passwd=$dbpwd hostnm=$servernm servicenm=$servicenm port=$portnum
  ```

- [ ] **Ansible Implementation**:
  ```yaml
  - name: Execute InSpec controls via SSH for Sybase
    shell: |
      /usr/bin/inspec exec {{ item.path }} \
        --ssh://{{ sybase_ssh_user }}:{{ sybase_ssh_password }}@{{ sybase_server }} \
        -o {{ sybase_ssh_key_path }} \
        --input usernm={{ sybase_username }} \
                passwd={{ sybase_password }} \
                hostnm={{ sybase_server }} \
                servicenm={{ sybase_service }} \
                port={{ sybase_port }} \
        --reporter=json-min \
        --no-color
  ```

### 5. **Sybase InSpec Controls**
- [ ] **Version-Specific Control Directories**:
  - `SYBASE15_ruby/` - Sybase ASE 15.x compliance controls
  - `SYBASE16_ruby/` - Sybase ASE 16.x compliance controls

- [ ] **Sample Sybase InSpec Control** (`trusted.rb`):
  ```ruby
  # Sybase InSpec Control Example
  # Note: May need custom InSpec resource for Sybase

  control 'sybase-01' do
    impact 1.0
    title 'Ensure Sybase server audit is enabled'
    desc 'Sybase ASE should have auditing enabled'

    describe command("isql -U#{attribute('usernm')} -P#{attribute('passwd')} -S#{attribute('servicenm')} -w999 <<< 'select @@servername go'") do
      its('exit_status') { should eq 0 }
    end
  end
  ```

### 6. **SSH Key Management**
- [ ] **SSH Key Tasks**:
  ```yaml
  # SSH key handling for Sybase connections
  - name: Deploy SSH private key for Sybase access
    copy:
      content: "{{ vault_sybase_ssh_private_key }}"
      dest: "/tmp/sybase_ssh_key"
      mode: '0600'
    no_log: true

  - name: Setup SSH authorized_keys on target
    authorized_key:
      user: "{{ sybase_ssh_user }}"
      key: "{{ sybase_ssh_public_key }}"
      state: present
    delegate_to: "{{ sybase_server }}"
  ```

### 7. **Update Converter Script**
- [ ] **Flat File Format Support**:
  ```
  SYBASE sybserver.com master SAP_ASE 5000 16.0 [username] [password]
  ```

- [ ] **SSH Configuration in Inventory**:
  ```yaml
  sybase_databases:
    hosts:
      sybserver_com_master_5000:
        sybase_server: sybserver.com
        sybase_port: 5000
        sybase_service: SAP_ASE
        sybase_ssh_enabled: true
        sybase_ssh_user: oracle
  ```

### 8. **Sybase Playbook** (`run_sybase_inspec.yml`)
- [ ] **SSH Pre-tasks**:
  ```yaml
  - name: Execute InSpec Sybase Compliance Scans
    hosts: sybase_databases
    pre_tasks:
      - name: Validate SSH connectivity
        include_tasks: validate_ssh.yml
    roles:
      - sybase_inspec
  ```

### 9. **Security Considerations**
- [ ] **SSH Key Security**:
  - Vault-encrypted SSH private keys
  - Temporary key deployment
  - Key cleanup after execution
  - SSH agent forwarding options

- [ ] **Network Security**:
  - SSH port configuration
  - Jump host/bastion support
  - Network ACL validation
  - SSH host key verification

### 10. **File Naming Compatibility**
- [ ] **Original Script Pattern**:
  ```
  SYBASE_NIST_{PID}_{SERVER}_{DB}_{VERSION}_{TIMESTAMP}_{CONTROL}.json
  ```

### 11. **Testing & Validation**
- [ ] **SSH Connectivity Tests**:
  - SSH key authentication
  - SSH connection validation
  - Network reachability
  - Permission verification

- [ ] **Sybase Database Tests**:
  - Database connectivity via SSH
  - InSpec control execution
  - Result format validation
  - Error handling verification

## 🔗 Dependencies

### Technical Requirements
- SSH client capabilities on Ansible control node
- Network connectivity to Sybase servers via SSH
- SSH key pair generation and management
- Sybase client tools (isql, etc.)
- Custom InSpec resources for Sybase (may need development)

### Security Requirements
- SSH key management and vault storage
- Network security policies for SSH access
- Sybase database user permissions
- SSH user account on Sybase servers

## 📋 Acceptance Criteria

- [ ] SSH connectivity established and validated
- [ ] InSpec executes successfully via SSH tunnel
- [ ] File naming matches original script pattern
- [ ] SSH keys properly managed and secured
- [ ] Error handling for SSH failures
- [ ] Integration with existing inventory structure
- [ ] AAP compatibility with SSH credential management
- [ ] Documentation for SSH setup and troubleshooting

## ⚠️ Special Challenges

### 1. **SSH Complexity**
- SSH key distribution and management
- SSH connection reliability and error handling
- Network firewall and security considerations

### 2. **InSpec Sybase Support**
- Limited InSpec resources for Sybase
- May require custom resource development
- Connection string complexity

### 3. **Original Script SSH Logic**
- Understanding the exact SSH command structure
- Replicating authorized_keys handling
- Password vs key authentication

## ⚡ Implementation Priority

**Phase 1**: SSH connection establishment and testing
**Phase 2**: Basic Sybase InSpec control execution
**Phase 3**: Full integration with inventory/vault structure
**Phase 4**: Advanced SSH features and error handling
**Phase 5**: Testing and documentation completion

## 🎯 Success Metrics

1. **Connectivity**: Reliable SSH connections to Sybase servers
2. **Functionality**: Successful InSpec execution via SSH
3. **Security**: Proper SSH key management and vault integration
4. **Compatibility**: Seamless integration with existing architecture
5. **Reliability**: Robust error handling for network/SSH failures
# Original Bash Script Analysis - Credential Handling

## Key Finding: NO CREDENTIALS IN FLAT FILE

The original `NIST_for_db.ksh` script does **NOT** expect username/password in the flat file. Here's the actual flow:

## Script Parameters (from flat file)
```bash
platform=$1    # PLATFORM (MSSQL/ORACLE/SYBASE)
servernm=$2    # SERVER_NAME
dbname=$3      # DATABASE_NAME
servicenm=$4   # SERVICE_NAME
portnum=$5     # PORT_NUMBER
dbversion=$6   # DB_VERSION
```

## Actual Flat File Format
```
PLATFORM SERVER_NAME DB_NAME SERVICE_NAME PORT VERSION
MSSQL m02dsm3 m02dsm3 BIRS_Confidential 1733 2017
```
**NO USERNAME OR PASSWORD!**

## Credential Retrieval Logic

### 1. Username Source
- `$user` variable is **predefined** (likely `dbmaint` or similar service account)
- **NOT** from flat file
- Appears to be environment variable or script constant

### 2. Password Retrieval
```bash
# External password retrieval system
dbpwd=$(${PW_DIR}/pwEcho.exe $dbname $user)
if [ $? -ne 0 ]; then
  dbpwd="NA"
fi
```

**Key Points:**
- Uses external binary: `${PW_DIR}/pwEcho.exe`
- Password lookup by: `$dbname` and `$user`
- If retrieval fails: `dbpwd="NA"`

### 3. Error Handling for Missing Passwords
```bash
if [ "$dbpwd" = "NA" ]; then
  pwdgood=0    # Password retrieval failed
else
  pwdgood=1    # Password retrieved successfully
fi
```

### 4. Execution Logic
- **If password good (`pwdgood=1`)**: Execute InSpec with retrieved credentials
- **If password bad (`pwdgood=0`)**: Generate "Cloakware unreachable" error JSON

## Impact on Ansible Implementation

### Current Problem
Our converter assumes credentials are in flat file:
```python
# WRONG ASSUMPTION
if len(parts) >= 7:
    parsed['username'] = parts[6]
if len(parts) >= 8:
    parsed['password'] = ' '.join(parts[7:])
```

### Correct Implementation Should:

1. **Flat file contains only 6 fields**:
   ```
   PLATFORM SERVER DB SERVICE PORT VERSION
   ```

2. **Username comes from configuration**:
   - Default service account (e.g., `dbmaint`, `nist_scan_user`)
   - Could be per-platform or global

3. **Password comes from external system**:
   - Vault lookup by database name
   - External secret management system
   - Cloakware/CyberArk integration

4. **Error handling for password failures**:
   - Generate "unreachable" JSON when password lookup fails
   - Don't attempt InSpec execution

## Recommended Ansible Approach

### 1. Simplified Flat File
```
# Only 6 fields - no credentials
MSSQL m02dsm3 m02dsm3 BIRS_Confidential 1733 2017
ORACLE oraserver ORCL XE 1521 19c
```

### 2. Username Configuration
```yaml
# In group_vars or inventory
default_db_username: dbmaint
platform_usernames:
  mssql: dbmaint
  oracle: dbmaint
  sybase: dbmaint
```

### 3. Password Lookup Strategy
```yaml
# Option A: Vault by database name
mssql_password: "{{ lookup('vars', 'vault_' + mssql_database + '_password') }}"

# Option B: External secret system
mssql_password: "{{ lookup('cyberark', mssql_database + '_' + mssql_username) }}"

# Option C: Cloakware integration
mssql_password: "{{ lookup('shell', pwecho_path + ' ' + mssql_database + ' ' + mssql_username) }}"
```

### 4. Error Handling
```yaml
- name: Check if password retrieval succeeded
  set_fact:
    password_available: "{{ mssql_password != 'NA' and mssql_password != '' }}"

- name: Generate Cloakware unreachable error
  copy:
    content: |
      {"controls":[{"id":"Not able to retrieve Cloakware Password for DBMAINT Account","status":"Unreachable"}]}
    dest: "{{ results_dir }}/unreachable.json"
  when: not password_available
```

## Summary

The original script uses:
- **6-field flat file** (no credentials)
- **Predefined username** (service account)
- **External password retrieval** (pwEcho.exe/Cloakware)
- **Graceful handling** of password failures

Our Ansible implementation should mirror this pattern, not assume credentials are in the flat file.
# Database Team Integration Guide

## Overview
The MSSQL InSpec compliance scanning solution requires database passwords to be provided separately from the flat file inventory. This document explains how the DB team should provide passwords for integration.

## Flat File Format (No Credentials)
The flat file contains **only 6 fields** - no usernames or passwords:

```
PLATFORM SERVER_NAME DB_NAME SERVICE_NAME PORT VERSION
MSSQL m02dsm3 m02dsm3 BIRS_Confidential 1733 2017
MSSQL sqlserver01 production_db null 1433 2019
```

## Password Integration Options

### Option 1: Manual Vault File Update (Recommended for POC)

1. **Conversion generates vault template**:
   ```bash
   ./convert_flatfile_to_inventory.py -i databases.txt -o inventory.yml --vault-template vault.yml
   ```

2. **Vault file contains placeholders**:
   ```yaml
   ---
   vault_m02dsm3_m02dsm3_1733_password: DB_TEAM_TO_PROVIDE
   vault_sqlserver01_production_db_1433_password: DB_TEAM_TO_PROVIDE
   ```

3. **DB team updates with actual passwords**:
   ```yaml
   ---
   vault_m02dsm3_m02dsm3_1733_password: "ActualPassword123!"
   vault_sqlserver01_production_db_1433_password: "ProdPassword456!"
   ```

4. **Encrypt the vault file**:
   ```bash
   ansible-vault encrypt vault.yml --vault-password-file .vaultpass
   ```

### Option 2: Script-Based Password Injection

Create a script that DB team can run to populate passwords:

```bash
#!/bin/bash
# update_passwords.sh - DB team password injection script

VAULT_FILE="vault.yml"
TEMP_FILE=$(mktemp)

# Decrypt vault file
ansible-vault decrypt $VAULT_FILE --vault-password-file .vaultpass --output $TEMP_FILE

# Update passwords (DB team adds their logic here)
sed -i 's/vault_m02dsm3_m02dsm3_1733_password: DB_TEAM_TO_PROVIDE/vault_m02dsm3_m02dsm3_1733_password: "ActualPassword123!"/' $TEMP_FILE

# Re-encrypt vault file
ansible-vault encrypt $TEMP_FILE --vault-password-file .vaultpass --output $VAULT_FILE

# Clean up
rm $TEMP_FILE
```

### Option 3: External Secret Management Integration

For production environments, integrate with existing secret management:

```yaml
# In group_vars/mssql_databases/main.yml
mssql_password: "{{ lookup('cyberark', mssql_database + '_' + mssql_username) }}"
# or
mssql_password: "{{ lookup('hashivault', 'secret/databases/' + mssql_database) }}"
# or
mssql_password: "{{ lookup('shell', '/opt/scripts/get_db_password.sh ' + mssql_database + ' ' + mssql_username) }}"
```

## Password Naming Convention

**Pattern**: `vault_{server}_{database}_{port}_password`

**Examples**:
- `vault_m02dsm3_m02dsm3_1733_password`
- `vault_sqlserver01_production_db_1433_password`
- `vault_dbserver_example_com_finance_db_1433_password`

**Rules**:
- Dots (.) become underscores (_)
- Hyphens (-) become underscores (_)
- All lowercase
- Special characters removed

## Service Account Information

**Default Username**: `nist_scan_user` (configurable)

**Required Permissions**:
- `CONNECT` to database
- `VIEW SERVER STATE` (for sys.configurations queries)
- `VIEW ANY DEFINITION` (for metadata queries)
- **READ-ONLY** access (no write permissions needed)

## Integration Workflow

1. **Security team** provides flat file with database connection details
2. **Conversion script** generates inventory and vault template
3. **DB team** updates vault with actual passwords
4. **Security team** encrypts vault and runs compliance scans
5. **Results** generated in JSON format for analysis

## Security Considerations

1. **Vault Encryption**: Always encrypt vault files before committing
2. **Access Control**: Limit access to vault files and passwords
3. **Rotation**: Regular password rotation for scanning accounts
4. **Monitoring**: Audit scanning account activity
5. **Least Privilege**: Grant only necessary permissions to scanning accounts

## Troubleshooting

### Password Lookup Failures
If password lookup fails, the system will:
- Generate "Unreachable" status in results
- Continue scanning other databases
- Log the failure for investigation

### Common Issues
- **Incorrect password format**: Ensure passwords are properly quoted in YAML
- **Missing vault variables**: Verify all placeholders are replaced
- **Permission issues**: Check scanning account permissions
- **Network connectivity**: Verify firewall and network access

## Support Contacts

- **Security Team**: For compliance scanning issues
- **DevOps Team**: For Ansible/infrastructure issues
- **DB Team**: For password and permission issues
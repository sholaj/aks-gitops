# Email to Steven - APMD Service Account Naming Convention

**To:** Steven
**Subject:** Guidance Needed: APMD Service Account Naming Convention

Hi Steven,

We're setting up automated database compliance scanning using Ansible AAP2 and need guidance on the APMD service account naming convention.

**Context:**
- Implementing NIST compliance scans across MSSQL, Oracle, and Sybase databases
- Using single APMD service account for:
  - AAP2 SSH connectivity to delegate hosts
  - Database connections (MSSQL port 1733, Oracle port 1521, Sybase port 5000)
  - Read-only compliance scanning operations

**Request:** What naming convention should we follow for this APMD service account?

Example format we're considering: `svc_apmd_db_compliance` or `apmd_nist_scanner`

Please advise on the standard naming pattern.

Thanks,
[Your Name]

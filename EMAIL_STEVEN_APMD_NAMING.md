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



Here's a clear and professional email you can send to Collin:

---

**Subject:** Task Delegation: Ansible AAP DB Scanning Project (3-Day Coverage)

Hi Collin,

I hope you're doing well. I will be away for the next 3 days and need your help with progressing our Ansible AAP database scanning project. I'm delegating three critical tasks to you during this time.

**Task 1: Setup Ansible Execution Environment with Database Binaries**
- Objective: Build an Ansible execution environment that includes all three database client binaries (Oracle, MSSQL, and Sybase)
- Point of Contact: Adam from the AAP2 team
- Resources: I've already sent you the database binaries through MS Teams
- This is essential for our AAP to be able to connect to and scan all three database platforms

**Task 2: Programmatic Password Retrieval for Service Account**
- Objective: Determine how to programmatically retrieve the password for our newly created service account (CHFAPP86770) from CyberArk
- Purpose: This will enable us to fully utilize RBAC controls assigned to the account for database scanning operations
- This is critical for our automation workflow and secure credential management
- You may need to work with the Security team or check CyberArk API documentation

**Task 3: Install Sybase Client Binary on Sandbox Server**
- Objective: Install Sybase client binary on our sandbox server (lab1@ssc.local)
- Point of Contact: Dimitry from the Sybase team
- Important Note: Dimitry is based in Canada and comes online after 12pm our time, so please schedule accordingly
- This will allow us to test Sybase connectivity from our lab environment

Please feel free to reach out if you have any questions before I leave. I'll have limited access while I'm away, but I'll check messages periodically if anything urgent comes up.

Thanks for taking this on, Collin. I really appreciate your help in keeping the project moving forward.

Best regards

---

This email clearly outlines each task with specific objectives, identifies the people Collin needs to collaborate with, and includes the important timezone note for working with Dimitry. Feel free to adjust any details as needed!
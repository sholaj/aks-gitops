## Claude
As devops enginneer, I want to create the database scanning design document for the NIST compliance project using Ansible and InSpec. 

Review the markdowns downs in the project and create a comprehensive design document that includes architecture diagrams, connectivity matrices, execution flow, role structures, security considerations, error handling, and result management.





Use this document as a reference:

Perfect ✅ — here’s your complete and production-ready Database Compliance Scanning Framework Design Document with the Mermaid + ASCII diagrams fully folded into the architecture section, ready for upload to Jira or Confluence.

⸻

🧾 Database Compliance Scanning Framework Design

Author: Platform Engineering / DevOps
Version: 1.0
Date: TBD
Tooling: Ansible AAP2, InSpec, Splunk (optional)

⸻

1. Purpose

This document defines the design and architecture of the Database Compliance Scanning Framework using Ansible AAP2 and InSpec.
The framework enables automated compliance scanning across multiple database platforms — MSSQL, Oracle, and Sybase — using native credentials, standard roles, and repeatable playbooks executed from AAP2.

⸻

2. Architecture Overview

2.1 Logical Overview

Each scan is orchestrated from Ansible AAP2, which triggers job templates that execute on delegate hosts.
These delegate hosts run InSpec scans using the appropriate role (mssql_scan, oracle_scan, sybase_scan), and results are exported as JSON for analysis or ingestion into Splunk.

⸻

2.2 Mermaid Architecture Diagram

flowchart LR
    AAP[AAP2 Controller / Job Template] -->|SSH (22)| DLH[Delegate Host (EE w/ InSpec + DB clients)]

    subgraph DB_Targets[Database Targets]
      MSSQL[(MSSQL 2017/2019/2022)]:::mssql
      ORA[(Oracle 12c/19c)]:::oracle
      SYB[(Sybase ASE 16)]:::sybase
    end

    DLH -->|TCP 1433| MSSQL
    DLH -->|TCP 1521| ORA
    DLH -->|TCP 1025| SYB
    DLH -->|HTTPS 8088 (optional)| SPL[Splunk HEC]

    classDef mssql fill:#1f77b4,stroke:#0d3a5a,color:#fff
    classDef oracle fill:#d62728,stroke:#5a0d0d,color:#fff
    classDef sybase fill:#9467bd,stroke:#3f2a61,color:#fff


⸻

2.3 ASCII Diagram (for plain-text platforms)

+-------------------------+
|     AAP2 Controller     |
|  (Job Template, EE ref) |
+-----------+-------------+
            | SSH 22
            v
+-------------------------+
|      Delegate Host      |  EE: InSpec + sqlcmd/sqlplus/isql
| (Runner / Execution Env)|
+-----+----------+--------+
      |          |                 Optional
      |          |                 HTTPS 8088
      |          +-------------------------->
      |                                   +-----------------+
      |                                   |     Splunk      |
      |                                   |  (HEC endpoint) |
      |                                   +-----------------+
      |
      | TCP 1433              TCP 1521                 TCP 1025
      v                       v                        v
+-----------+          +-------------+          +---------------+
|  MSSQL    |          |   Oracle    |          |    Sybase     |
| (Target)  |          |  (Target)   |          |   (Target)    |
+-----------+          +-------------+          +---------------+


⸻

2.4 Connectivity Matrix

Component	Source	Destination	Protocol	Port	Description
AAP2 Controller	AAP2	Delegate Host	SSH	22	Launches jobs to EE
Delegate Host	EE Runner	MSSQL DB	TCP	1433	SQL Server connectivity
Delegate Host	EE Runner	Oracle DB	TCP	1521	Oracle listener
Delegate Host	EE Runner	Sybase DB	TCP	1025	Sybase ASE listener
Delegate Host	EE Runner	Splunk HEC	HTTPS	8088	Optional metrics/log ingestion


⸻

3. Execution Flow
	1.	Job Trigger:
AAP2 launches a job template referencing an execution environment (EE) containing InSpec and DB clients.
	2.	Inventory Selection:
Hosts are dynamically loaded from inventory files converted from flat DB input lists.
	3.	Role Execution:
	•	mssql_scan, oracle_scan, or sybase_scan executed per DB type.
	•	Each role retrieves credentials, validates connection, and runs its respective InSpec profile.
	4.	Scan Execution:
	•	InSpec runs using native DB clients (sqlcmd, sqlplus, or isql).
	•	JSON results saved locally and optionally forwarded to Splunk.
	5.	Reporting:
	•	Result JSONs parsed for control-level compliance.
	•	Reports exported to /tmp/compliance_scans/<DB>/<timestamp>/.

⸻

4. Role and File Structure

roles/
├── mssql_scan/
│   ├── tasks/
│   │   ├── main.yml
│   │   ├── setup.yml
│   │   ├── execute.yml
│   │   └── results.yml
│   └── templates/
│       └── mssql_inspec.j2
├── oracle_scan/
│   └── tasks/
│       └── main.yml
├── sybase_scan/
│   └── tasks/
│       └── main.yml
group_vars/
└── all/
    └── vault.yml   # Encrypted credentials
playbooks/
└── master_db_scan.yml


⸻

5. Connectivity Section

5.1 Network Requirements
	•	AAP2 must reach delegate hosts via SSH (port 22).
	•	Delegate hosts must have direct or routed connectivity to DB endpoints on their respective ports.
	•	Ensure inbound firewall rules on DB servers permit access from the delegate host subnet.

5.2 Host Configuration

Delegate hosts run EE images that include:
	•	inspec binary
	•	sqlcmd, sqlplus, isql clients
	•	Access to vault.yml for credential lookup

⸻

6. Security
	•	All credentials stored in Ansible Vault, never in plain text.
	•	Vaults encrypted with AES256 using AAP2 credential store integration.
	•	No AD/RBAC authentication in scope — native DB credentials only.
	•	Each DB scan executed using a read-only scan account (nist_scan_user).

⸻

7. Error Handling

Failure Type	Detection	Recovery
Password retrieval	Helper script exit code != 0	Log as CLOAKWARE_UNREACHABLE, mark scan as skipped
DB connection failure	SQL client return code != 0	Retry 2x with 30s delay
JSON parse failure	InSpec output malformed	Move to /tmp/failed_results/
Missing control file	File not found	Abort with descriptive error message


⸻

8. Result Management
	•	All results saved in:

/tmp/compliance_scans/<hostname>_<dbtype>_<timestamp>/


	•	Output formats:
	•	inspec_results.json
	•	inspec_results.txt (summary)
	•	Optional ingestion to Splunk HEC endpoint.

⸻

9. Governance and Documentation
	•	Design Document stored in Confluence: Platform Engineering → DB Compliance Framework
	•	Linked Jira Stories:
	•	EE Client Installation
	•	Password Retrieval
	•	MSSQL/Oracle/Sybase Scanning Roles
	•	Sample DB Validation
	•	Connectivity Test Automation

⸻

10. Future Enhancements
	•	Centralize vault credential management per DB type.
	•	Add Slack/Email notification integration in AAP2 workflows.
	•	Introduce dynamic inventory generation for ephemeral test environments.
	•	Integrate with ServiceNow CMDB for scan status reporting.

⸻

✅ This document is now ready for upload into Jira or Confluence as an attachment or design artifact.

Would you like me to generate a matching “DB_Scan_Design_Overview.pptx” (PowerPoint) version for management presentation and stakeholder review?
# Epic: DB Compliance Scanning with Ansible + InSpec

**Goal:** Replace the legacy ksh scanner with modular Ansible roles (MSSQL, Oracle, Sybase), a wrapper playbook to orchestrate scans by DB type, utilities to convert existing flat-file lists into Ansible inventories, and secure authentication with AD service accounts. Results are emitted as JSON for Splunk ingestion and SOC monitoring.

---

## Ticket 1 — Install DB clients into Ansible Execution Environments
**Title:** [DB Corp] Install DB client binaries into Ansible Execution Environments (AWX Tower: AA22)

**User Story:**  
As a DevOps engineer, I want MSSQL, Oracle, and Sybase clients installed in the Ansible EE (AWX Tower: AA22) so that playbooks can execute database connectivity checks and compliance scans.

**Acceptance Criteria:**
- DB client binaries (MSSQL, Oracle, Sybase) are available inside the EE images.
- EE builds are updated and tested in AWX.
- Documentation added for how DB clients are maintained in EE.

**Tasks:**
1. Raise request to Ansible platform team to add DB client packages into EE images.
2. Verify installation via AWX job logs (`sqlcmd`, `sqlplus`, `isql` available).
3. Document pre-requisites in Confluence.

---

## Ticket 2 — Firewall connectivity to CORP DEV databases
**Title:** [DB Corp] Enable firewall rules from Ansible EE to CORP DEV databases

**User Story:**  
As a DevOps engineer, I want firewall rules raised and approved so that Ansible EE can reach CORP DEV databases for scanning.

**Acceptance Criteria:**
- Firewall requests submitted and approved.
- Connectivity confirmed from EE to CORP DEV DB endpoints (telnet/nc tests).
- Connectivity validated for all required ports (MSSQL 1433, Oracle 1521, Sybase 5000+/configurable).

**Tasks:**
1. Raise firewall requests for CORP DEV DB subnets.
2. Track approval through change process.
3. Validate connectivity once rules are in place.

---

## Ticket 3 — On-board databases and IAM service account model
**Title:** [DB Corp] On-board databases and test IAM service account model for scanning

**User Story:**  
As a DevOps engineer, I want existing or new databases on-boarded for scanning and work with GCS IAM team to validate the CHF DB service account model.

**Acceptance Criteria:**
- At least one MSSQL, Oracle, and Sybase DB onboarded for scan.
- IAM service account created and validated with GCS IAM team.
- Connectivity tests pass using IAM-based credentials.

**Tasks:**
1. Identify target DBs (new/existing) for onboarding.
2. Request IAM service account creation for CHF DB scanning.
3. Validate login and connectivity with IAM account.
4. Document onboarding procedure.

---

## Ticket 4 — Execute connectivity and scanning from EE
**Title:** [DB Corp] Execute DB connectivity validation and scanning from Ansible EE

**User Story:**  
As a DevOps engineer, I want to run connectivity checks and InSpec scanning playbooks from EE so that database compliance can be validated.

**Acceptance Criteria:**
- Playbooks run successfully inside EE.
- JSON scan results generated for each DB type.
- Manual and automated execution paths validated.

**Tasks:**
1. Test manual execution of DB connectivity batch from EE.
2. Commit codebase/playbooks into GitHub and configure AWX job templates.
3. Run playbooks against CORP DEV DBs and collect results.

---

## Ticket 5 — Splunk ingestion and SOC testing
**Title:** [DB Corp] Ingest scan results into Splunk and validate with Azure SOC

**User Story:**  
As a DevOps engineer, I want scan results ingested into Splunk and validated by Azure SOC so that compliance data is available for monitoring and audit.

**Acceptance Criteria:**
- JSON outputs from scans ingested into Splunk index.
- Dashboards updated to display DB scan results.
- Azure SOC team validates ingestion and confirms visibility.

**Tasks:**
1. Implement ingestion step in playbooks (reuse `splunk_ingest` role if available).
2. Verify Splunk index population.
3. Coordinate with Azure SOC to test visibility and alerting.

---

## Ticket 6 — Request AD service account for DB scanning
**Title:** [DB Corp] Request AD service account (process ID) for DB scanning with Windows authentication

**User Story:**  
As a DevOps engineer, I want to use an AD service account (process ID) with Windows authentication for database scanning so that scans are executed securely using corporate identity, instead of relying on local database accounts.

**Acceptance Criteria:**
- Request submitted for creation of AD service account dedicated to DB scanning.
- Process ID created and managed under corporate AD policies.
- Service account granted required DB permissions (read/scan only).
- Connectivity validated with Windows authentication (Kerberos/SSPI).
- Documentation updated to reflect switch from local DB accounts to AD-based authentication.

**Tasks:**
1. Submit AD service account request via IAM process (specify DB scanning use case).
2. Work with DBAs to grant least-privilege access for compliance scanning.
3. Configure Ansible playbooks to use AD authentication instead of local DB users.
4. Validate DB connectivity and successful InSpec scans using the new service account.
5. Update Confluence with account details, usage procedures, and fallback.

---

## Ticket 7 — Test AD service account for sample DB scan
**Title:** [DB Corp] Validate AD service account by executing sample DB scan with Windows authentication

**User Story:**  
As a DevOps engineer, I want to test the newly created AD service account against a sample database scan so that I can confirm Windows authentication works end-to-end for DB compliance scanning.

**Acceptance Criteria:**
- AD service account credentials successfully used in Ansible playbook.
- Connectivity test to a sample MSSQL database succeeds with Windows authentication.
- InSpec scan executes using the service account and produces JSON results.
- Logs confirm authentication via AD (not local DB account).
- Test results documented with screenshots/output attached to the ticket.

**Tasks:**
1. Configure Ansible inventory/playbook to use the new AD service account.
2. Select a non-production/sample MSSQL database for validation.
3. Run connectivity test (sqlcmd / Ansible task) with Windows authentication.
4. Execute sample InSpec scan and confirm results are captured.
5. Document outcome in Confluence and attach run logs/output.


⸻

Epic

[DB Corp] Implement Ansible-based DB compliance scanning with InSpec

Goal: Replace the legacy ksh scanner with modular Ansible roles (MSSQL, Oracle, Sybase), a wrapper playbook to orchestrate scans by DB type, and utilities to convert existing flat-file lists into proper Ansible inventories. Results are emitted as JSON for Splunk ingestion.

⸻

Story 1 — Repo & VSCode scaffolding

Title: [DB Corp] Scaffold VSCode workspace and Ansible repo for DB scanning
User Story: As a DevOps engineer, I want a consistent project structure and VSCode workspace so that developers can easily add roles and playbooks for DB scanning.
Acceptance Criteria
	•	VSCode workspace with folders: roles/, playbooks/, inventories/, profiles/, utils/, docs/
	•	ansible.cfg tuned for local runs and AWX/AAP
	•	Makefile or task runner with make lint, make scan-mssql, etc.
	•	Example .env.sample documenting required vars
Tasks
	•	Initialize repo, editorconfig, yamllint/ansible-lint
	•	Add VSCode settings (YAML schema hints, Ansible extension recommendations)
	•	Commit skeleton

⸻

Story 2 — MSSQL scan role

Title: [DB Corp] Create roles/mssql_scan to execute InSpec profiles for MSSQL
User Story: As a DevOps engineer, I want an Ansible role that runs InSpec controls against MSSQL targets so that MSSQL databases can be scanned consistently.
Acceptance Criteria
	•	Role folder roles/mssql_scan with tasks/main.yml, defaults/main.yml, vars/main.yml, README.md
	•	Inputs: mssql_host, mssql_port, mssql_user, mssql_pass, db_version (maps to MSSQL{version}_ruby)
	•	Executes profile from profiles/MSSQL{version}_ruby/
	•	Outputs JSON to results/mssql/<host>/<timestamp>/inspec_results.json
	•	Tags: mssql, db_scan, inspec_exec
Tasks
	•	Implement command wrapper and path detection
	•	Handle missing profile with clear failure
	•	Unit test with localhost/dummy

⸻

Story 3 — Oracle scan role

Title: [DB Corp] Create roles/oracle_scan to execute InSpec profiles for Oracle
User Story: As a DevOps engineer, I want an Ansible role that runs InSpec controls against Oracle so that Oracle databases can be scanned by version.
Acceptance Criteria
	•	Role roles/oracle_scan with same layout as MSSQL
	•	Inputs: oracle_host, oracle_port, oracle_sid|service, db_version
	•	Maps to profiles/ORACLE{version}_ruby/
	•	JSON results under results/oracle/<host>/<timestamp>/
Tasks
	•	Implement connection var handling (SID/service name)
	•	Explicit error on missing client binaries
	•	Sample run doc

⸻

Story 4 — Sybase scan role

Title: [DB Corp] Create roles/sybase_scan to execute InSpec profiles for Sybase
User Story: As a DevOps engineer, I want an Ansible role to scan Sybase so that we cover all 3 DB types.
Acceptance Criteria
	•	Role roles/sybase_scan with inputs: sybase_host, sybase_port, db_version
	•	Maps to profiles/SYBASE{version}_ruby/
	•	JSON results under results/sybase/<host>/<timestamp>/
Tasks
	•	Command wrapper, error handling, examples

⸻

Story 5 — Wrapper playbook to select role by db_type

Title: [DB Corp] Develop wrapper playbook to orchestrate DB scans by type
User Story: As a DevOps engineer, I want a single playbook that calls the appropriate DB scan role based on db_type so that the same entry point can scan any database.
Acceptance Criteria
	•	playbooks/db_scan.yml accepts db_type: mssql|oracle|sybase and common vars
	•	Conditionally include_role for the selected type
	•	Uniform logging and exit codes
	•	Works with dynamic/static inventory
Tasks
	•	Implement conditional includes
	•	Add example invocations in README
	•	Tagging: db_scan

⸻

Story 6 — Flat files → inventories (MSSQL, Oracle, Sybase)

Title: [DB Corp] Convert existing flat files into Ansible inventories
User Story: As a DevOps engineer, I want playbooks to transform the legacy flat files into Ansible inventories so that targets are addressable by groups and variables.
Acceptance Criteria
	•	Three converter playbooks:
	•	playbooks/inventory_convert_mssql.yml
	•	playbooks/inventory_convert_oracle.yml
	•	playbooks/inventory_convert_sybase.yml
	•	Inputs: the flat file(s) you showed (e.g., NIST_FILES_BACKUP/inventory_MSSQL*.txt, inventory_Oracle.txt, frank_inventory_sybase.txt)
	•	Outputs: inventories/<type>/hosts.yml grouped by version and host
	•	Validation step: ansible-inventory --inventory inventories/<type>/hosts.yml --list passes
Tasks
	•	Write line parsers (regex) for each format
	•	Normalize fields (host, port, version, service/dbname)
	•	Emit YAML inventory with groups:
	•	mssql, mssql_<version>
	•	oracle, oracle_<version>
	•	sybase, sybase_<version>

⸻

Story 7 — Results post-processing & Splunk handoff

Title: [DB Corp] Standardize results foldering and Splunk handoff
User Story: As a DevOps engineer, I want standardized results locations and a handoff step so that Splunk can ingest scan outputs.
Acceptance Criteria
	•	Common result root: results/<db_type>/<host>/<timestamp>/
	•	Minimal results/index.json with run metadata
	•	Optional role hook to push to Splunk (use existing roles/splunk_ingest if present)
	•	Retention knob (e.g., keep last N runs)
Tasks
	•	Implement meta JSON builder
	•	If Splunk role exists, wire it behind a flag

⸻

Story 8 — Error handling & reporting

Title: [DB Corp] Implement robust error handling for DB scans
User Story: As a DevOps engineer, I want clear failure modes and messages so that operators can quickly troubleshoot.
Acceptance Criteria
	•	Fail fast on missing profile/binary/credentials
	•	Wrap InSpec return codes; write error.json with reason
	•	Ansible failed_when and changed_when set appropriately
	•	Optional summary at end of run per host
Tasks
	•	Add block/rescue/always patterns
	•	Add human-readable summary task

⸻

Story 9 — AWX/AAP job templates & credentials

Title: [DB Corp] Prepare AWX/AAP jobs for DB scanning
User Story: As a DevOps engineer, I want AWX jobs to run scans at scale so that we can execute from controlled execution environments.
Acceptance Criteria
	•	Job templates for each path:
	•	db_scan.yml (var db_type)
	•	each inventory converter playbook
	•	EE contains InSpec and DB client CLIs
	•	Credentials configured via AWX (no plain-text in vars)
Tasks
	•	EE verification
	•	Template creation & test runs

⸻

Story 10 — Documentation & runbooks

Title: [DB Corp] Document usage, inputs, and troubleshooting
User Story: As a DevOps engineer, I want clear docs so that others can run and extend the solution.
Acceptance Criteria
	•	docs/ with:
	•	How to run each role
	•	How to convert inventories
	•	Variable reference
	•	Expected outputs and Splunk flow
	•	Troubleshooting (client libs, ports, auth)
Tasks
	•	Write README per role + top-level guide
	•	Add sample commands

⸻

Suggested Labels / Components
	•	Labels: db-scan, inspec, mssql, oracle, sybase, inventory, awx, aap, splunk
	•	Component: Platform Engineering
	•	Priority: Medium (adjust as needed)

⸻

VSCode + commands to scaffold (copy-paste)

# from repo root
mkdir -p playbooks inventories/mssql inventories/oracle inventories/sybase profiles results docs utils
ansible-galaxy init roles/mssql_scan
ansible-galaxy init roles/oracle_scan
ansible-galaxy init roles/sybase_scan

# wrapper playbook
cat > playbooks/db_scan.yml <<'YAML'
---
- name: Orchestrate DB scan
  hosts: all
  gather_facts: false
  vars:
    db_type: "{{ db_type | default('mssql') }}"
  tasks:
    - name: Run MSSQL scan
      include_role: { name: mssql_scan }
      when: db_type == 'mssql'

    - name: Run Oracle scan
      include_role: { name: oracle_scan }
      when: db_type == 'oracle'

    - name: Run Sybase scan
      include_role: { name: sybase_scan }
      when: db_type == 'sybase'
YAML

Inventory converter playbook stubs

# playbooks/inventory_convert_mssql.yml
---
- name: Convert MSSQL flat files to inventory
  hosts: localhost
  gather_facts: false
  vars:
    input_file: "NIST_FILES_BACKUP/inventory_MSSQLtxt.new"
    output_file: "inventories/mssql/hosts.yml"
  tasks:
    - name: Read flat file
      slurp:
        src: "{{ input_file }}"
      register: raw

    - name: Parse lines -> host entries
      set_fact:
        mssql_hosts: >-
          {{
            (raw.content | b64decode).splitlines()
            | select('match','^MSSQL\\s+')
            | map('regex_replace','^MSSQL\\s+','')
            | map('split','\\s+')
            | list
          }}
    - name: Build inventory structure
      set_fact:
        inv: |
          all:
            children:
              mssql:
                hosts:
          {% for parts in mssql_hosts %}
            {{ parts[0] }}:
              mssql_port: {{ parts[-2] }}
              db_version: {{ parts[-1] }}
          {% endfor %}
    - copy:
        dest: "{{ output_file }}"
        content: "{{ inv }}"

Repeat the same pattern for inventory_convert_oracle.yml and inventory_convert_sybase.yml adjusting the field positions from your flat files (Oracle lines like ORACLE <host> <db> <service> <port> <version>; Sybase sample matches SYBASE <host> <db> <service> <port> <version>).

⸻

Definition of Done (apply to all stories)
	•	Code merged to main with lint passing
	•	Example run documented
	•	Outputs verified (JSON present under results/…)
	•	If applicable, AWX job runs green
	•	Tickets reference commit hashes / screenshots

⸻
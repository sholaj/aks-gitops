# Epic: DB Compliance Scanning with Ansible + InSpec

**Goal:** Replace the legacy ksh scanner with modular Ansible roles (MSSQL, Oracle, Sybase), a wrapper playbook to orchestrate scans by DB type, utilities to convert existing flat-file lists into Ansible inventories, and secure authentication with native database credentials. Results are emitted as JSON for Splunk ingestion and SOC monitoring.

---

## Foundation & Access

### Ticket 1 — Install DB clients into Ansible Execution Environments
As a DevOps engineer, I want MSSQL, Oracle, and Sybase clients installed in the Ansible execution environment so that playbooks can execute database connectivity checks and compliance scans.

**Acceptance Criteria**
- EE images include MSSQL, Oracle, and Sybase client binaries.
- Updated EE images are tested and available within AWX/AAP.
- Documentation explains how DB clients are maintained in the EE builds.

**Tasks**
1. Raise request to the Ansible platform team to add DB client packages into EE images.
2. Verify installation via AWX job logs, ensuring `sqlcmd`, `sqlplus`, and `isql` are available.
3. Document prerequisites and maintenance procedures in Confluence.

### Ticket 2 — Enable firewall connectivity to CORP DEV databases
As a DevOps engineer, I want firewall rules raised and approved so that the Ansible execution environment can reach CORP DEV databases for scanning.

**Acceptance Criteria**
- Firewall requests are submitted and approved for required CORP DEV subnets.
- Connectivity tests from the EE to each target succeed using `telnet`/`nc` or equivalent checks.
- All necessary ports (MSSQL 1433, Oracle 1521, Sybase 5000+/configurable) are validated.

**Tasks**
1. Submit firewall requests covering the CORP DEV database subnets and ports.
2. Track approvals through the change process until rules are live.
3. Run connectivity validations once rules are in place and capture evidence.

### Ticket 3 — On-board target databases for scanning
As a DevOps engineer, I want representative MSSQL, Oracle, and Sybase databases onboarded with native credentials so that scans can be validated end-to-end.

**Acceptance Criteria**
- At least one MSSQL, Oracle, and Sybase database is onboarded for scanning.
- Native database credentials needed for scanning are captured and stored following policy.
- Connectivity tests using those credentials succeed for each onboarded database.
- Onboarding steps are documented for reuse.

**Tasks**
1. Identify candidate databases (new or existing) to act as scan exemplars.
2. Coordinate with DB owners to supply or reset scoped native credentials for scanning.
3. Validate logon and simple query execution for each database using the provided credentials.
4. Document the onboarding workflow and success criteria.

---

## Build Scanning Capabilities

### Ticket 4 — Create MSSQL scanning role
As a DevOps engineer, I want an Ansible role that runs InSpec controls against MSSQL targets so that MSSQL databases can be scanned consistently.

**Acceptance Criteria**
- Role `roles/mssql_scan` includes tasks, defaults, vars, and README.
- Role inputs cover host, port, credentials, and version mapping to `profiles/MSSQL{version}_ruby/`.
- Scan outputs are written to `results/mssql/<host>/<timestamp>/inspec_results.json`.
- Role errors clearly when the required profile or client binary is missing.

**Tasks**
1. Implement the command wrapper and profile selection logic in `roles/mssql_scan`.
2. Add handling for missing profiles or binaries with descriptive failures.
3. Create a localhost or dummy test to validate command execution flow.

### Ticket 5 — Create Oracle scanning role
As a DevOps engineer, I want an Ansible role that runs InSpec controls against Oracle databases so that Oracle targets can be scanned by version.

**Acceptance Criteria**
- Role `roles/oracle_scan` mirrors the MSSQL role layout with SID/service-name handling.
- Role maps inputs to `profiles/ORACLE{version}_ruby/` and emits results under `results/oracle/<host>/<timestamp>/`.
- Clear errors are raised when Oracle client dependencies or profiles are absent.

**Tasks**
1. Implement connection variable handling for SID and service-name scenarios.
2. Detect missing Oracle client binaries and fail with actionable messaging.
3. Produce a sample run and capture expected output locations.

### Ticket 6 — Create Sybase scanning role
As a DevOps engineer, I want an Ansible role that runs InSpec controls against Sybase databases so that the solution covers all three database types.

**Acceptance Criteria**
- Role `roles/sybase_scan` accepts host, port, credentials, and version mapping to `profiles/SYBASE{version}_ruby/`.
- Results are written to `results/sybase/<host>/<timestamp>/` with consistent naming.
- Role surfaces meaningful errors for missing dependencies or failed scans.

**Tasks**
1. Build the Sybase command wrapper with robust error handling.
2. Supply usage examples within the role README.
3. Align task outputs and logging with the MSSQL and Oracle roles.

### Ticket 7 — Develop wrapper playbook for DB scan orchestration
As a DevOps engineer, I want a single playbook that selects the correct DB scan role based on type so that operators have a unified entry point.

**Acceptance Criteria**
- `playbooks/db_scan.yml` accepts `db_type` (mssql|oracle|sybase) and common connection variables.
- The playbook conditionally includes the appropriate scan role.
- Logging, exit codes, and tagging are uniform across DB types.
- Playbook supports both static and dynamic inventories.

**Tasks**
1. Implement conditional role inclusion based on the `db_type` variable.
2. Document example invocations in the repository README.
3. Tag the playbook with `db_scan` for AWX/AAP discovery.

### Ticket 8 — Implement robust error handling and reporting
As a DevOps engineer, I want clear failure modes and summaries so that operators can quickly troubleshoot scan issues.

**Acceptance Criteria**
- Scan roles fail fast on missing profiles, binaries, or credentials.
- An `error.json` file with failure reasons is produced when scans fail.
- `failed_when` and `changed_when` conditions are set to reflect scan outcomes accurately.
- Optional end-of-run summary is available per host.

**Tasks**
1. Add `block`/`rescue`/`always` patterns to wrap scan execution.
2. Generate concise human-readable summaries and structured error outputs.
3. Align return codes with downstream tooling expectations.

---

## Inventories & Automation

### Ticket 9 — Convert legacy flat files into Ansible inventories
As a DevOps engineer, I want playbooks that transform legacy flat files into Ansible inventories so that targets are addressable by groups and variables.

**Acceptance Criteria**
- Three converter playbooks exist for MSSQL, Oracle, and Sybase inputs.
- Output inventories are written under `inventories/<type>/hosts.yml` with grouping by DB version and host.
- `ansible-inventory --inventory inventories/<type>/hosts.yml --list` succeeds for each generated inventory.

**Tasks**
1. Implement line parsers (regex) tailored to each legacy format.
2. Normalize host metadata (host, port, version, service or database name).
3. Emit grouped inventory YAML and validate with `ansible-inventory`.

### Ticket 10 — Execute connectivity validation and scanning from EE
As a DevOps engineer, I want to run connectivity checks and InSpec scanning playbooks from the execution environment so that database compliance can be validated end-to-end.

**Acceptance Criteria**
- Manual execution of connectivity checks from the EE succeeds for each DB type.
- AWX/AAP job templates run the scanning playbooks successfully.
- JSON scan results are captured and archived per database type.

**Tasks**
1. Test manual execution of the connectivity batch from the EE images.
2. Commit playbooks and roles into the repository and configure AWX job templates.
3. Run the scan playbooks against CORP DEV databases and verify SQL Server tooling via the MSSQL role test playbook.

### Ticket 11 — Prepare AWX/AAP jobs for DB scanning
As a DevOps engineer, I want production-ready AWX job templates so that scans can run at scale from controlled execution environments.

**Acceptance Criteria**
- Job templates exist for the unified scan playbook and each inventory conversion playbook.
- Execution environments referenced by the jobs contain InSpec and DB client CLIs.
- Credentials are configured via AWX and no plain-text secrets remain in playbooks or inventories.

**Tasks**
1. Verify EE contents align with scan requirements.
2. Create and parameterize AWX/AAP job templates.
3. Perform test runs and capture logs for future reference.

---

## Results & Documentation

### Ticket 12 — Standardize results foldering and Splunk handoff
As a DevOps engineer, I want standardized result locations and a handoff step so that Splunk can ingest scan outputs.

**Acceptance Criteria**
- Results follow `results/<db_type>/<host>/<timestamp>/` across all roles.
- A minimal `results/index.json` captures run metadata for each scan.
- Optional Splunk ingestion hook is available and can be toggled per run.
- Retention controls allow keeping only the last N runs per host.

**Tasks**
1. Implement metadata JSON builder shared by scan roles.
2. Wire the Splunk ingestion role or hook behind a feature flag if available.
3. Add a retention mechanism that prunes old run folders.

### Ticket 13 — Document usage, inputs, and troubleshooting
As a DevOps engineer, I want comprehensive documentation so that others can run and extend the solution.

**Acceptance Criteria**
- `docs/` contains runbooks covering each role, the wrapper playbook, and inventory conversion steps.
- Documentation includes variable references, expected outputs, and the Splunk ingestion flow.
- Troubleshooting guidance addresses client libraries, ports, and authentication patterns.

**Tasks**
1. Write role-level READMEs and a top-level guide describing end-to-end usage.
2. Add sample commands and expected outputs for common scenarios.
3. Capture known issues and troubleshooting tips informed by early test runs.

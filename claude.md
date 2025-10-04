## Claude

/agent devops-enginer: 
##Task
You are a DevOps engineer. You running a test of the run_mssql_inspec.yml playbook.
You need to ensure that the playbook runs successfully and configures the MSSQL server as expected.
You have access to the following resources:
- The Ansible playbook file: run_mssql_inspec.yml 
Here is error output from the playbook run:
```
TASK [mssql : Ensure MSSQL is started and enabled] *****************************

```
TASK [mssql_inspec : Setup directories and find control files] ***************
included: /auto/home/p882789/aks-gitops-main/mssql_inspec/tasks/setup.yml for GDCTWC0007_1733

TASK [mssql_inspec : Create results directory] *******************************
changed: [GDCTWC0007_1733 -> localhost]

TASK [mssql_inspec : Create temporary working directory] *********************
changed: [GDCTWC0007_1733 -> localhost]

TASK [mssql_inspec : Find all Ruby control files for specified MSSQL version] ***
ok: [GDCTWC0007_1733 -> localhost]

TASK [mssql_inspec : Display control files to be executed] *******************
skipping: [GDCTWC0007_1733]

TASK [mssql_inspec : Execute InSpec controls and process results] ************
fatal: [GDCTWC0007_1733]: FAILED! => {"reason": "delegate_to is not a valid attribute for a TaskInclude\n\nThe error appears to be in '/auto/home/p882789/aks-gitops-main/mssql_inspec/tasks/execute.yml': line 25, column 3, but may\nbe elsewhere in the file depending on the exact syntax problem.\n\nThe offending line appears to be:\n\n- name: Process InSpec results\n  ^ here\n"}

PLAY RECAP *******************************************************************
GDCTWC0007_1733          : ok=12   changed=2   unreachable=0   failed=1   skipped=6   rescued=0   ignored=0

lcptlvc0005 28: 45:38 +0000 (0:00:00.054)       0:01:23.501 ********


Patch role:mssql_inspec, task: Execute InSpec controls and process results failed. For more details, see the error message above.
The error message indicates that there is an issue with the 'delegate_to' attribute in the task include.
Please review the task definition in 'mssql_inspec/tasks/execute.yml' and correct the syntax error.
Once the issue is resolved, re-run the playbook to ensure it completes successfully
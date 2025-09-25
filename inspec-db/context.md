
Overview

Compliance scanning is currently conducted through a bash script.
Databases (Oracle, Sybase, MSSQL) are backed up with the same script.
The script differentiates which DB is being backed up by platform type.


i want to refactor your current Bash-based DB scanning into modular Ansible roles + inventories, with support for MSSQL, Oracle, and Sybase.

The script is called with parameters for platform, server name, database name, service name, port number, and database version.: 
script name: NIST_for_db.ksh 
```sh
#!/bin/ksh
# Script Name: NIST_for_db.ksh
# This script must be called from the Parent Script NIST.ksh
# This script will not work as a standalone run script.

platform=$1
servernm=$2
dbname=$3
servicenm=$4
portnum=$5
dbversion=$6

script_dir=$(dirname $0)
temp_dir=$script_dir/${platform}_NIST_$$_${now}_temp_files
mkdir -p $temp_dir

ruby_dir=$script_dir/${platform}_${dbversion}_ruby

if [ ! -d $ruby_dir ]; then
  print "The directory specified as ruby_dir for Database Platform $platform in the script does not exist or the permissions to access the directory are insufficient."
  print "The value of ruby_dir in the script is: $ruby_dir"
  exit 7
fi

cloakware_unreachable="{\"controls\":[{\"timestamp\":\"\",\"hostname\":\"$servernm\",\"database\":\"$dbname\",\"port\":\"$portnum\",\"DBVersion\":\"$dbversion\",\"id\":\"Not able to retrieve Cloakware Password for DBMAINT Account\",\"profile_id\":\"N/A\",\"profile_sha256\":\"N/A\",\"status\":\"Unreachable\",\"code_desc\":\"N/A\",\"statistics\":{\"duration\":0},\"version\":\"N/A\"}]}"

# Pick up the password for the database
dbpwd=$(${PW_DIR}/pwEcho.exe $dbname $user)
if [ $? -ne 0 ]; then
  dbpwd="NA"
fi

if [ "$dbpwd" = "NA" ]; then
  pwdgood=0
else
  pwdgood=1
fi

# Database password section end
if [ $pwdgood -eq 0 ]; then
  for g_file in $(ls -1 $ruby_dir); do
    file_prefix=$(print $g_file | awk -F. '{print $1}')
    if [ "$platform" = "SYBASE" ]; then
      /usr/bin/inspec exec $ruby_dir/$g_file --ssh://oracle:edcp!cv0576@ -o oracle/.ssh/authorized_keys --input usernm=$user passwd=$dbpwd hostnm=$servernm servicenm=$servicenm port=$portnum --reporter=json-min --no-color > $temp_dir/${platform}_NIST_$$_${servernm}_${dbname}_${dbversion}_${now}_${file_prefix}.out
    else
      /usr/bin/inspec exec $ruby_dir/$g_file --input usernm=$user passwd=$dbpwd hostnm=$servernm servicenm=$servicenm port=$portnum --reporter=json-min --no-color > $temp_dir/${platform}_NIST_$$_${servernm}_${dbname}_${dbversion}_${now}_${file_prefix}.out
    fi

    the_status=$(awk -F\" '/status/ {print $2}' $temp_dir/${platform}_NIST_$$_${servernm}_${dbname}_${dbversion}_${now}_${file_prefix}.out | awk -F: '{print $1}' | sed 's/[",]//g')

    if [ "$the_status" = "passed" ] || [ "$the_status" = "failed" ] || [ "$the_status" = "skipped" ]; then
      mv $temp_dir/${platform}_NIST_$$_${servernm}_${dbname}_${dbversion}_${now}_${file_prefix}.out \
         $temp_dir/${platform}_NIST_$$_${servernm}_${dbname}_${dbversion}_${now}_${file_prefix}.json
    else
      some_error="{\"controls\":[{\"timestamp\":\"\",\"hostname\":\"$servernm\",\"database\":\"$dbname\",\"port\":\"$portnum\",\"DBVersion\":\"$dbversion\",\"id\":\"Cannot connect to database. One or more parameters such as Platform, Host Name, Database Name, Service Name, Port Number, Database Version may be incorrect.\",\"profile_id\":\"N/A\",\"profile_sha256\":\"N/A\",\"status\":\"Unreachable\",\"code_desc\":\"Cannot connect\",\"statistics\":{\"duration\":0},\"version\":\"N/A\"}]}"

      print "$some_error" > $temp_dir/${platform}_NIST_$$_${servernm}_${dbname}_${dbversion}_${now}_${file_prefix}.json
    fi
  done
else
  print "$cloakware_unreachable" > $temp_dir/${platform}_NIST_$$_${servernm}_${dbname}_${dbversion}_${now}_unreachable.json
fi

exit 0

```

The first assignment is to focus on MSSQL scanning.
The controls will be stored in a folder structure like:

MSSQL2018_ruby = ruby_dir=$script_dir/${platform}_${dbversion}_ruby

Example control folders for MSSQL:

MSSQL2008_ruby
MSSQL2012_ruby
MSSQL2014_ruby
MSSQL2016_ruby
MSSQL2018_ruby
MSSQL2019_ruby

Inventory
At the moment, inventory is presented as flat files.
Example line for MSSQL:

MSSQL m02dsm3 m02dsm3 BIRS_Confidential 1733 2017

Example controls directory for ORACLE:

ORACLE11_ruby
ORACLE12_ruby
ORACLE19_ruby

Example controls directory for SYBASE:
SYBASE12_ruby
SYBASE15_ruby   
SYBASE16_ruby




Script takes

platform=$1
servernm=$2
dbname=$3
servicenm=$4
portnum=$5
dbversion=$6

Notes
DB username and service name not used.
Ignore password retrieval with cloakware.

⸻


Sample Ansible Playbook to Execute InSpec MSSQL Controls which can be adapted as needed
```yaml
---
- name: Execute InSpec MSSQL Controls via Ansible
  hosts: localhost
  gather_facts: yes

  vars:
    # InSpec execution parameters
    inspec_profile: "./trusted.rb"   # Path to your InSpec profile
    mssql_server: "GDWTCN0007.ustcorp.ustatestatr.local"
    mssql_port: 1733
    mssql_username: "nist_scan_user"
    mssql_password: "Pa$$8word"

    # Results and logging
    results_dir: "/tmp/inspec_mssql_{{ ansible_date_time.epoch }}"

  tasks:
    - name: Create results directory
      file:
        path: "{{ results_dir }}"
        state: directory
        mode: '0755'

    - name: Display test configuration
      debug:
        msg: |
          InSpec MSSQL Test Configuration:
          Profile: {{ inspec_profile }}
          Server: {{ mssql_server }}:{{ mssql_port }}
          Username: {{ mssql_username }}
          Results: {{ results_dir }}

    - name: Check if InSpec profile exists
      stat:
        path: "{{ inspec_profile }}"
      register: profile_check

    - name: Fail if profile doesn’t exist
      fail:
        msg: "InSpec profile not found: {{ inspec_profile }}"
      when: not profile_check.stat.exists

    - name: Execute InSpec MSSQL controls
      shell: >
        /usr/bin/inspec exec {{ inspec_profile }}
        --input usernm={{ mssql_username }} passwd={{ mssql_password }} hostnm={{ mssql_server }}
        port={{ mssql_port }}
        --reporter=json-min --no-color
        --reporter json:{{ results_dir }}/inspec_results.json
      register: inspec_exec
      changed_when: false
      failed_when: inspec_exec.rc != 0
      environment:
        PATH: "/usr/bin:/usr/local/bin:{{ ansible_env.PATH }}:/opt/inspec/tools/bin"

```
- trusted.rb (sample control file)
```rb
sql = mssql_session(user: 'nist_scan_user', password: 'Pa$$w0rd!', host: 'GDCTWVC0007.uatcorp.uatstatesttr.local', port: '1733', TrustServerCertificate: 'Yes')
c_2_01="SELECT CASE WHEN value_in_use = 0 AND value = 0 THEN 'COMPLIANT' ELSE 'NOT COMPLIANT' END AS Results FROM sys.configurations WHERE name = 'Ad Hoc Distributed Queries'"
title "2.01 Ensure 'Ad Hoc Distributed Queries' Server Configuration Option is set to '0'"
control "2.01 Ensure 'Ad Hoc Distributed Queries' Server Configuration Option is set to '0'" do
  describe sql.query(c_2_01).row(0).column('Results') do
    its('value') { should eq 'COMPLIANT' }
  end
end

```

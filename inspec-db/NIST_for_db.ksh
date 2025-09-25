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
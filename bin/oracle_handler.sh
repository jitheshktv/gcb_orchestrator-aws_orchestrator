#!/usr/bin/env bash

set -x

_run_script(){
  username=${1}
  password=${2}
  host=${3}
  port=${4}
  sid=${5}
  script_path=${6}

  script_dir=$(dirname ${script_path})
  script_name=$(basename ${script_path})

  required_arguments=(username password host port sid script_path)
  for arg in "${required_arguments[@]}";
  do
    if [[ -z ${!arg} ]];
    then
      error "The argument ${arg} must be set"
    fi
  done

  pushd ${script_dir}

  # short form of connection string should not be used because of the 63 char limit on hostname
  #sqlplus "${username}/${password}@${host}:${port}/${sid} @${script_path}"

  # long form connection string
  conn_string="${username}/${password}@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=${host})(PORT=${port}))(CONNECT_DATA=(SID=${sid})))"
  echo ${conn_string}
  echo exit | sqlplus "${conn_string}" @"${script_name}"
  sql_exit_code=$?

  popd

  return ${sql_exit_code}
}

_grant_access(){
  aws ec2 authorize-security-group-ingress --group-id ${rds_sg} --protocol tcp --port ${rds_port} --cidr ${orch_ip}/32
  aws ec2 authorize-security-group-egress --group-id ${rds_sg} --protocol tcp --port ${rds_port} --cidr ${orch_ip}/32
}

_revoke_access(){
  aws ec2 revoke-security-group-ingress --group-id ${rds_sg} --protocol tcp --port ${rds_port} --cidr ${orch_ip}/32
  aws ec2 revoke-security-group-egress --group-id ${rds_sg} --protocol tcp --port ${rds_port} --cidr ${orch_ip}/32
}

###################################
# MAIN
# oracle_handler.sh <action> <parameters>

export AWS_DEFAULT_REGION=${AWS_REGION}

in_progress_metadata=inventory/in_progress.yml
orch_ip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
rds_sg=$(./bin/yaml_get ${in_progress_metadata} RDSAccessSecurityGroup)
rds_port=$(./bin/yaml_get ${in_progress_metadata} RDSPort)
action=${1}

error(){ echo ${1};exit 1; }

if [[ "${action}" = 'script' ]];
then
  shift
  _grant_access
  _run_script $@
  sql_status=$?
  _revoke_access
  exit ${sql_status}
else
  error "The action arg must be provided."
fi

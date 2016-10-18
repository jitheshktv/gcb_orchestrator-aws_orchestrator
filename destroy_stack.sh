#!/usr/bin/env bash

set -e
set -x

_confirm() {
  msg=$1
  read -p "Are you sure you want to destroy ${msg}?" -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
      exit 1
  fi
}

_check_run_list() {
  rlist_type=$1
  if [[ "${rlist_type}" = "environment" ]]; then
    rlist=( "${env_runlist[@]}" )
  else
    rlist=( "${runlist[@]}" )
  fi
  echo "The ${rlist_type} run list:"
  printf '\t%s\n' "${rlist[@]}"
  if [[ ${#rlist[@]} -eq 0 ]];
  then
    echo "nothing in the runlist, bailing"
    exit 1
  fi
}

_destroy_stack() {
  declare -a runlist=($(./bin/get_run_list ${stack_manifest_file} run_list))
  declare -a cfn_stack_names
  _check_run_list "tech_stack"
  for (( idx=${#runlist[@]}-1 ; idx>=0 ; idx-- )); do
    template_name=$(echo ${runlist[$idx]} | awk -F'=' '{print $1}')
    component_name=$(bin/emit_stack_name ${template_name})
    cfn_stack_names=($(bin/get_cfn_stack_names.sh ${orchestrator_name} ${env_repo_name/gcb_environment-/} ${stack_name/gcb_tech_stack-/} ${component_name}))
    for cfn_stack in "${cfn_stack_names[@]}"; do
      echo "deleting cfn stack: ${cfn_stack} ..."
      bin/delete_cfn_stack ${cfn_stack}
    done
  done
}

_destroy_env() {
  declare -a env_runlist=($(./bin/get_env_run_list ${env_manifest_file} tech_stacks))
  _check_run_list "environment"
  for (( idx=${#env_runlist[@]}-1 ; idx>=0 ; idx-- )); do
    stack_name=${env_runlist[$idx]}
    stack_manifest_file="${stack_basedir}${stack_name}/${manifest_file_name}"
    _destroy_stack
  done
}

###################################
# MAIN
# destroy_stack.sh orchestrator_name env_repo_name [stack_name]

orchestrator_name=${1}
env_repo_name=${2}
stack_name=${3}

[ -z ${orchestrator_name} ] && error "Error: Please provide an orchestrator name!"
[ -z ${env_repo_name} ] && error "Error: Please provide an environment name!"
[ -z ${AWS_REGION} ] && error "Please be sure AWS_REGION is set in the environment"
export AWS_DEFAULT_REGION=${AWS_REGION}

stack_basedir=tech_stacks/
manifest_file_name=manifest.yml
env_manifest_file=environments/${env_repo_name}/manifest.yml
destroy_summary="the environment ${env_repo_name}"

if [ -z ${stack_name} ]; then
  _confirm "${destroy_summary}"
  _destroy_env
else
  destroy_summary="the tech_stack ${stack_name} for ${destroy_summary}"
  stack_manifest_file="${stack_basedir}${stack_name}/${manifest_file_name}"
  _confirm "${destroy_summary}"
  _destroy_stack
fi

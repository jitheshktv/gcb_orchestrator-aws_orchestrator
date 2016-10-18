#!/usr/bin/env bash

set -e

## hard coded for now, should convert these to a cookbook attributes (aka tempalate)
stack_basedir=tech_stacks/
metadata_file_name=metadata.yml
manifest_file_name=manifest.yml
env_manifest_file_name=environment/manifest.yml

## quick and dirty error handler
error(){ echo ${1};exit 1; }

[ -z ${AWS_REGION} ] && error "Please be sure AWS_REGION is set in the environment"

## make sure the stack_name is passed to the script
[ -z ${1} ] && error "Error: Please provide a tech_stack name!"
[ -z ${2} ] && error "Error: Please provide an environment name!"
stack_name=${1}
tier_orig=${2}
TIER=${tier_orig//_/}

stack_metadata_file="${stack_basedir}${stack_name}/${metadata_file_name}"
stack_manifest_file="${stack_basedir}${stack_name}/${manifest_file_name}"
env_manifest_file="${stack_basedir}${stack_name}/${env_manifest_file_name}"

## check for metadata file
[ -f ${stack_metadata_file} ] || error "Error: Can not find metadata for tech_stack at ${stack_metadata_file}"

## check for manifest file
[ -f ${stack_manifest_file} ] || error "Error: Can not find manifest for tech_stack at ${stack_manifest_file}"

## check for env manifest file
[ -f ${env_manifest_file} ] || error "Error: Can not find environment manifest for tech_stack at ${env_manifest_file}"

bundle install

## get runlist from manifest
declare -a runlist=($(./bin/get_run_list ${stack_manifest_file} run_list))
declare -a db_conn_params

printf '%s\n' "${runlist[@]}"

if [[ ${#runlist[@]} -eq 0 ]];
then
  echo "nothing in the runlist, bailing"
  exit 1
fi

# if everything just reconverges should be ok to just start this from scratch?
rm -f inventory/in_progress.yml || true

## handle chef cookbooks
for item in "${!runlist[@]}"; do
  child_component_type=$(echo ${runlist[$item]} | awk -F'=' '{print $2}')
  if [[ "${child_component_type}" = "chef_cookbook" ]]; then
    cookbook=$(echo ${runlist[$item]} | awk -F'=' '{print $3}')
    echo "cookbook="$cookbook
    ./bin/chef_handler.sh process ${stack_name} ${cookbook} ${TIER}
    if [ $? -ne 0 ]; then
      echo "Error running chef_handler process: $1" >&2
      exit $?
    fi
    # append the returned artifact id to the cookbook name
    runlist[$item]=${runlist[$item]}"="$(./bin/chef_handler.sh push ${stack_name} ${cookbook} ${TIER})
  fi
done

## handle cfn templates related to chef cookbooks
for item in ${!runlist[@]}; do
  template=$(echo ${runlist[$item]} | awk -F'=' '{print $1}')
  child_component_type=$(echo ${runlist[$item]} | awk -F'=' '{print $2}')
  if [ -f inventory/repo_bucket.yml ];
  then
    artifact_bucket=$(./bin/yaml_get inventory/repo_bucket.yml ArtifactBucketName)
  else
    artifact_bucket=""
  fi
  echo "child_component_type=${child_component_type}"
  #if the cfn template has an associated chef cookbook or no associated executables
  if [[ "${child_component_type}" = "chef_cookbook" || -z "${child_component_type}" ]]; then
    cookbook=$(echo ${runlist[$item]} | awk -F'=' '{print $3}')
    artifact_id=$(echo ${runlist[$item]} | awk -F'=' '{print $4}')
    ./bin/cfn_simple_handler.sh "${stack_name}" "${template}" "${TIER}" "${artifact_id}" "${artifact_bucket}" "${cookbook}"
  fi
  #if the cfn template has an associated oracle script
  if [[ "${child_component_type}" = "oracle_script" ]]; then
    sql_script=$(echo ${runlist[$item]} | awk -F'=' '{print $3}')
    cookbook=""
    artifact_id=""
    ./bin/cfn_simple_handler.sh "${stack_name}" "${template}" "${TIER}" "${artifact_id}" "${artifact_bucket}" "${cookbook}"
    # data base should be up, so run the associated sql script
    stacks_dir=$(pwd)/${stack_basedir}
    tech_stack_dir=${stacks_dir}${stack_name}
    script_path=${tech_stack_dir}/oracle/${sql_script}
    param_path=tech_stacks/${stack_name}/parameters/database
    db_conn_params=($(./bin/get_oracle_conn_params ${tech_stack_dir}/${env_manifest_file_name} ${param_path}))
    ./bin/oracle_handler.sh script "${db_conn_params[0]}" "${db_conn_params[1]}" "${db_conn_params[2]}" "${db_conn_params[3]}" "${db_conn_params[4]}" "${script_path}"
  fi
done


#./bin/onprem_routing_and_security.sh

#./bin/s3_prep.sh
#./bin/chef_bundle_push.sh
#./bin/rpm_bundle_push.sh
#./bin/app_bundle_push.sh
#
#./bin/cfn_server_handler.sh

mv inventory/in_progress.yml inventory/in_progress.yml.old

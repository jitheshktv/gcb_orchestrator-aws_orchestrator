#!/usr/bin/env bash

set -e
set -x

tech_stack_name=${1}
template=${2}
tier_name=${3}

artifact_ids=${4}
artifact_bucket=${5}
chef_recipe=${6}

timestamp=$(date +%s)

error(){ echo ${1};exit 1; }

[ -z ${ORCHESTRATOR_NAME} ] && echo "ERROR: please export ORCHESTRATOR_NAME in your environment" && exit 2

required_arguments=(tech_stack_name tier_name AWS_REGION)
for arg in "${required_arguments[@]}";
do
  if [[ -z ${!arg} ]];
  then
    error "The argument ${arg} must be set"
  fi
done

  cat <<END > inventory/tmpartifactparameters.yml
---
OrchestratorName: ${ORCHESTRATOR_NAME}
ArtifactIdList: ${artifact_ids}
ArtifactBucketName:  ${artifact_bucket}
ChefRecipe: ${chef_recipe}
END


#################################################################################################

compute_stack_template_name() {
  local stack_name
  local layer_name
  layer_name=$(bin/emit_layer_name ${template})
  if [[ ${layer_name} == server ]];
  then
    stack_name=${ORCHESTRATOR_NAME}-${tier_name}-${contracted_tech_stack_name}-$(bin/emit_stack_name ${template})-${timestamp}
  else
    stack_name=${ORCHESTRATOR_NAME}-${tier_name}-${contracted_tech_stack_name}-$(bin/emit_stack_name ${template})
  fi

  echo ${stack_name//_/}
}

merge_stack_parameters() {
  # until we can integrate something else based upon separate environment repos
  local environment_metadata="${stack_basedir}/${tech_stack_name}/environment/manifest.yml"

  local stack_metadata="${stack_basedir}/${tech_stack_name}/metadata.yml"

  # intentionally not local - global side effect
  in_progress_metadata="inventory/in_progress.yml"

  set +e
  bin/yaml_cut ${environment_metadata} tech_stacks/${tech_stack_name}/parameters/shared > inventory/env_shared.yml
  bin/yaml_cut ${environment_metadata} tech_stacks/${tech_stack_name}/parameters/database > inventory/env_database.yml
  bin/yaml_cut ${environment_metadata} tech_stacks/${tech_stack_name}/parameters/server > inventory/env_server.yml
  set -e

  for yml_file in ${stack_metadata} inventory/env_shared.yml inventory/env_database.yml inventory/env_server.yml inventory/orchestrator_kms_goodies.yml inventory/orchestrator_client_role.yml inventory/repo_bucket.yml;
  do
    [ -f ${in_progress_metadata} ] || echo '---' > ${in_progress_metadata}
    if [[ -s ${yml_file} ]]; then
      bin/yaml_merge ${yml_file} ${in_progress_metadata} > ${in_progress_metadata}.tmp
      mv ${in_progress_metadata}.tmp ${in_progress_metadata}
    fi
  done
}

###
# Runs json rules against the cloudformation template using the ruleset
# determined by the "layer" name embedded in the tech stack name (e.g. network, database)
#
# errors out if any rule violations found
check_cfn_compliance() {
  local template=${1}
  local json_to_check=${2}

  echo AWS CLI Validation results for: ${template}
  aws cloudformation validate-template --template-body file://${json_to_check} \
                                       --region ${AWS_REGION}

  set +e
  layer_name=$(bin/emit_layer_name ${template})
  json_rules --input-json-path ${json_to_check} \
             --rules-directory cfn-validations/${layer_name} > compliance_results.json

  if [[ $? != 0 ]];
  then
    error "Cfn compliance failed for ${template}.  Please see compliance_results.json for details"
  fi
  set -e
}

check_compliance_for_cfndsl() {
  local path_to_cfndsl="${stack_cfndir}/${template}"

  local json_output=${path_to_cfndsl}.json.tmp
  cfndsl -y ${in_progress_metadata} \
         ${path_to_cfndsl} > ${json_output}

  check_cfn_compliance ${template} ${json_output}
  rm ${json_output}
}

check_compliance_for_template() {
  if [[ ${template} =~ ^.*_dsl\.rb$ ]];
  then
    check_compliance_for_cfndsl
  elif [[ ${template} =~ ^.*\.json$ ]];
  then
    check_cfn_compliance ${template} "${stack_cfndir}/${template}"
  fi
}

converge_template() {
  if [[ ${template} =~ ^.*_dsl\.rb$ ]];
  then
    converge_cfndsl ${template}
  elif [[ ${template} =~ ^.*\.json$ ]];
  then
    converge_vanilla_cfn ${template}
  fi
}

###
# Creates a CloudFormation stack from a vanilla CloudFormation json specification.
# If the stack doesn't exist, it creates it.  If it exists, it updates it.
converge_vanilla_cfn() {
  local template=${1}

  local stack_name
  stack_name=$(compute_stack_template_name)

  echo Converging ${template} as ${stack_name}

  bin/convert_snake_case_to_camel_case ${in_progress_metadata} > ${in_progress_metadata}.camel.tmp

  bin/yaml_merge ${in_progress_metadata}.camel.tmp inventory/tmpartifactparameters.yml > ${in_progress_metadata}.camel

  cfn_converge --path-to-stack "${stack_cfndir}/${template}" \
               --stack-name ${stack_name} \
               --path-to-yaml ${in_progress_metadata}.camel \
               --strip-extra-parameters > inventory/cfn_vanilla_output.yml

  bin/yaml_merge ${in_progress_metadata} inventory/cfn_vanilla_output.yml > ${in_progress_metadata}.tmp
  mv ${in_progress_metadata}.tmp ${in_progress_metadata}

  rm ${in_progress_metadata}.camel*
}


###
# Creates a CloudFormation stack from a cfndsl specification.
# If the stack doesn't exist, it creates it.  If it exists, it updates it.
converge_cfndsl() {
  local template=${1}

  local stack_name
  stack_name=$(compute_stack_template_name)

  local path_to_cfndsl="${stack_cfndir}/${template}"

  echo Converging ${template} as ${stack_name}

  bin/yaml_merge ${in_progress_metadata} inventory/tmpartifactparameters.yml > ${in_progress_metadata}.with_artifact

  cfndsl_converge --path-to-stack ${path_to_cfndsl} \
                  --stack-name ${stack_name} \
                  --path-to-yaml ${in_progress_metadata}.with_artifact > inventory/cfndsl_output.yml

  bin/yaml_merge ${in_progress_metadata} inventory/cfndsl_output.yml > ${in_progress_metadata}.tmp
  mv ${in_progress_metadata}.tmp ${in_progress_metadata}
}

pre_verify_cfn_resource_creation() {
  local spec_directory
  spec_directory=preverify_spec

  run_specs ${spec_directory}
}

verify_cfn_resource_creation() {
  local spec_directory
  spec_directory=spec

  run_specs ${spec_directory}
}

run_specs() {
  local spec_directory
  spec_directory=$1

  local template_spec
  template_spec=${template//.json/}
  template_spec=${template_spec//dsl.rb/dsl}
  template_spec=${template_spec}_spec.rb

  pushd ${stack_cfndir}
    if [[ -d ${spec_directory} ]];
    then
      if [[ -f  ${spec_directory}/${template_spec} ]];
      then
        echo Running RSpec/awspec tests in cfn/ ${spec_directory} against ${template}

        bundle install
        INVENTORY_FILE=../../../${in_progress_metadata} rspec ${spec_directory}/${template_spec}
      else
        echo No tests found for ${template} in ${spec_directory} i.e. no ${template_spec} to be found, skipping...
      fi
    else
      echo No cfn/${spec_directory} directory found in tech stack, skipping...
    fi
  popd
}
#################

# drop all underscore and hyphen to use in cfn stack name
contracted_tech_stack_name=${tech_stack_name//_/}
contracted_tech_stack_name=${contracted_tech_stack_name//-/}

stack_basedir=$(pwd)/tech_stacks
stack_cfndir="${stack_basedir}/${tech_stack_name}/cfn"

if [[ ! -f "${stack_cfndir}/${template}" ]];
then
  error "The template ${template} does not exist in ${stack_cfndir}"
fi

# json-rules built from source and stored in /opt/json-rules
# with a proper gem repo, this should be in the Gemfile for bundler instead
gem install /opt/json-rules/json-rules-0.0.0.gem --conservative

bundle install

merge_stack_parameters

#check_compliance_for_template

pre_verify_cfn_resource_creation

converge_template

verify_cfn_resource_creation

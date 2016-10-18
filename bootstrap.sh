#!/usr/bin/env bash
set -ex

tech_stack_name=${1}
orch_home=/orchestrator
stacks_dir=${orch_home}/tech_stacks
git_url='https://github.com/jitheshktv'

error(){ echo ${1};exit 1; }

required_arguments=(tech_stack_name)
for arg in "${required_arguments[@]}"; do
    if [[ -z ${!arg} ]];
    then
      error "The argument ${arg} must be set"
    fi
done

[ -z ${AWS_REGION} ] && error "Please be sure AWS_REGION is set in the environment"
[ -z ${ORCHESTRATOR_NAME} ] && error "Please be sure ORCHESTRATOR_NAME is set in the environment"
[ -z ${ENV_REPO_NAME} ] && error "Please be sure ENV_REPO_NAME is set in the environment"

chmod -R 755 bin

# clone and inject the env and tech_stack repos
if [[ "${2}" = "clone" ]]; then
  [[ -d "${stacks_dir}" ]] || mkdir -p ${stacks_dir}

  pushd ${stacks_dir}

  # wipe the stack and env dirs
  rm -rf ${tech_stack_name}
  rm -rf ${ENV_REPO_NAME}

  # clone the env repo
  git clone ${git_url}/${ENV_REPO_NAME}.git

  # clone the stack repo
  git clone ${git_url}/${tech_stack_name}.git

  # inject the env manifest into the tech stack
  mkdir ${tech_stack_name}/environment && cp -r ${ENV_REPO_NAME}/* "$_"

  popd

  mkdir -p environments && mv ${stacks_dir}/${ENV_REPO_NAME} environments/${ENV_REPO_NAME}
  exit
fi

./run_stack.sh ${tech_stack_name} ${ENV_REPO_NAME}

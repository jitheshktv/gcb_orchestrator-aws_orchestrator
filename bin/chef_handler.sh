#!/usr/bin/env bash

set -e
set -x

_validate() {
  echo "chef_handler: validating cookbook..."
  [[ ! -d "${cookbook_dir}" ]] && echo "ERROR: cookbook ${cookbook_name} not found" && exit 1
  [[ ! -f "${cookbook_dir}"/Berksfile ]] && echo "ERROR: Berksfile not found in cookbook ${cookbook_name}" && exit 1
  [[ ! -f "${cookbook_dir}"/metadata.rb ]] && echo "ERROR: metadata.rb not found in cookbook ${cookbook_name}" && exit 1
  return 0
}

_test() {
  echo "chef_handler: testing cookbook..."
  #create test dir if it doesn't exist
  [[ -d "${test_dir}" ]] || mkdir -p ${test_dir}
  ## run tests
  export COOKBOOK=${cookbook_name}
  export DOCKER_IMAGE=${docker_image}
  cp -r ${cookbook_dir} ${test_dir}
  cp -f ${kitchen_config_dir}/.kitchen.yml ${test_dir}/${cookbook_name}
  # if [[ $(docker images | grep ${docker_image} | wc -l) -eq 0 ]]; then
  #   [[ -f ${test_dir}/${docker_image}.tar.gz ]] || aws s3 cp s3://${docker_bucket}/${docker_image}.tar.gz ${test_dir}/${docker_image}.tar.gz
  #   (cd ${test_dir} && tar xfz ${docker_image}.tar.gz && sudo docker load -i ${docker_image})
  # fi
  # (cd ${test_dir}/${cookbook_name} && ${kitchen_command})
  return 0
}

_bundle() {
  >&2 echo "chef_handler: bundling cookbook..."
  #create dist dir if it doesn't exist
  [[ -d "${artifact_base}" ]] || mkdir -p ${artifact_base}
  #run berks vendor for the cookbook
  (cd ${test_dir}/${cookbook_name} && ${berks_command})
}

_push() {
  push_result=$("${bin_dir}"/artifact_handler.sh push "${artifact_base}"/"${artifact_dir}" "${tier_name}")
  if [[ $? -eq 0 ]]; then
    echo ${push_result} && return 0
  else
    echo "" && exit 1
  fi
}

_clean() {
  >&2 echo "chef_handler: cleaning workspace..."
  (cd ${test_dir} && rm -rf ${cookbook_name})
  (cd ${dist_dir} && rm -rf ${cookbook_name})
}

###################################
# MAIN
# chef_handler.sh <action> <parameters>

  action=${1}
  tech_stack_name=${2}
  cookbook_name=${3}
  tier_name=${4}
  stack_dir=tech_stacks/${tech_stack_name}
  cookbook_dir=${stack_dir}/chef/cookbooks/${cookbook_name}
  test_dir=${stack_dir}/test
  dist_dir=${stack_dir}/dist
  bin_dir=./bin
  artifact_base=$(pwd)/${dist_dir}/${cookbook_name}
  artifact_dir=cookbooks

  kitchen_config_dir=kitchen_config
  kitchen_command="kitchen test centos"
  berks_command="berks vendor ${artifact_base}/${artifact_dir}"

  docker_bucket=${DOCKER_BUCKET_NAME:-"orchestrator-resources/docker"}
  docker_image=orchestrator_centos6.7

  error(){ echo ${1};exit 1; }

  required_arguments=(tech_stack_name cookbook_name tier_name AWS_REGION)
  for arg in "${required_arguments[@]}";
  do
    if [[ -z ${!arg} ]];
    then
      error "The argument ${arg} must be set"
    fi
  done

  if [[ "${action}" = 'push' ]];
  then
    _push && _clean
  else
    _validate && _test && _bundle
  fi

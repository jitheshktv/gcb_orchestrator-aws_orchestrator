#!/usr/bin/env bash

set -e

orchestrator_name=${1}
env_name=${2}
tech_stack_name=${3}
component_name=${4}

error(){ echo ${1};exit 1; }

required_arguments=(orchestrator_name tech_stack_name env_name component_name AWS_REGION)
for arg in "${required_arguments[@]}";
do
  if [[ -z ${!arg} ]];
  then
    error "The argument ${arg} must be set"
  fi
done

export AWS_DEFAULT_REGION=${AWS_REGION}

jq_query1='.StackSummaries[]'
jq_query2='select(.StackStatus != "DELETE_COMPLETE").StackName'
jq_query3="match(\"${orchestrator_name}.*${env_name}.*${tech_stack_name}.*${component_name}.*\").string"

aws cloudformation list-stacks | jq "${jq_query1} | ${jq_query2} | ${jq_query3}" | tr '\n' ' ' | tr -d '"'

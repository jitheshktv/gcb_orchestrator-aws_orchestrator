#!/bin/bash
set -o pipefail

[ "$(uname -a|awk '{print $1}')" != "Linux" ] && echo "only works on Linux" && exit 3
set -e
set -x

### Hardcoded for now:
[ -z ${ORCHESTRATOR_NAME} ] && echo "ERROR: please export ORCHESTRATOR_NAME in your environment" && exit 2

orchestrator_local_path="orchestrator"

ensure_orchestrator_client_role() {
  stack_name=$(get_orchestrator_id)-orchestrator-client-role
  cfndsl_converge --path-to-stack lib/cfndsl/orchestrator_roles_dsl.rb \
                  --stack-name ${stack_name} > inventory/orchestrator_client_role.yml
}

get_orchestrator_id() {
  echo "${ORCHESTRATOR_NAME}-${environment}"
}

get_bucket_name() {
  #we need a unique way to consistently identify this orchestrator
  #this isnt how we should do this, for now its hard coded
  #there needs to be an environment prep or something that sets
  #variables at run time
  bucket_name="$(get_orchestrator_id)_artifacts"
  echo ${bucket_name//_/-}
}

get_artifact_staging_path() {
  local staging_path="/${orchestrator_local_path}/${environment}_workspace/artifact_staging/"
  [ -d ${staging_path} ] || mkdir -p ${staging_path}
  echo "${staging_path}"
}

ensure_bucket() {

  repo_bucket_name=$(get_bucket_name)
  orchestrator_role_arn=$(bin/get_local_role_arns)
  orchestrator_client_role_arn=$(./bin/yaml_get inventory/orchestrator_client_role.yml OrchestratorClientRoleArn)

  cat <<END > inventory/tmpbucket.yml
---
RepoBucketName: ${repo_bucket_name}
OrchestratorRoleArn: ${orchestrator_role_arn}
OrchestratorClientRoleArn: ${orchestrator_client_role_arn}
END

  stack_name=$(get_bucket_name)
  cfndsl_converge --path-to-stack lib/cfndsl/repo_bucket_dsl.rb \
                  --path-to-yaml inventory/tmpbucket.yml \
                  --stack-name ${stack_name} > inventory/repo_bucket.yml
}

generate_key() {
  openssl rand -hex 256
}

get_sha() {
  [ -z $1 ] && echo "###ERROR need something to sha, please specify path" && exit 2
  local source=${1}

  if [ -e ${source} ] ; then
    sha="$(find ${source} -type f |xargs sha256sum|awk '{print $1}'|sha256sum|awk '{print $1}')"
    echo "${sha}"
  else
     echo "###ERROR please be sure you are trying to get sha of a file or directory" && exit 2
  fi
}

get_kms_key_alias() {
  orchestrator_id=$(get_orchestrator_id)
  echo "alias/${orchestrator_id}"
}

ensure_kms_key() {

  orchestrator_role_arn=$(bin/get_local_role_arns)
  orchestrator_client_role_arn=$(./bin/yaml_get inventory/orchestrator_client_role.yml OrchestratorClientRoleArn)

  cat <<END > inventory/tmpkms.yml
---
OrchestratorRoleArn: ${orchestrator_role_arn}
OrchestratorClientRoleArn: ${orchestrator_client_role_arn}
END

  stack_name=$(get_orchestrator_id)-kms
  cfndsl_converge --path-to-stack lib/cfndsl/kms_policy_dsl.rb \
                  --path-to-yaml inventory/tmpkms.yml \
                  --stack-name ${stack_name} > inventory/orchestrator_kms_goodies.yml

  if [ $(aws kms list-aliases --region ${AWS_REGION} --output text --query "Aliases[?AliasName=='$(get_kms_key_alias)']"|wc -l) -eq 0 ] ;then
    key_id=$(./bin/yaml_get inventory/orchestrator_kms_goodies.yml OrchestratorKMSKey)
    kms_key_alias="$(get_kms_key_alias)"
    aws kms create-alias --region ${AWS_REGION} --target-key-id "${key_id}" --alias-name "${kms_key_alias}"
  fi
}

get_kms_key_id() {
  ensure_kms_key
  kms_key_alias="$(get_kms_key_alias)"
  aws kms list-aliases --region ${AWS_REGION} --query "Aliases[?AliasName=='${kms_key_alias}'].TargetKeyId" --output text
}

encrypt_with_kms() {
  [ -z ${1} ] && echo "nothing to encrypt!" && exit

  # command substitution doesn't respect set -e when part of a larger command
  kms_key_id=$(get_kms_key_id)

  aws kms encrypt --region ${AWS_REGION} --key-id ${kms_key_id} --output text --query CiphertextBlob --plaintext "${1}"
}

encrypt_and_stage() {
  [ -z ${1} ] && echo "###ERROR need something to encrypt, please specify path" && exit 2
  [[ "${1}" =~ ^\.\..* ]] && echo "###ERROR paths can not start with .. , please specify full path" && exit 2
  local source=${1}

  ## if this is a file or directory, lets pack it up
  if [ -e ${source} ] ; then

    my_sum=$(get_sha ${source})

    ## Name the package with a date and 2 random characters, avoid colisions
    scratch_space=$(get_artifact_staging_path)/$(date +%Y%m%d%H%M%S)$(printf "%02d" $[1 + $[ RANDOM % 99 ]])
    [ -d ${scratch_space} ] || mkdir -p ${scratch_space}
    local source_package="${scratch_space}/packed.tar.gz"

    ## tar up the source
    tar -czf ${source_package} --directory $(dirname ${source}) $(basename ${source})

    ## generate an encryption key and encrypt with openssl and aes256 symetric
    key=$(generate_key)
    openssl enc -aes-256-cbc -salt -in ${source_package} -out ${scratch_space}/${my_sum}.enc -k ${key}

    ## kms encrypt the envelope key and write metadata file
    encrypted_key=$(encrypt_with_kms "${key}")
    if [[ $? != 0 ]];
    then
      error 'encryption failed'
    fi
    echo "${encrypted_key},${my_sum},${source}" > "${scratch_space}/${my_sum}.dat"

    ## make the encrypted envelope and clean up the contents
    cd ${scratch_space}
    artifact_staging_path=$(get_artifact_staging_path)
    tar -czf ${artifact_staging_path}/${my_sum} ${my_sum}.*
    rm -f ./${my_sum}.enc ./${my_sum}.dat ./packed.tar.gz
    cd ${artifact_staging_path}
    rmdir ${scratch_space}

    ## output the package name
    echo "${my_sum}"

  # else, I cant handle anything but files or directories, error
  else
    echo "####ERROR Not a file or directory, please specify a path" && exit 2
  fi

}

is_pushed() {
  ## checks to see if a local artifact is pushed already
  ##  returns 0 if exists up in s3 already
  ##  returns 1 if does not exist
  [ -z ${1} ] && echo "ERROR: nothing to check, please specify a file or directory" && exit 2
  my_sum=$(get_sha ${1})
  s3_object_url="s3://$(get_bucket_name)/${my_sum}"
  if [ $(aws s3 ls ${s3_object_url}|wc -l) -eq 1 ]; then
     ## found sha in artifact bucket return true
     echo 0
  else
     ## did not find sha in artifact bucket return false
     echo 1
  fi
}

fetch() {

  ## make sure we have an input parameter
  [ -z ${1} ] && echo "ERROR: nothing to fetch, please specify sha256sum" && exit 2

  ## TODO add region support
  s3_object_url="s3://$(get_bucket_name)/${1}"
  local_staging_path="$(get_artifact_staging_path)/unpacked/"

  ## check to see if the envelope exists and if so pull it down and stage and unpack it
  [ $(aws s3 ls ${s3_object_url}|wc -l) -eq 0 ] && echo "ERROR: can not find object in s3" && exit 2
  [ -d ${local_staging_path}/${1} ] || mkdir -p ${local_staging_path}/${1}
  cd ${local_staging_path}/${1}/
  aws s3 cp ${s3_object_url} ${local_staging_path}/${1}/ --quiet
  tar -xzf ${1}

  ## kms decrypt the envelope key and decrypt and unpack the package
  key=$(aws kms decrypt --ciphertext-blob fileb://<(cat ${1}.dat |awk -F, '{print $1}'|base64 --decode) --output text --query Plaintext|base64 --decode)
  openssl enc -d -aes-256-cbc -in ${1}.enc -out ${1}.tar.gz -k ${key}
  file=$(cat ${1}.dat|awk -F, '{print $3}')
  tar -xzf ${1}.tar.gz

  ## cleanup
  rm -f ./${1}.enc ./${1}.tar.gz ./${1}.dat ./${1}

  echo "${local_staging_path}/${1}/${file}"
}

##
# PLEASE BEWARE!!!!!
#
# Make sure you don't do anything that emits text to stdout as it will become part of the result returned
# by the push operation.  Want that to only be the artifact id
push() {
  [ -z ${1} ] && echo "ERROR: nothing to push, please specify path" && exit 2
  my_sum=$(encrypt_and_stage ${1})
  ensure_bucket
  ## TODO - Add region support
  bucket_name=$(get_bucket_name)
  artifact_staging_path=$(get_artifact_staging_path)
  aws s3 mv ${artifact_staging_path}/${my_sum} s3://${bucket_name}/ --quiet  --sse aws:kms || exit 2
  echo "${my_sum}"
}

###################################
# MAIN
# artifact_handler.sh <operation> <parameters>

[ -z ${1} ] && echo "usage artifact_handler.sh <operation> [<parameters>]" && exit 2
aws s3 ls > /dev/null ; [[ $? != 0 ]] && echo "ERROR: unable to call s3 ls, something wrong with our AWS access, check aws configure and your iam access" && exit 2

environment=${3}

bundle install > /dev/null 2>&1

ensure_orchestrator_client_role

## RUN Operations
case ${1} in

  ## Will return the name of the s3 bucket used to store artifacts for this orchestrator
  get_bucket_name) get_bucket_name ;;

  ## returns 0 (or true) if the provided file or directory is unchanged since it was last pushed
  is_pushed) shift; is_pushed $@ ;;

  ## will envelope encrypt with kms, and push the file or directory encrypted to S3 and return the sha id
  push) shift; push $@  ;;

  ## will fetch from s3, decrypt and stage the artifact in the working directory
  fetch) shift; fetch $@;;

  *) echo "ERROR: need an operation, doing nothing"; exit 2 ;;

esac

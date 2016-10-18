#!/bin/bash -x

new_tech_stack_name=$1

if [[ -z ${new_tech_stack_name} ]];
then
  echo Must specify name for new tech stack name
  exit 1
fi

tech_stack_dir=tech_stacks/${new_tech_stack_name}
mkdir -p ${tech_stack_dir}

directories=(app bin cfn cfn/preverify_spec cfn/spec chef chef/cookbooks chef/roles chef/databags chef/environments features features/stepdefs)

for directory in "${directories[@]}";
do
  mkdir -p ${tech_stack_dir}/${directory}
  touch ${tech_stack_dir}/${directory}/.for.git
done

cat > ${tech_stack_dir}/dev_env_metadata.yml <<END
---
environment:
  name: dev
  common_parameters:
    VpcId: vpc-xxxxx
    RouteTableId: rtb-xxxxx
    PrivateSubnetIdA: subnet-xxxxxx
    PrivateSubnetIdB: subnet-xxxxxx
    AssociatePublicIpAddr: true
    ImageId: ami-yyyyyyy
END

cat > ${tech_stack_dir}/.gitignore <<END
.idea
.chef
.kitchen
END

cat > ${tech_stack_dir}/manifest.yml <<END
---
run_list:
  - some_recipe

cloudformation_templates:
  - some_cfn.json
  - some_dsl.rb
END

cat > ${tech_stack_dir}/metadata.yml <<END
---
# Environment Related Configuration data
application: some_app

name: some_name
END

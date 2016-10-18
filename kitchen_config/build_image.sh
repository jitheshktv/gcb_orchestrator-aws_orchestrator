#!/bin/bash -ex

docker build -t orchestrator_centos6.7 . > build_output
image_id=$(grep '^Successfully built' build_output | awk '{print $3}')
docker save -o orchestrator_centos6.7 ${image_id}
tar cvfz orchestrator_centos6.7.tar.gz orchestrator_centos6.7

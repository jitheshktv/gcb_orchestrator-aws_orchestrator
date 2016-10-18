#!/usr/bin/env bash

IFS=' ' read -r -a git_urls <<< $(bin/list_tech_stacks|sed 's/.$//')

cd tech_stacks

for tech_stack in ${git_urls[@]};
do
  if [[ -d ./$(basename ${tech_stack}) ]];
  then
    pushd $(basename ${tech_stack})
    git pull
    popd
  else
    git clone "${tech_stack}"
  fi
done

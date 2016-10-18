#!/bin/bash

key=$(openssl rand -base64 32)
aws_kms_id="fce04484-25c7-44a8-8f01-bb54fa55b68d"
test_file="./testfile"
enc_file="./testfile.enc"
encr_key_file="./testfile.kms"

## this dont work yet
openssl enc -aes-256-cbc -salt -in ${test_file} -out ${enc_file} -pass ${key}
aws kms encrypt --key-id ${aws_kms_id} --plaintext "${key}" --output text --query CiphertextBlob|base64 --decode > ${encr_key_file}

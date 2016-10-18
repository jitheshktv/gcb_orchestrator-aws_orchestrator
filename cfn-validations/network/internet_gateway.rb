fail_if_found {
  jq '[.Resources|with_entries(.value.LogicalResourceId = .key)[] | select(.Type == "AWS::EC2::InternetGateway")]|map(.LogicalResourceId)'
  message 'Internet Gateways are always a no-no'
}

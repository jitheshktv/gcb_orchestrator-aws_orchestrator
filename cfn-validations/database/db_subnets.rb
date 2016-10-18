fail_if_found {
  jq '[.Resources|with_entries(.value.LogicalResourceId = .key)[] | select(.Type == "AWS::RDS::DBSubnetGroup" and (.Properties.SubnetIds|length < 2))]|map(.LogicalResourceId)'
  message 'A Db subnet group should have at least 2 subnets'
}

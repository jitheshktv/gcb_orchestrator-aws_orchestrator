require 'json'

CloudFormation {

  Description 'Create role and instance profile for the Orchestrator client'

  ec2_trust_policy_document = {
    'Version' => '2012-10-17',
    'Statement' => [
      {
        'Effect' => 'Allow',
        'Principal' => {
          'Service' => %w(ec2.amazonaws.com)
        },
        'Action' => %w(sts:AssumeRole)
      }
    ]
  }

  IAM_Role('OrchestratorClientRole') {
    AssumeRolePolicyDocument ec2_trust_policy_document
    Path '/'
    Policies JSON.load <<-END
      [
        {
          "PolicyName": "orchestrator-client",
          "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
              {
                "Effect": "Allow",
                "Action": [
                  "s3:GetBucketLocation",
                  "s3:ListAllMyBuckets"
                ],
                "Resource": [
                  "arn:aws:s3:::*"
                ]
              },
              {
                "Sid": "Stmt1392679134000",
                "Effect": "Allow",
                "Action": [
                  "ec2:AuthorizeSecurityGroupEgress",
                  "ec2:AuthorizeSecurityGroupIngress",
                  "ec2:DescribeSecurityGroups",
                  "ec2:RevokeSecurityGroupEgress",
                  "ec2:RevokeSecurityGroupIngress"
                ],
                "Resource": [
                  "*"
                ]
              }
            ]
          }
        }
      ]
     END
  }

  IAM_InstanceProfile('OrchestratorClientInstanceProfile') {
    Path '/'
    Roles [ Ref('OrchestratorClientRole') ]
  }


  %w(OrchestratorClientRole OrchestratorClientInstanceProfile).each do |logical_resource_id|
    Output logical_resource_id,
           Ref(logical_resource_id)

    Output "#{logical_resource_id}Arn",
           FnGetAtt(logical_resource_id, 'Arn')
  end
}

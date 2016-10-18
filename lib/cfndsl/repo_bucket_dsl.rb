CloudFormation {
  RepoBucketName ||= 'wizbangbucket'
  OrchestratorRoleArn ||= 'local-non-ec2'
  OrchestratorClientRoleArn ||= 'wizabangclientrole'

  Description 'Create S3 Bucket and bucket policy for Orchestrator Artifact Repository'

  S3_Bucket('RepositoryBucket') {
    BucketName RepoBucketName
  }

  publish_permissions = []
  unless OrchestratorRoleArn == 'local-non-ec2'
    publish_permissions += [
      {
        'Sid' => 'PublishPermissions',
        'Action' => %w(s3:PutObject s3:PutObjectAcl),
        'Effect' => 'Allow',
        'Resource' => [ "arn:aws:s3:::#{RepoBucketName}/*" ],
        'Principal' => {
          'AWS' => OrchestratorRoleArn
        }
      },
      {
        'Sid' => 'ListArtifactsForPublishRole',
        'Action' => %w(s3:ListBucket),
        'Effect' => 'Allow',
        'Resource' => [ "arn:aws:s3:::#{RepoBucketName}" ],
        'Principal' =>
          {
            'AWS' => OrchestratorRoleArn
          }
      }
    ]
  end

  block_unencrypted_puts = [
    {
      'Sid' => 'DenyIncorrectEncryptionHeader',
      'Action' => %w(s3:PutObject),
      'Effect' => 'Deny',
      'Resource' => [ "arn:aws:s3:::#{RepoBucketName}/*" ],
      'Principal' => '*',
      'Condition' => {
        'StringNotEquals' => {
          's3:x-amz-server-side-encryption' => 'aws:kms'
        }
      }
    },
    {
      'Sid' => 'DenyUnEncryptedObjectUploads',
      'Action' => %w(s3:PutObject),
      'Effect' => 'Deny',
      'Resource' => [ "arn:aws:s3:::#{RepoBucketName}/*" ],
      'Principal' => '*',
      'Condition' => {
        'Null' => {
          's3:x-amz-server-side-encryption' => true
        }
      }
    }
  ]

  fetch_permissions = [
    {
      'Sid' => 'FetchPermissions',
      'Action' => %w(s3:GetObject s3:GetObjectAcl),
      'Effect' => 'Allow',
      'Resource' => [ "arn:aws:s3:::#{RepoBucketName}/*" ],
      'Principal' => {
        'AWS' => OrchestratorClientRoleArn
      }
    },
    {
    'Sid' => 'ListArtifactsForFetchRole',
    'Action' => %w(s3:ListBucket),
    'Effect' => 'Allow',
    'Resource' => [ "arn:aws:s3:::#{RepoBucketName}" ],
    'Principal' =>
      {
        'AWS' => OrchestratorClientRoleArn
      }
    }
  ]

  S3_BucketPolicy('RepositoryBucketPolicy') {
    Bucket Ref('RepositoryBucket')
    PolicyDocument({
                     'Version' => '2012-10-17',
                     'Id' => "#{RepoBucketName}Policy",
                     'Statement' => (fetch_permissions + publish_permissions + block_unencrypted_puts)
                   })
  }

  Output 'ArtifactBucketName',
         Ref('RepositoryBucket')
}

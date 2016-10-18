CloudFormation {
  OrchestratorRoleArn ||= 'arn:aws:iam::648217242815:user/uncle.freddie'
  OrchestratorClientRoleArn ||= 'wizabangclientrole'

  Description 'Create KMS Key for Orchestrator to encrypt artifacts for Artifact Repository'

  encrypt_permissions = [
    {
      'Sid' => 'AdminPermissions',
      'Action' => %w(
        kms:Create*
        kms:Describe*
        kms:Enable*
        kms:List*
        kms:Put*
        kms:Update*
        kms:Revoke*
        kms:Disable*
        kms:Get*
        kms:Delete*
        kms:ScheduleKeyDeletion
        kms:CancelKeyDeletion
      ),
      'Effect' => 'Allow',
      'Resource' => '*',
      'Principal' => {
        'AWS' => OrchestratorRoleArn
      }
    },
    {
      'Sid' => 'AnyoneCanDeleteTemporarily',
      'Action' => %w(
        kms:ScheduleKeyDeletion
      ),
      'Effect' => 'Allow',
      'Resource' => '*',
      'Principal' => '*'
    },
    {
      'Sid' => 'EncryptPermissions',
      'Action' => %w(
        kms:Encrypt
      ),
      'Effect' => 'Allow',
      'Resource' => '*',
      'Principal' => {
        'AWS' => OrchestratorRoleArn
      }
    }
  ]

  decrypt_permissions = [
    {
      'Sid' => 'DecryptPermissions',
      'Action' => %w(kms:Decrypt),
      'Effect' => 'Allow',
      'Resource' => '*',
      'Principal' => {
        'AWS' => OrchestratorClientRoleArn
      }
    }
  ]

  KMS_Key('OrchestratorKMSKey') {
    Description 'This key encrypts artifacts stored in artifact repository aka s3 bucket'

    EnableKeyRotation false
    Enabled true
    KeyPolicy({
                'Version' => '2012-10-17',
                'Id' => 'OrchestratorKeyPolicyId',
                'Statement' => (encrypt_permissions + decrypt_permissions)
              })
  }

  Output 'OrchestratorKMSKey',
         Ref('OrchestratorKMSKey')
}

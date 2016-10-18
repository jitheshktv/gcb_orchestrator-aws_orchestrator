@orchestrator
Feature: Chef Invocation
  As a DevOps user,
  I want to develop a Chef handler (invoker) in the orchestrator
  So I can converge nodes in EC2 that support our application deployments

  Scenario: Storage of distribution units
    * an s3 bucket that orchestrator can has permission to push to
    * the ec2 instances created by the cloudformation must have permission to read from
    * consider versioning and mfa delete?
    * consider a layout for storing objects - tech_stack_name/version etc

  # Berkshelf is your obvious friend here, but this leaves open whether
  # to vendor ahead of time or not
  #
  # the format of the name should probably be based upon the tech stack name
  # and include some extra version or identifier to discriminate things
  # the key is that user data needs to be able to pick out the proper
  # distribution later
  Scenario: Distribution unit creation
    Given a tech stack with (wrapper) cookbooks stored in 'cfn/cookbooks'
      And an s3 bucket to store distribution unit (objects) in
      And the cookbooks have been validated - automated tests and static analysis
     When the tech stack runs
     Then the cookbooks and all dependent cookbooks are packaged together in a distribution unit
      And pushed to an S3 bucket for later retrieval by EC2 user-data execution


  Scenario: Node Convergence - Success
    Given an EC2 instance has been stood up by a cfn template
      And it has knowledge of which tech stack (and version?) it is running in
      And the proper distribution unit has been packaged and published
     When its user-data runs
     Then it will retrieve the chef cookbook distribution unit from the s3 repo
      And execute the run list (run list per distribution, or baked into the user data?)

  Scenario: Node Convergence - Failure
    Given an EC2 instance has been stood up by a cfn template
      And it has knowledge of which tech stack (and version?) it is running in
      And the proper distribution unit has NOT been packaged and published
     When its user-data runs
     Then failure to retrieve the distribution should signal a failure to cfn service

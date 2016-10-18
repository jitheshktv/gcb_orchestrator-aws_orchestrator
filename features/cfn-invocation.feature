@orchestrator
Feature: CloudFormation Template Invocation
  As a DevOps user,
  I want to develop a cloud formation handler (invoker) in the orchestrator
  So I can CREATE (vice UPDATE?) AWS resources to support infrastructure needs

Scenario: Invoke a cfndsl template or raw cloudformation template synchronously from a single-click
  Given a local filesystem path to a cfndsl or vanilla cfn template
    And a collection of parameters:
      | A command separated list of one or more artifact identifiers (output from the artifact handler) |
      | A bucket location to pull the artifacts from                                                    |
      | A chef recipe                                                                                   |
   When I invoke the handler
   Then for cfndsl the parameters will be injected as bindings with no validation
    And for vanilla cfn the parameters will be injected as parameters with no validation whereby extra parameters will not be passed to the template
    And the cfndsl template will be submitted to the CloudFormation service endpoint
    And the handler will wait until the convergence is successful or fails
    And the output values will be emitted to stdout in YAML format in the form:
      |output1: v1|
      |output2: v2|

Scenario: Pre-validation of cfn template invocation based upon type
  Given I invoke the handler on an <layer> type template
    And before convergence is attempted
   When the template violates rules for <layer> type templates
   Then the invocation is stopped with a failure result and explanation

  Examples:
    | layer        |
    | Network      |
    | Security     |
    | IAM (Policy) |
    | Server       |

Scenario: Post-verification of cfn template invocation
  Given I invoke the handler on a template with the name "x_y_dsl.rb" or "x_y.json"
   When the convergence succeeds
   Then the handler will run rspec against spec/x_y_dsl_spec.rb or spec/x_y.spec if it exists
    And fail/pass the build accordingly

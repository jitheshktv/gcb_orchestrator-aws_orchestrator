@orchestrator
Feature: Metadata injection to CloudFormation Template Invocation and Chaining of outputs
  As a DevOps user,
  I want to inject metadata/parameters into the cloud formation handler (invoker) in the orchestrator
    and chain the output of prior stacks to be resolvable by later stacks
  So I can CREATE (vice UPDATE?) AWS resources to support infrastructure needs in an
    environment specific way while supporting proper decomposition of cloudfromation templates

  Some extra thoughts around this story:

  We need a way to store static, non-sensitive "properties" in version control that can control
  the behavior of a given tech stack.

  Beyond these "properties" controlling the behavior of a tech stack, they usually are capturing
  variances across "environments" and as such variances should be minimised to allow
  for reliable testing and promotion.

  On the flip side, sensitive items should not be stored in version control, and anything that is
  dynamic should be discovered some other way (query AWS, query an "inventory" database, etc.)

  There are a variety of components of a tech stack that are going to need parameterisation of some kind
  including the CloudFormation/cfndsl templates and Chef cookbooks.

  For vanilla CloudFormation templates, "parameters" are the mechanism to parameterise the template.  However,
  supplying extra parameters causes template validation to fail.... so instead of failing the orchestrator
  probably needs to figure out which parameters can be supplied, and only supply those.

  As CloudFormation templates run, their output may be useful input to downstream templates, so the
  orchestrator needs to collect these outputs, and apply them to downstream templates.  These outputs
  need to be available for restarting convergence half-way through, but not persistent in a long term way?
  These are "dynamic" in a way, but we have control over them so.... useful to apply these.

  There are probably three classes of these properties:

  * Common to all tech stacks in an environment
  * Particular to a tech stack (static)
  * Outputs from upstream CloudFormation templates in the same tech stack

  To avoid collisions among these three, we can use a prefix convention:

  * common: no prefix
  * per tech stack: <tech stack name>_
  * prior outputs: output_

  CloudFormation parameters cannot include underscore, so x_y will be converted to xY for vanilla
  CloudFormation templates.

  In mantaining the YaML files, not repeating configuration is important but then on the flips side, targeting
  subsets of configuration explicitly for the target component is also a worthy goal.  The latter can lead
  to repeating configuration without some kind of sophisticated inheritance mechanism.... In the trade-off among
  these options, as far as CloudFormaiton parameters - going to favor avoiding replication.

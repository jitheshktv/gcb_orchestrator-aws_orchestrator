require 'socket'
require 'open-uri'
require 'aws-sdk'
require 'timeout'

class LocalRole

  ##
  # Return string NOT_RUNNING_ON_EC2_MAGIC_STRING if the ec2 metadata service doesn't *appear* to be available
  #
  # if creds are missing outright, or if there are creds but no actual instance profile, raise an exception
  #
  # Otherwise return an array of IAM role ARN for the locally assigned instance profile
  #
  def discover
    begin
      return current_user_arn unless is_ec2_metadata_service_available

      # appears to ignore no_proxy - will never want a proxy for link local address
      instance_id = open('http://169.254.169.254/latest/meta-data/instance-id', :proxy => nil).read

      describe_instances_response = ec2.describe_instances instance_ids: [instance_id]

      instance_profile = describe_instances_response.reservations.first.instances.first.iam_instance_profile

      raise 'ec2 instance has no instance profile' if instance_profile.nil?

      get_instance_profile_response = iam.get_instance_profile instance_profile_name: instance_profile_name(instance_profile)

      get_instance_profile_response.instance_profile.roles.map { |role| role.arn }

      # if there is no role, but in ec2 could end up here too
    rescue Aws::Errors::MissingCredentialsError
      raise 'ec2 instance has no credentials'
    end
  end

  private

  def current_user_arn
    iam.get_user.user.arn
  end

  def instance_profile_name(instance_profile)
    instance_profile.arn.split('/')[-1]
  end

  def ec2
    Aws::EC2::Client.new
  end

  def iam
    Aws::IAM::Client.new
  end

  def is_ec2_metadata_service_available
    begin
      Timeout::timeout(15) do
        TCPSocket.open('169.254.169.254', 80)
      end
      true
    rescue Exception
      false
    end
  end
end

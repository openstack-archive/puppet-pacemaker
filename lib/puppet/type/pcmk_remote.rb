require 'puppet/parameter/boolean'

Puppet::Type.newtype(:pcmk_remote) do
  @doc = "Remote resource definition for a pacemaker"

  ensurable

  newparam(:name) do
    desc "A unique name for the resource"
  end

  newparam(:pcs_user) do
    desc "Pcs user to use when authenticating a remote node"
    defaultto ''
  end

  newparam(:pcs_password) do
    desc "Pcs password to use when authenticating a remote node"
    defaultto ''
  end

  newparam(:post_success_sleep) do
    desc "The time to sleep after successful pcs action.  The reason to set
          this is to avoid immediate back-to-back 'pcs resource create' calls
          when creating multiple resources.  Defaults to '0'."

    munge do |value|
      if value.is_a?(String)
        unless value =~ /^[-\d.]+$/
          raise ArgumentError, "post_success_sleep must be a number"
        end
        value = Float(value)
      end
      raise ArgumentError, "post_success_sleep cannot be a negative number" if value < 0
      value
    end

    defaultto 0
  end

  ## borrowed from exec.rb
  newparam(:tries) do
    desc "The number of times to attempt to create a pcs resource.
      Defaults to '1'."

    munge do |value|
      if value.is_a?(String)
        unless value =~ /^[\d]+$/
          raise ArgumentError, "Tries must be an integer"
        end
        value = Integer(value)
      end
      raise ArgumentError, "Tries must be an integer >= 1" if value < 1
      value
    end

    defaultto 1
  end

  newparam(:try_sleep) do
    desc "The time to sleep in seconds between 'tries'."

    munge do |value|
      if value.is_a?(String)
        unless value =~ /^[-\d.]+$/
          raise ArgumentError, "try_sleep must be a number"
        end
        value = Float(value)
      end
      raise ArgumentError, "try_sleep cannot be a negative number" if value < 0
      value
    end

    defaultto 0
  end

  newproperty(:op_params) do
    desc "op parameters"
  end
  newproperty(:meta_params) do
    desc "meta parameters"
  end
  newproperty(:resource_params) do
    desc "resource parameters"
  end
  newproperty(:remote_address) do
    desc "Address for remote resources"
  end
  newproperty(:reconnect_interval) do
    desc "reconnection interval for remote resources"
    munge do |value|
      if value.is_a?(String)
        unless value =~ /^[-\d.]+$/
          raise ArgumentError, "reconnect_interval must be a number"
        end
        value = Float(value)
      end
      raise ArgumentError, "reconnect_interval cannot be a negative number" if value < 0
      value
    end

    defaultto 60
  end

  newparam(:deep_compare, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Whether to enable deep comparing of resource
    When set to true a resource will be compared in full (options, meta parameters,..)
    to the existing one and in case of difference it will be repushed to the CIB
    Defaults to `false`."

    defaultto false
  end

  newparam(:update_settle_secs) do
    desc "The time in seconds to wait for the cluster to settle after resource has been updated
          when :deep_compare kicked in.  Defaults to '600'."

    munge do |value|
      if value.is_a?(String)
        unless value =~ /^[-\d.]+$/
          raise ArgumentError, "update_settle_secs must be a number"
        end
        value = Float(value)
      end
      raise ArgumentError, "update_settle_secs cannot be a negative number" if value < 0
      value
    end

    defaultto 600
  end
end

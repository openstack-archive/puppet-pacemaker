require 'puppet/parameter/boolean'

Puppet::Type.newtype(:pcmk_bundle) do
  @doc = "Resource definition for a pacemaker resource bundle"

  ensurable

  newparam(:name) do
    desc "A unique name for the resource"
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

  newparam(:verify_on_create, :boolean => true, :parent => Puppet::Parameter::Boolean) do
     desc "Whether to verify pcs resource creation with an additional
     call to 'pcs resource show' rather than just relying on the exit
     status of 'pcs resource create'.  When true, $try_sleep
     determines how long to wait to verify and $post_success_sleep is
     ignored.  Defaults to `false`."

     defaultto false
   end

  newproperty(:image) do
    desc "docker image"
  end
  newproperty(:container_options) do
    desc "options to pcs container argument"
  end
  newproperty(:replicas) do
    desc "number of replicas"

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
  end

  newproperty(:masters) do
    desc "number of masters"

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
  end

  newproperty(:options) do
    desc "docker options"
  end
  newproperty(:run_command) do
    desc "dock run command"
  end
  newproperty(:storage_maps) do
    desc "storage maps"
  end
  newproperty(:network) do
    desc "network options"
  end
  newproperty(:location_rule) do
    desc "A location rule constraint hash"
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
  newproperty(:container_backend) do
    desc "Container backend"
    defaultto "docker"
  end
end

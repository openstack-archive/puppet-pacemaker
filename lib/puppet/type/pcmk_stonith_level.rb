require 'puppet/parameter/boolean'

Puppet::Type.newtype(:pcmk_stonith_level) do
  @doc = "Base resource definition for a pacemaker stonith level resource"

  ensurable

  newparam(:name) do
    desc "A unique name for the stonith level"
  end

  newparam(:level) do
    desc "The stonith level"
    munge do |value|
      if value.is_a?(String)
        unless value =~ /^[\d]+$/
          raise ArgumentError, "The stonith level must be an integer"
        end
        value = Integer(value)
      end
      raise ArgumentError, "Level must be an integer >= 1" if value < 1
      value
    end
  end

  newparam(:target) do
    desc "The pacemaker stonith target to apply the level to"
  end

  newparam(:stonith_resources) do
    desc "The array containing the list of stonith devices"
    # FIXME: check for an array of strings
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
end

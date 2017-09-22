require 'puppet/parameter/boolean'

Puppet::Type.newtype(:pcmk_resource_default) do
  @doc = "A default value for pacemaker resource options"

  ensurable

  newparam(:name) do
    desc "A unique name of the option"
  end

  newparam(:value) do
    desc "A default value for the option"
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

end

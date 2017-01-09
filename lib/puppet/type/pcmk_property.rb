require 'puppet/parameter/boolean'

Puppet::Type.newtype(:pcmk_property) do
  @doc = "Base resource definition for a pacemaker property"

  ensurable
  newparam(:name) do
    desc "A unique name for the resource"
  end

  newparam(:property) do
    desc "A unique name for the property"
  end
  newparam(:value) do
    desc "the value for the pacemaker property"
  end
  newparam(:node) do
    desc "Optional specific node to set the property on"
  end

  newparam(:force, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    desc "Wheter to use --force with pcs"

    defaultto false
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
end

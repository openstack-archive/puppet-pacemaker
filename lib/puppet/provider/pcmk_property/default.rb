require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_property).provide(:default) do
  desc 'A base resource definition for a pacemaker property'

  ### overloaded methods
  def create
    property = @resource[:property]
    node = @resource[:node]
    value = @resource[:value]
    cmd = "property set"
    if not_empty_string(@resource[:force])
      cmd += " --force"
    end
    if not_empty_string(node)
      cmd += " --node #{node}"
    end
    cmd += " #{property}=#{value}"
    ret = pcs('create', @resource[:property], cmd, @resource[:tries], @resource[:try_sleep])
    Puppet.debug("property create: #{cmd} -> #{ret}")
    return ret
  end

  def destroy
    property = @resource[:property]
    node = @resource[:node]
    cmd = "property unset"
    if not_empty_string(node)
      cmd += " --node #{node}"
    end
    cmd += " #{property}"
    ret = pcs('delete', @resource[:property], cmd, @resource[:tries], @resource[:try_sleep])
    Puppet.debug("property destroy: #{cmd} -> #{ret}")
    return ret
  end

  def exists?
    property = @resource[:property]
    node = @resource[:node]
    # If the goal is to have the property present, we need to make sure
    # exists? returns false in case the property exists but has a different value
    if @resource[:ensure] == :present
      # This forces the value to be a string (might be a bool)
      value = "#{@resource[:value]}"
    else
      value = ''
    end
    cmd = "property show | grep #{property}"
    if not_empty_string(node)
      cmd += " | grep #{node}"
    end
    if not_empty_string(value)
      cmd += " | grep #{value}"
    end
    cmd += " > /dev/null 2>&1"
    ret = pcs('show', @resource[:property], cmd, @resource[:tries], @resource[:try_sleep])
    Puppet.debug("property exists: #{cmd} -> #{ret}")
    return ret == false ? false : true
  end
end

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
    cmd = "property show"
    # We need to distinguish between per node properties and global ones as the output is
    # different:
    # Cluster Properties:
    #  cluster-infrastructure: corosync
    #  cluster-name: tripleo_cluster
    #  dc-version: 1.1.19-8.el7-c3c624ea3d
    #  have-watchdog: false
    #  maintenance-mode: false
    #  redis_REPL_INFO: controller-0
    #  stonith-enabled: false
    # Node Attributes:
    #  controller-0: cinder-volume-role=true galera-role=true haproxy-role=true rabbitmq-role=true redis-role=true rmq-node-attr-last-known-rabbitmq=rabbit@controller-0
    #  controller-1: cinder-volume-role=true galera-role=true haproxy-role=true rabbitmq-role=true redis-role=true rmq-node-attr-last-known-rabbitmq=rabbit@controller-1
    #  controller-2: cinder-volume-role=true galera-role=true haproxy-role=true rabbitmq-role=true redis-role=true rmq-node-attr-last-known-rabbitmq=rabbit@controller-2
    if not_empty_string(node)
      cmd += " | grep -e '#{node}:.*#{property}=#{value}'"
    else
      cmd += " | grep -e '#{property}:.*#{value}'"
    end
    cmd += " > /dev/null 2>&1"
    ret = pcs('show', @resource[:property], cmd, @resource[:tries], @resource[:try_sleep])
    Puppet.debug("property exists: #{cmd} -> #{ret}")
    return ret == false ? false : true
  end
end

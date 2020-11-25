require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_remote).provide(:default) do
  desc 'A remote resource definition for pacemaker resource'

  def build_pcs_auth_cmd()
    if @resource[:pcs_user] == '' or @resource[:pcs_password] == ''
      raise(Puppet::Error, "When using the new pcs cluster node backend for remotes " +
            "'pcs_user' and 'pcs_password must be both defined (#{@resource[:pcs_user]} " +
            "#{@resource[:pcs_password]})")
    end
    # Build the 'pcs resource create' command.  Check out the pcs man page :-)
    cmd = 'host auth ' + @resource[:name]
    if not_empty_string(@resource[:remote_address])
      cmd += ' addr=' + @resource[:remote_address]
    end
    cmd += ' -u ' + @resource[:pcs_user] + ' -p "' + @resource[:pcs_password] + '"'
    cmd
  end

  def build_pcs_remote_cmd()
    resource_params = @resource[:resource_params]
    meta_params = @resource[:meta_params]
    op_params = @resource[:op_params]

    # Build the 'pcs resource create' command.  Check out the pcs man page :-)
    cmd = 'cluster node add-remote ' + @resource[:name]
    if not_empty_string(@resource[:remote_address])
      cmd += ' ' + @resource[:remote_address]
    end
    # reconnect_interval always has a default
    cmd += " reconnect_interval=#{@resource[:reconnect_interval]}"
    if not_empty_string(resource_params)
      cmd += ' ' + resource_params
    end
    if not_empty_string(meta_params)
      cmd += ' meta ' + meta_params
    end
    if not_empty_string(op_params)
      cmd += ' op ' + op_params
    end
    cmd
  end

  ### overloaded methods
  def initialize(*args)
    super(*args)
    Puppet.debug("puppet-pacemaker: initialize()")
    # Hash to store the existance state of each resource
    @resources_state = {}
  end

  def create
    did_resource_exist = @resources_state[@resource[:name]] == PCMK_NOCHANGENEEDED

    cmd_auth = build_pcs_auth_cmd()
    cmd_remote = build_pcs_remote_cmd()

    pcs_without_push('create', @resource[:name], cmd_auth, @resource[:tries],
        @resource[:try_sleep], @resource[:post_success_sleep])
    pcs_without_push('create', @resource[:name], cmd_remote, @resource[:tries],
        @resource[:try_sleep], @resource[:post_success_sleep])
  end

  def destroy
    cmd = 'cluster node delete-remote ' + @resource[:name]
    pcs_without_push('delete', @resource[:name], cmd, @resource[:tries],
        @resource[:try_sleep], @resource[:post_success_sleep])
  end

  def exists?
    @resources_state[@resource[:name]] = resource_exists?
    did_resource_exist = @resources_state[@resource[:name]] == PCMK_NOCHANGENEEDED
    Puppet.debug("Exists: resource #{@resource[:name]} exists "\
                 "#{@resources_state[@resource[:name]]} "\
                 "resource deep_compare: #{@resource[:deep_compare]}")
    if did_resource_exist
      return true
    end
    return false
  end

  def resource_exists?
    cmd = 'resource config ' + @resource[:name] + ' > /dev/null 2>&1'
    ret = pcs('show', @resource[:name], cmd, @resource[:tries],
              @resource[:try_sleep], false, @resource[:post_success_sleep])
    if ret == false then
      return PCMK_NOTEXISTS
    end
    return PCMK_NOCHANGENEEDED
  end

  ### property methods

  # It isn't an easy road if you want to make these true
  # puppet-like resource properties.  Here is a start if you are feeling brave:
  # https://github.com/cwolferh/puppet-pacemaker/blob/pcmk_resource_improvements_try0/lib/puppet/provider/pcmk_resource/default.rb#L64
  def resource_params
    @resource[:resource_params]
  end

  def resource_params=(value)
  end

  def op_params
    @resource[:op_params]
  end

  def op_params=(value)
  end

  def meta_params
    @resource[:meta_params]
  end

  def meta_params=(value)
  end

  def reconnect_interval
    @resource[:reconnect_interval]
  end

  def reconnect_interval=(value)
  end

  def remote_address
    @resource[:remote_address]
  end

  def remote_address=(value)
  end
end

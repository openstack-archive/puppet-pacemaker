require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_resource).provide(:default) do
  desc 'A base resource definition for a pacemaker resource'

  def build_pcs_resource_cmd(update=false)
    resource_params = @resource[:resource_params]
    meta_params = @resource[:meta_params]
    op_params = @resource[:op_params]
    clone_params = @resource[:clone_params]
    group_params = @resource[:group_params]
    master_params = @resource[:master_params]
    location_rule = @resource[:location_rule]
    bundle = @resource[:bundle]

    suffixes = 0
    if clone_params then suffixes +=1 end
    if master_params then suffixes +=1 end
    if group_params then suffixes +=1 end
    if suffixes > 1
      raise(Puppet::Error, "May only define one of clone_params, "+
            "master_params and group_params")
    end
    if update
      create_cmd = ' update '
    else
      create_cmd = ' create '
    end

    if @resource[:force]
      force_cmd = '--force '
    else
      force_cmd = ''
    end
    # Build the 'pcs resource create' command.  Check out the pcs man page :-)
    cmd = force_cmd + 'resource' + create_cmd + @resource[:name] + ' ' + @resource[:resource_type]
    if @resource[:resource_type] == 'remote'
      if not_empty_string(@resource[:remote_address])
        cmd += ' server=' + @resource[:remote_address]
      end
      # reconnect_interval always has a default
      cmd += " reconnect_interval=#{@resource[:reconnect_interval]}"
    end
    if not_empty_string(resource_params)
      cmd += ' ' + resource_params
    end
    if not_empty_string(meta_params)
      cmd += ' meta ' + meta_params
    end
    if not_empty_string(op_params)
      cmd += ' op ' + op_params
    end
    # When a bundle is specified we may not specify clone, master or group
    if bundle
      cmd += ' bundle ' + bundle
    else
      if clone_params
        # pcs 0.10/pcmk 2.0 removed the --clone option
        if Puppet::Util::Package.versioncmp(pcs_cli_version(), '0.10.0') >= 0
          cmd += ' clone'
        else
          cmd += ' --clone'
        end
        if not_empty_string(clone_params)
          cmd += ' ' + clone_params
        end
      end
      if not_empty_string(group_params)
        cmd += ' --group ' + group_params
      end
      if master_params
        cmd += ' --master'
        if not_empty_string(master_params)
          cmd += ' ' + master_params
        end
      end
    end
    cmd
  end

  ### overloaded methods
  def initialize(*args)
    super(*args)
    Puppet.debug("puppet-pacemaker: initialize()")
    # Hash to store the existance state of each resource or location
    @resources_state = {}
    @locations_state = {}
  end

  def create_resource_and_location(location_rule, needs_update=false)
    if needs_update then
      cmd = build_pcs_resource_cmd(update=true)
      pcmk_update_resource(@resource, cmd, '', @resource[:update_settle_secs])
    else
      cmd = build_pcs_resource_cmd()
      if location_rule then
        pcs('create', @resource[:name], "#{cmd} --disabled", @resource[:tries],
            @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
        location_rule_create()
        pcs('create', @resource[:name], "resource enable #{@resource[:name]}", @resource[:tries],
            @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
      else
        pcs('create', @resource[:name], cmd, @resource[:tries],
            @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
      end
    end
  end

  def create
    # We need to probe the existance of both location and resource
    # because we do not know why we're being created (if for both or
    # only for one)
    did_resource_exist = @resources_state[@resource[:name]] == PCMK_NOCHANGENEEDED
    did_location_exist = @locations_state[@resource[:name]] == PCMK_NOCHANGENEEDED
    Puppet.debug("Create: resource exists #{@resources_state[@resource[:name]]} location exists #{@locations_state[@resource[:name]]}")
    needs_update = @resources_state[@resource[:name]] == PCMK_CHANGENEEDED

    cmd = build_pcs_resource_cmd()

    # If both the resource and the location do not exist, we create them both
    # if a location_rule is specified otherwise only the resource
    if not did_location_exist and not did_resource_exist
      create_resource_and_location(location_rule, needs_update)
    # If the location_rule already existed, we only create the resource
    elsif did_location_exist and not did_resource_exist
      create_resource_and_location(false, needs_update)
    # The location_rule does not exist and the resource does exist
    elsif not did_location_exist and did_resource_exist
      if location_rule
        location_rule_create()
      end
    else
      raise Puppet::Error, "Invalid create: #{@resource[:name]} resource exists #{did_resource_exist} "
                           "location exists #{did_location_exist} - location_rule #{location_rule}"
    end
  end

  def destroy
    # Any corresponding location rules will be deleted by
    # pcs automatically, if present
    cmd = 'resource delete ' + @resource[:name]
    pcs('delete', @resource[:name], cmd, @resource[:tries],
        @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
  end

  def exists?
    @locations_state[@resource[:name]] = location_exists?
    @resources_state[@resource[:name]] = resource_exists?
    did_resource_exist = @resources_state[@resource[:name]] == PCMK_NOCHANGENEEDED
    did_location_exist = @locations_state[@resource[:name]] == PCMK_NOCHANGENEEDED
    Puppet.debug("Exists: resource #{@resource[:name]} exists "\
                 "#{@resources_state[@resource[:name]]} "\
                 "location exists #{@locations_state[@resource[:name]]} "\
                 "resource deep_compare: #{@resource[:deep_compare]}")
    if did_resource_exist and did_location_exist
      return true
    end
    return false
  end

  def resource_exists?
    cmd = 'resource ' + pcs_config_or_show() + ' ' + @resource[:name] + ' > /dev/null 2>&1'
    ret = pcs('show', @resource[:name], cmd, @resource[:tries],
              @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
    if ret == false then
      return PCMK_NOTEXISTS
    end
    if @resource[:deep_compare] and pcmk_resource_has_changed?(@resource, build_pcs_resource_cmd(update=true), '') then
      return PCMK_CHANGENEEDED
    end
    return PCMK_NOCHANGENEEDED
  end

  def location_exists?
    bundle = @resource[:bundle]
    # If no location_rule is specified then we treat it as if it
    # always exists
    if not @resource[:location_rule]
      return PCMK_NOCHANGENEEDED
    end
    if bundle
      constraint_name = 'location-' + bundle
    else
      constraint_name = 'location-' + @resource[:name]
      if @resource[:clone_params]
        constraint_name += '-clone'
      elsif @resource[:master_params]
        constraint_name += '-master'
      end
    end
    cmd = "constraint show --full | grep #{constraint_name} > /dev/null 2>&1"
    ret = pcs('show', @resource[:name], cmd, @resource[:tries],
              @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
    return ret == false ? PCMK_NOTEXISTS : PCMK_NOCHANGENEEDED
  end

  def location_rule_create()
    location_cmd = build_pcs_location_rule_cmd(@resource)
    Puppet.debug("location_rule_create: #{location_cmd}")
    pcs('create', @resource[:name], location_cmd, @resource[:tries],
        @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
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

  def group_params
    @resource[:group_params]
  end

  def group_params=(value)
  end

  def master_params
    @resource[:master_params]
  end

  def master_params=(value)
  end

  def clone_params
    @resource[:clone_params]
  end

  def clone_params=(value)
  end

  def location_rule
    @resource[:location_rule]
  end

  def location_rule=(value)
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

  def bundle
    @resource[:bundle]
  end

  def bundle=(value)
  end

end

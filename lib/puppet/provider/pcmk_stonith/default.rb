require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_stonith).provide(:default) do
  desc 'A base resource definition for a pacemaker stonith'

  def initialize(*args)
    super(*args)
    Puppet.debug("puppet-pacemaker: initialize()")
    # Hash to store the existance state of each resource or location
    @resources_state = {}
    @locations_state = {}
  end

  def build_pcs_resource_cmd(update=false)

    name = @resource[:name]
    stonith_type = @resource[:stonith_type]
    pcmk_host_list = @resource[:pcmk_host_list]
    pcs_param_string = @resource[:pcs_param_string]

    if update
      create_cmd = ' update '
    else
      create_cmd = ' create '
    end

    cmd = 'stonith' + create_cmd + name + ' ' + stonith_type + ' '
    if not_empty_string(pcmk_host_list)
      cmd += 'pcmk_host_list=' + pcmk_host_list + ' '
    end
    cmd += @resource[:pcs_param_string]

  end

  def create_resource_and_location(location_rule=false, needs_update=false)
    if needs_update then
      cmd = build_pcs_resource_cmd(update=true)
      pcs('update', name, cmd, @resource[:tries],
          @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
    else
      cmd = build_pcs_resource_cmd()
      if location_rule then
        pcs('create', name, "#{cmd} --disabled", @resource[:tries],
          @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
        stonith_location_rule_create()
        pcs('create', name, "resource enable #{name}", @resource[:tries],
          @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
      else
        pcs('create', name, cmd, @resource[:tries],
          @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
      end
    end
  end


  def create

    # We need to probe the existance of both location and resource
    # because we do not know why we're being created (if for both or
    # only for one)
    did_stonith_resource_exist = @resources_state[@resource[:name]] == PCMK_NOCHANGENEEDED
    did_stonith_location_exist = @locations_state[@resource[:name]] == PCMK_NOCHANGENEEDED

    Puppet.debug("Create: stonith exists #{did_stonith_resource_exist} location exists #{did_stonith_location_exist}")

    needs_update = @resources_state[@resource[:name]] == PCMK_CHANGENEEDED

    # If both the stonith resource and the location do not exist, we create them both
    # if a location_rule is specified otherwise only the resource
    if not did_stonith_location_exist and not did_stonith_resource_exist
      create_resource_and_location(true, needs_update)
    # If the location_rule already existed, we only create the resource
    elsif did_stonith_location_exist and not did_stonith_resource_exist
      create_resource_and_location(false, needs_update)
    # The location_rule does not exist and the resource does exist
    elsif not did_stonith_location_exist and did_stonith_resource_exist
      stonith_location_rule_create()
    else
      raise Puppet::Error, "Invalid create: #{name} stonith resource exists #{did_stonith_resource_exist} "
                           "stonith location exists #{did_stonith_location_exist}"
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
    @locations_state[@resource[:name]] = stonith_location_exists?
    @resources_state[@resource[:name]] = stonith_resource_exists?
    did_stonith_resource_exist = @resources_state[@resource[:name]] == PCMK_NOCHANGENEEDED
    did_stonith_location_exist = @locations_state[@resource[:name]] == PCMK_NOCHANGENEEDED

    Puppet.debug("Exists: stonith resource exists #{did_stonith_resource_exist} location exists #{did_stonith_location_exist}")
    if did_stonith_resource_exist and did_stonith_location_exist
      return true
    end
    return false
  end

  def stonith_resource_exists?
    cmd = 'stonith ' + pcs_config_or_show() + ' ' + @resource[:name] + ' > /dev/null 2>&1'
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

  def stonith_location_exists?
    # We automatically create the resource location constraint only in the case when
    # pcmk_host_list is not empty
    if not_empty_string(@resource[:pcmk_host_list])
      constraint_name = "#{@resource[:name]}"
      cmd = "constraint location | grep #{constraint_name} > /dev/null 2>&1"
      ret = pcs('show', @resource[:name], cmd, @resource[:tries],
                @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
      return ret == false ? false : true
    else
      return true
    end
  end

  def stonith_location_rule_create()
    pcmk_host_list = @resource[:pcmk_host_list]
    nodes_count = crm_node_l().lines.size
    if not_empty_string(pcmk_host_list) and nodes_count > 1 and @resource[:name] != 'watchdog'
      location_cmd = "constraint location #{@resource[:name]} avoids #{pcmk_host_list}=10000"
      Puppet.debug("stonith_location_rule_create: #{location_cmd}")
      pcs('create', @resource[:name], location_cmd, @resource[:tries],
          @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
    end
  end
end

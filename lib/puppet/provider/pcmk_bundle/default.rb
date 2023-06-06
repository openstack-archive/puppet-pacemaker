require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_bundle).provide(:default) do
  desc 'A bundle resource definition for pacemaker'

  def _storage_maps_cmd(storage_maps, update=false)
    return '' if storage_maps == nil or storage_maps.empty?
    cmd = ''
    if update
      add = ' add '
    else
      add = ' '
    end
    storage_maps.each do | key, value |
      cmd += ' storage-map' + add + 'id=' + key + \
             ' source-dir=' + value['source-dir'] + \
             ' target-dir=' + value['target-dir']
      options = value['options']
      if not_empty_string(options)
        cmd += ' options=' + options
      end
    end
    cmd
  end

  def build_pcs_bundle_cmd(update=false)
    image = @resource[:image]
    replicas = @resource[:replicas]
    masters = @resource[:masters]
    promoted_max = @resource[:promoted_max]
    container_options = @resource[:container_options]
    options = @resource[:options]
    run_command = @resource[:run_command]
    storage_maps = @resource[:storage_maps]
    network = @resource[:network]
    location_rule = @resource[:location_rule]
    container_backend = @resource[:container_backend]

    if update
      create_cmd = 'update'
      docker_cmd = ''
    else
      create_cmd = 'create'
      docker_cmd = container_backend
    end

    if @resource[:force]
      force_cmd = '--force '
    else
      force_cmd = ''
    end
    # Build the 'pcs resource create' command.  Check out the pcs man page :-)
    cmd = force_cmd + 'resource bundle ' + create_cmd + ' ' + @resource[:name] + ' container ' + docker_cmd + ' image=' + @resource[:image]
    if replicas
      cmd += " replicas=#{replicas}"
    end
    if masters
      cmd += " masters=#{masters}"
    end
    if promoted_max
      if update
        cmd += " masters="
      end
      cmd += " promoted-max=#{promoted_max}"
    end
    if options
      cmd += ' options="' + options + '"'
    end
    if run_command
      cmd += ' run-command="' + run_command + '"'
    end
    if container_options
      cmd += ' ' + container_options
    end

    # When we're updating a bundle we first dump the CIB, then
    # we remove all the *current* storage-maps for the resource
    # and then we add back the storage-maps passed to us
    cmd += _storage_maps_cmd(storage_maps, update)
    if network
      cmd += ' network ' + network
    end
    cmd
  end

  def build_pcs_bundle_pruning
    cmd = 'resource bundle update ' + @resource[:name]
    # In case of updates due to how pcs manages storage, we need to first remove all
    # the *current* existing storage maps and then readd the puppet defined ones
    live_storage_maps = pcmk_get_bundle_storage_map(@resource[:name])
    if live_storage_maps and !live_storage_maps.empty?
      live_storage_maps.each do | key, value |
        cmd += ' storage-map remove ' + value['id']
      end
      return cmd
    end
    return ''
  end

  ### overloaded methods
  def initialize(*args)
    super(*args)
    Puppet.debug("puppet-pacemaker: initialize()")
    # Hash to store the existance state of each resource or location
    @resources_state = {}
    @locations_state = {}
  end

  def create_bundle_and_location(location_rule, needs_update=false)
    if needs_update then
      cmd = build_pcs_bundle_cmd(update=true)
      pcmk_update_resource(@resource, cmd, build_pcs_bundle_pruning(), @resource[:update_settle_secs])
    else
      cmd = build_pcs_bundle_cmd()
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

    cmd = build_pcs_bundle_cmd()

    # If both the resource and the location do not exist, we create them both
    # if a location_rule is specified otherwise only the resource
    if not did_location_exist and not did_resource_exist
      create_bundle_and_location(location_rule, needs_update)
    # If the location_rule already existed, we only create the resource
    elsif did_location_exist and not did_resource_exist
      create_bundle_and_location(false, needs_update)
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
    Puppet.debug("Exists: bundle #{@resource[:name]} exists "\
                 "#{@resources_state[@resource[:name]]} "\
                 "location exists #{@locations_state[@resource[:name]]} "\
                 "deep_compare: #{@resource[:deep_compare]}")
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
    if @resource[:deep_compare] and pcmk_resource_has_changed?(@resource, build_pcs_bundle_cmd(update=true), build_pcs_bundle_pruning(), true) then
      return PCMK_CHANGENEEDED
    end
    return PCMK_NOCHANGENEEDED
  end

  def location_exists?
    # If no location_rule is specified then we treat it as if it
    # always exists
    if not @resource[:location_rule]
      return PCMK_NOCHANGENEEDED
    end
    constraint_name = 'location-' + @resource[:name]
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
  def image
    @resource[:image]
  end

  def image=(value)
  end

  def replicas
    @resource[:replicas]
  end

  def replicas=(value)
  end

  def masters
    @resource[:masters]
  end

  def masters=(value)
  end

  def promoted_max
    @resource[:promoted_max]
  end

  def promoted_max=(value)
  end

  def options
    @resource[:options]
  end

  def options=(value)
  end

  def container_options
    @resource[:container_options]
  end

  def container_options=(value)
  end

  def run_command
    @resource[:run_command]
  end

  def run_command=(value)
  end

  def storage_maps
    @resource[:storage_maps]
  end

  def storage_maps=(value)
  end

  def network
    @resource[:network]
  end

  def network=(value)
  end

  def location_rule
    @resource[:location_rule]
  end

  def location_rule=(value)
  end

  def container_backend
    @resource[:container_backend]
  end

  def container_backend=(value)
  end
end

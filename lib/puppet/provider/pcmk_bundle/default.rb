require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_bundle).provide(:default) do
  desc 'A bundle resource definition for pacemaker'

  ### overloaded methods
  def create
    image = @resource[:image]
    replicas = @resource[:replicas]
    masters = @resource[:masters]
    container_options = @resource[:container_options]
    options = @resource[:options]
    run_command = @resource[:run_command]
    storage_maps = @resource[:storage_maps]
    network = @resource[:network]
    location_rule = @resource[:location_rule]

    # We need to probe the existance of both location and resource
    # because we do not know why we're being created (if for both or
    # only for one)
    did_location_exist = location_exists?
    did_resource_exist = resource_exists?
    Puppet.debug("Bundle create: resource exists #{did_resource_exist} location exists #{did_location_exist}")

    # Build the 'pcs resource create' command.  Check out the pcs man page :-)
    cmd = 'resource bundle create ' + @resource[:name]+' container docker image=' + @resource[:image]
    if replicas
      cmd += " replicas=#{replicas}"
    end
    if masters
      cmd += " masters=#{masters}"
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

    # storage_maps[id] = {'source' => value, 'target' => value, 'options' => value}
    # FIXME: need to do proper error checking here
    if storage_maps and !storage_maps.empty?
      storage_maps.each do | key, value |
        cmd += ' storage-map id=' + key + \
               ' source-dir=' + value['source-dir'] + \
               ' target-dir=' + value['target-dir']
        options = value['options']
        if not_empty_string(options)
          cmd += ' options=' + options
        end
      end
    end

    if network
      cmd += ' network ' + network
    end

    # If both the resource and the location do not exist, we create them both
    # if a location_rule is specified otherwise only the resource
    if not did_location_exist and not did_resource_exist
      if location_rule
        pcs('create', @resource[:name], "#{cmd} --disabled", @resource[:tries],
            @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
        location_rule_create(location_rule)
        pcs('create', @resource[:name], "resource enable #{@resource[:name]}", @resource[:tries],
            @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
      else
        pcs('create', @resource[:name], cmd, @resource[:tries],
            @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
      end
    # If the location_rule already existed, we only create the resource
    elsif did_location_exist and not did_resource_exist
      pcs('create', @resource[:name], cmd, @resource[:tries],
          @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
    # The location_rule does not exist and the resource does exist
    elsif not did_location_exist and did_resource_exist
      if location_rule
        location_rule_create(location_rule)
      end
    else
      raise Puppet::Error, "Invalid create: #{name} resource exists #{did_resource_exist} "
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
    did_location_exist = location_exists?
    did_resource_exist = resource_exists?
    Puppet.debug("Exists: resource exists #{did_resource_exist} location exists #{did_location_exist}")
    if did_resource_exist and did_location_exist
      return true
    end
    return false
  end

  def resource_exists?
    cmd = 'resource show ' + @resource[:name] + ' > /dev/null 2>&1'
    ret = pcs('show', @resource[:name], cmd, @resource[:tries],
              @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
    return ret == false ? false : true
  end

  def location_exists?
    # If no location_rule is specified then we treat it as if it
    # always exists
    if not @resource[:location_rule]
      return true
    end
    constraint_name = 'location-' + @resource[:name]
    cmd = "constraint list | grep #{constraint_name} > /dev/null 2>&1"
    ret = pcs('show', @resource[:name], cmd, @resource[:tries],
              @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
    return ret == false ? false : true
  end

  def location_rule_create(location_rule)
    # The name that pcs will create is location-<name>[-{clone,master}]
    location_cmd = 'constraint location ' + @resource[:name]
    location_cmd += ' rule'
    if location_rule['resource_discovery']
      location_cmd += " resource-discovery=#{location_rule['resource_discovery']}"
    end
    if location_rule['score']
      location_cmd += " score=#{location_rule['score']}"
    end
    if location_rule['score_attribute']
      location_cmd += " score-attribure=#{location_rule['score_attribute']}"
    end
    if location_rule['expression']
      location_cmd += " " + location_rule['expression'].join(' ')
    end
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

end

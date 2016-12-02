Puppet::Type.type(:pcmk_resource).provide(:default) do
  desc 'A base resource definition for a pacemaker resource'

  ### overloaded methods
  def create
    resource_params = @resource[:resource_params]
    meta_params = @resource[:meta_params]
    op_params = @resource[:op_params]
    clone_params = @resource[:clone_params]
    group_params = @resource[:group_params]
    master_params = @resource[:master_params]
    location_rule = @resource[:location_rule]

    # We need to probe the existance of both location and resource
    # because we do not know why we're being created (if for both or
    # only for one)
    did_location_exist = location_exists?
    did_resource_exist = resource_exists?
    Puppet.debug("Create: resource exists #{did_resource_exist} location exists #{did_location_exist}")

    suffixes = 0
    if clone_params then suffixes +=1 end
    if master_params then suffixes +=1 end
    if group_params then suffixes +=1 end
    if suffixes > 1
      raise(Puppet::Error, "May only define one of clone_params, "+
            "master_params and group_params")
    end

    # Build the 'pcs resource create' command.  Check out the pcs man page :-)
    cmd = 'resource create ' + @resource[:name]+' ' +@resource[:resource_type]
    if not_empty_string(resource_params)
      cmd += ' ' + resource_params
    end
    if not_empty_string(meta_params)
      cmd += ' meta ' + meta_params
    end
    if not_empty_string(op_params)
      cmd += ' op ' + op_params
    end
    if clone_params
      cmd += ' --clone'
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

    # If both the resource and the location do not exist, we create them both
    # if a location_rule is specified otherwise only the resource
    if not did_location_exist and not did_resource_exist
      if location_rule
        pcs('create', "#{cmd} --disabled")
        location_rule_create(location_rule)
        pcs('create', "resource enable #{@resource[:name]}")
      else
        pcs('create', cmd)
      end
    # If the location_rule already existed, we only create the resource
    elsif did_location_exist and not did_resource_exist
      pcs('create', cmd)
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
    pcs('delete', cmd)
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
    ret = pcs('show', cmd)
    return ret == false ? false : true
  end

  def location_exists?
    # If no location_rule is specified then we treat it as if it
    # always exists
    if not @resource[:location_rule]
      return true
    end
    constraint_name = 'location-' + @resource[:name]
    if @resource[:clone_params]
      constraint_name += '-clone'
    elsif @resource[:master_params]
      constraint_name += '-master'
    end
    cmd = "constraint list | grep #{constraint_name} > /dev/null 2>&1"
    ret = pcs('show', cmd)
    return ret == false ? false : true
  end

  def location_rule_create(location_rule)
    # The name that pcs will create is location-<name>[-{clone,master}]
    location_cmd = 'constraint location ' + @resource[:name]
    if clone_params
      location_cmd += '-clone'
    elsif master_params
      location_cmd += '-master'
    end
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
    pcs('create', location_cmd)
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

  def not_empty_string(p)
    p && p.kind_of?(String) && ! p.empty?
  end

  def pcs(name, cmd)
    if name.start_with?("create") && @resource[:verify_on_create]
      return pcs_create_with_verify(name, cmd)
    end
    try_sleep =  @resource[:try_sleep]
    max_tries = name.include?('show') ? 1 : @resource[:tries]
    max_tries.times do |try|
      try_text = max_tries > 1 ? "try #{try+1}/#{max_tries}: " : ''
      Puppet.debug("#{try_text}/usr/sbin/pcs #{cmd}")
      pcs_out = `/usr/sbin/pcs #{cmd} 2>&1`
      if name.include?('show')
        # return output for good exit or false for failure.
        return $?.exitstatus == 0 ? pcs_out : false
      end
      if $?.exitstatus == 0
        sleep @resource[:post_success_sleep]
        return pcs_out
      end
      Puppet.debug("Error: #{pcs_out}")
      if try == max_tries-1
        pcs_out_line = pcs_out.lines.first ? pcs_out.lines.first.chomp! : ''
        raise Puppet::Error, "pcs #{name} failed: #{pcs_out_line}"
      end
      if try_sleep > 0
        Puppet.debug("Sleeping for #{try_sleep} seconds between tries")
        sleep try_sleep
      end
    end
  end

  def pcs_create_with_verify(name, cmd)
    try_sleep = @resource[:try_sleep]
    max_tries = @resource[:tries]
    max_tries.times do |try|
      try_text = max_tries > 1 ? "try #{try+1}/#{max_tries}: " : ''
      Puppet.debug("#{try_text}/usr/sbin/pcs #{cmd}")
      pcs_out = `/usr/sbin/pcs #{cmd} 2>&1`
      if $?.exitstatus == 0
        sleep try_sleep
        cmd_show = "/usr/sbin/pcs resource show "+ @resource[:name]
        Puppet.debug("Verifying with: "+cmd_show)
        `#{cmd_show}`
        if $?.exitstatus == 0
          return pcs_out
        else
          Puppet.debug("Warning: verification of pcs resource creation failed")
        end
      else
        Puppet.debug("Error: #{pcs_out}")
        sleep try_sleep
      end
      if try == max_tries-1
        pcs_out_line = pcs_out.lines.first ? pcs_out.lines.first.chomp! : ''
        raise Puppet::Error, "pcs #{name} failed: #{pcs_out_line}"
      end
    end
  end

end

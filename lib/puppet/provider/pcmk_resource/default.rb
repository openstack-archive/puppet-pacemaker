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

    # do pcs create
    pcs('create', cmd)
  end

  def destroy
    cmd = 'resource delete ' + @resource[:name]
    pcs('delete', cmd)
  end

  def exists?
    cmd = 'resource show ' + @resource[:name] + ' > /dev/null 2>&1'
    pcs('show', cmd)
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

  def not_empty_string(p)
    p && p.kind_of?(String) && ! p.empty?
  end

  def pcs(name, cmd)
    Puppet.debug("/usr/sbin/pcs #{cmd}")
    pcs_out = `/usr/sbin/pcs #{cmd}`
    if $?.exitstatus != 0 && pcs_out.lines.first && ! name.include?('show')
      Puppet.debug("Error: #{pcs_out}")
      raise Puppet::Error, "pcs #{name} failed: #{pcs_out.lines.first.chomp!}" if $?.exitstatus
    end
    # return output for good exit or false for failure.
    $?.exitstatus == 0 ? pcs_out : false
  end

end

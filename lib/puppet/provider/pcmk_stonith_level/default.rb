require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_stonith_level).provide(:default) do
  desc 'A base resource definition for a pacemaker stonith level definition'

  ### overloaded methods
  def create
    level = @resource[:level]
    target = @resource[:target]
    stonith_resources = @resource[:stonith_resources]
    res = stonith_resources.join(',')
    cmd = 'stonith level add ' + level.to_s + ' ' + target + ' ' + res

    destroy if does_level_exist?
    pcs('create', "#{name}-#{target}-#{res}", cmd, @resource[:tries],
        @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
  end

  def destroy
    # Any corresponding location rules will be deleted by
    # pcs automatically, if present
    target = @resource[:target]
    level = @resource[:level]
    cmd = 'stonith level remove ' + level.to_s + ' ' + target
    pcs('delete', @resource[:name], cmd, @resource[:tries],
        @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])
  end

  def does_level_exist?
    # stonith level output is a bit cumbersome to parse:
    # Target: overcloud-galera-0
    #   Level 1 - stonith-fence_ipmilan-006809859383,stonith-fence_compute-fence-nova
    # Target: overcloud-novacompute-0
    #   Level 1 - stonith-fence_ipmilan-006809859383,stonith-fence_compute-fence-nova
    #   Level 2 - stonith-fence_ipmilan-006809859383,stonith-fence_compute-fence-nova
    # Target: overcloud-rabbit-0
    #   Level 2 - stonith-fence_ipmilan-006809859383,stonith-fence_compute-fence-nova
    target = @resource[:target]
    level = @resource[:level]
    stonith_resources = @resource[:stonith_resources]
    res = stonith_resources.join(',')
    # The below cmd return the "Level X - ...." strings after the Target: string until the next
    # Target: string (or until the bottom of the file if it is the last Target in the output
    cmd = 'stonith level | sed -n "/^Target: ' + target + '$/,/^Target:/{/^Target: ' + target + '$/b;/^Target:/b;p}"'
    cmd += ' | grep -e "Level[[:space:]]*' + level.to_s + '"'
    Puppet.debug("Exists: does level exist with something else #{level} #{target} #{res} -> #{cmd}")
    ret = pcs('show', @resource[:name], cmd, @resource[:tries],
              @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])

    return ret == false ? false : true
  end

  def exists?
    # stonith level output is a bit cumbersome to parse:
    # Target: overcloud-galera-0
    #   Level 1 - stonith-fence_ipmilan-006809859383,stonith-fence_compute-fence-nova
    # Target: overcloud-novacompute-0
    #   Level 1 - stonith-fence_ipmilan-006809859383,stonith-fence_compute-fence-nova
    #   Level 2 - stonith-fence_ipmilan-006809859383,stonith-fence_compute-fence-nova
    # Target: overcloud-rabbit-0
    #   Level 2 - stonith-fence_ipmilan-006809859383,stonith-fence_compute-fence-nova
    target = @resource[:target]
    level = @resource[:level]
    stonith_resources = @resource[:stonith_resources]
    res = stonith_resources.join(',')
    Puppet.debug("Exists: stonith level exists #{level} #{target} #{res}")
    # The below cmd return the "Level X - ...." strings after the Target: string until the next
    # Target: string (or until the bottom of the file if it is the last Target in the output
    cmd = 'stonith level | sed -n "/^Target: ' + target + '$/,/^Target:/{/^Target: ' + target + '$/b;/^Target:/b;p}"'
    cmd += ' | grep -e "Level[[:space:]]*' + level.to_s + '[[:space:]]*-[[:space:]]*' + res + '"'
    ret = pcs('show', @resource[:name], cmd, @resource[:tries],
              @resource[:try_sleep], @resource[:verify_on_create], @resource[:post_success_sleep])

    return ret == false ? false : true
  end
end

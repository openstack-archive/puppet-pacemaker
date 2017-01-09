require 'digest'

# backs up the current cib and returns the temporary file name where it
# was stored. Besides the temporary file it also makes an identical copy
# called temporary file + ".orig"
def backup_cib()
  # We use the pacemaker CIB folder because of its restricted access permissions
  cib = Dir::Tmpname.make_tmpname "/var/lib/pacemaker/cib/puppet-cib-backup", nil
  cmd = "/usr/sbin/pcs cluster cib #{cib}"
  output = `#{cmd}`
  ret = $?
  if not ret.success?
    msg = "backup_cib: Running: #{cmd} failed with code: #{ret.exitstatus} -> #{output}"
    FileUtils.rm(cib, :force => true)
    raise Puppet::Error, msg
  end
  Puppet.debug("backup_cib: #{cmd} returned #{output}")
  FileUtils.cp cib, "#{cib}.orig"
  return cib
end

# Pushes the cib file back to the cluster and removes the cib files
# returns the pcs cluster cib-push return code. If the cib file and its
# original counterpart are the exact same push_cib() is a no-op.
# The pcs cluster-cib syntax with "diff-against" is used only if pcs supports
# it (it helps to minimize the chances that a cib-push might fail due
# to us trying to push a too old CIB)
def push_cib(cib)
  cib_digest = Digest::SHA2.file(cib)
  cib_orig_digest = Digest::SHA2.file("#{cib}.orig")
  if cib_digest == cib_orig_digest
    Puppet.debug("push_cib: #{cib} and #{cib}.orig were identical, skipping")
    return 0
  end
  has_diffagainst = `/usr/sbin/pcs cluster cib-push --help`.include? 'diff-against'
  cmd = "/usr/sbin/pcs cluster cib-push #{cib}"
  if has_diffagainst
    cmd += " diff-against=#{cib}.orig"
  end
  output = `#{cmd}`
  ret = $?
  FileUtils.rm(cib, :force => true)
  FileUtils.rm("#{cib}.orig", :force => true)
  if not ret.success?
    msg = "push_cib: Running: #{cmd} failed with code: #{ret.exitstatus} -> #{output}"
    Puppet.debug("push_cib failed: #{msg}")
  end

  Puppet.debug("push_cib: #{cmd} returned #{ret.exitstatus} -> #{output}")
  return ret.exitstatus
end

def pcs(name, resource_name, cmd, tries=1, try_sleep=0,
        verify_on_create=false, post_success_sleep=0)
  if name.start_with?("create") && verify_on_create
    return pcs_create_with_verify(name, resource_name, cmd, tries, try_sleep)
  end
  max_tries = name.include?('show') ? 1 : tries
  max_tries.times do |try|
    cib = backup_cib()
    try_text = max_tries > 1 ? "try #{try+1}/#{max_tries}: " : ''
    Puppet.debug("#{try_text}/usr/sbin/pcs -f #{cib} #{cmd}")
    pcs_out = `/usr/sbin/pcs -f #{cib} #{cmd} 2>&1`
    if name.include?('show')
      # return output for good exit or false for failure.
      return $?.exitstatus == 0 ? pcs_out : false
    end
    if $?.exitstatus == 0
      # If push_cib failed, we stay in the loop and keep trying
      if push_cib(cib) == 0
        sleep post_success_sleep
        return pcs_out
      end
    end
    Puppet.debug("Error: #{pcs_out}")
    if try == max_tries-1
      pcs_out_line = pcs_out.lines.first ? pcs_out.lines.first.chomp! : ''
      raise Puppet::Error, "pcs -f #{cib} #{name} failed: #{pcs_out_line}"
    end
    if try_sleep > 0
      Puppet.debug("Sleeping for #{try_sleep} seconds between tries")
      sleep try_sleep
    end
  end
end

def pcs_create_with_verify(name, resource_name, cmd, tries=1, try_sleep=0)
  max_tries = tries
  max_tries.times do |try|
    try_text = max_tries > 1 ? "try #{try+1}/#{max_tries}: " : ''
    Puppet.debug("#{try_text}/usr/sbin/pcs #{cmd}")
    pcs_out = `/usr/sbin/pcs #{cmd} 2>&1`
    if $?.exitstatus == 0
      sleep try_sleep
      cmd_show = "/usr/sbin/pcs resource show " + resource_name
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

def not_empty_string(p)
  p && p.kind_of?(String) && ! p.empty?
end

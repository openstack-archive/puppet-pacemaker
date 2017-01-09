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

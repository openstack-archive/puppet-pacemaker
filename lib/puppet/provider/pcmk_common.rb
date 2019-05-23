require 'digest'
require 'rexml/document'

# Constants that represent the state of a resource/constraint
PCMK_NOCHANGENEEDED = 0
PCMK_NOTEXISTS      = 1
PCMK_CHANGENEEDED   = 2

# Base temporary CIB backup folder
PCMK_TMP_BASE = "/var/lib/pacemaker/cib"

# Let's use pcs from PATH when it is set:
# Useful to run pcs from a different path when using
# containers
if ENV.has_key?('PATH')
  PCS_BIN = 'pcs'
  CRMDIFF_BIN = 'crm_diff'
  CRMSIMULATE_BIN = 'crm_simulate'
  CRMRESOURCE_BIN = 'crm_resource'
  TIMEOUT_BIN = 'timeout'
else
  PCS_BIN = '/usr/sbin/pcs'
  CRMDIFF_BIN = '/usr/sbin/crm_diff'
  CRMSIMULATE_BIN = '/usr/sbin/crm_simulate'
  CRMRESOURCE_BIN = '/usr/sbin/crm_resource'
  TIMEOUT_BIN = '/usr/bin/timeout'
end

# Use pcs_cli_version() as opposed to a facter so that if the pcs
# package gets installed during the puppet run everything still works
# as expected. Returns empty string if pcs command does not exist
def pcs_cli_version()
  begin
    pcs_cli_version = `#{PCS_BIN} --version`
  rescue Errno::ENOENT
    pcs_cli_version = ''
  end
  return pcs_cli_version
end


# Ruby 2.5 has dropped Dir::Tmpname.make_tmpname
# https://github.com/ruby/ruby/commit/25d56ea7b7b52dc81af30c92a9a0e2d2dab6ff27
def pcmk_tmpname((prefix, suffix), n)
  #Dir::Tmpname.make_tmpname (prefix, suffix), n
  prefix = (String.try_convert(prefix) or
            raise ArgumentError, "unexpected prefix: #{prefix.inspect}")
  suffix &&= (String.try_convert(suffix) or
              raise ArgumentError, "unexpected suffix: #{suffix.inspect}")
  t = Time.now.strftime("%Y%m%d")
  path = "#{prefix}#{t}-#{$$}-#{rand(0x100000000).to_s(36)}".dup
  path << "-#{n}" if n
  path << suffix if suffix
  path
end

def delete_cib(cib)
  FileUtils.rm(cib, :force => true)
  FileUtils.rm("#{cib}.orig", :force => true)
end

# backs up the current cib and returns the temporary file name where it
# was stored. Besides the temporary file it also makes an identical copy
# called temporary file + ".orig"
def backup_cib()
  # We use the pacemaker CIB folder because of its restricted access permissions
  cib = pcmk_tmpname("#{PCMK_TMP_BASE}/puppet-cib-backup", nil)
  cmd = "#{PCS_BIN} cluster cib #{cib}"
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
    delete_cib(cib)
    return 0
  end
  has_diffagainst = `#{PCS_BIN} cluster cib-push --help`.include? 'diff-against'
  cmd = "#{PCS_BIN} cluster cib-push #{cib}"
  if has_diffagainst
    cmd += " diff-against=#{cib}.orig"
  end
  output = `#{cmd}`
  ret = $?
  delete_cib(cib)
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
    Puppet.debug("#{try_text}#{PCS_BIN} -f #{cib} #{cmd}")
    pcs_out = `#{PCS_BIN} -f #{cib} #{cmd} 2>&1`
    if name.include?('show')
      delete_cib(cib)
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
      delete_cib(cib)
      pcs_out_line = pcs_out.lines.first ? pcs_out.lines.first.chomp! : ''
      raise Puppet::Error, "pcs -f #{cib} #{name} failed: #{pcs_out_line}"
    end
    if try_sleep > 0
      Puppet.debug("Sleeping for #{try_sleep} seconds between tries")
      sleep try_sleep
    end
  end
end

def pcs_without_push(name, resource_name, cmd, tries=1, try_sleep=0, post_success_sleep=0)
  max_tries = tries
  max_tries.times do |try|
    try_text = max_tries > 1 ? "try #{try+1}/#{max_tries}: " : ''
    Puppet.debug("#{try_text}#{PCS_BIN} #{cmd}")
    pcs_out = `#{PCS_BIN} #{cmd} 2>&1`
    if $?.exitstatus == 0
      sleep post_success_sleep
      return pcs_out
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

def pcs_create_with_verify(name, resource_name, cmd, tries=1, try_sleep=0)
  max_tries = tries
  max_tries.times do |try|
    try_text = max_tries > 1 ? "try #{try+1}/#{max_tries}: " : ''
    Puppet.debug("#{try_text}#{PCS_BIN} #{cmd}")
    pcs_out = `#{PCS_BIN} #{cmd} 2>&1`
    if $?.exitstatus == 0
      sleep try_sleep
      cmd_show = "#{PCS_BIN} resource show " + resource_name
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

# Returns the pcs command to create the location rule
def build_pcs_location_rule_cmd(resource, force=false)
  # The name that pcs will create is location-<name>[-{clone,master}]
  location_rule = resource[:location_rule]
  location_cmd = 'constraint location '
  if resource.propertydefined?(:bundle)
    location_cmd += resource[:bundle]
  else
    location_cmd += resource[:name]
    if resource.propertydefined?(:clone_params)
      location_cmd += '-clone'
    elsif resource.propertydefined?(:master_params)
      location_cmd += '-master'
    end
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
  if force
    location_cmd += ' --force'
  end
  Puppet.debug("build_pcs_location_rule_cmd: #{location_cmd}")
  location_cmd
end

# This method runs a pcs command on an offline cib
# Much simpler logic compared to pcs()
# return output for good exit or false for failure.
def pcs_offline(cmd, cib)
    pcs_out = `#{PCS_BIN} -f #{cib} #{cmd}`
    Puppet.debug("pcs_offline: #{PCS_BIN} -f #{cib} #{cmd}. Output: #{pcs_out}")
    return $?.exitstatus == 0 ? pcs_out : false
end

# This is a loop that simply tries to  push a CIB a number of time
# on to the live cluster. It does not remove the CIB except in the Error
# case. Returns nothing in case of success and errors out in case of errors
def push_cib_offline(cib, tries=1, try_sleep=0, post_success_sleep=0)
  tries.times do |try|
    try_text = tries > 1 ? "try #{try+1}/#{tries}: " : ''
    Puppet.debug("pcs_cib_offline push #{try_text}")
    if push_cib(cib) == 0
      sleep post_success_sleep
      return
    end
    Puppet.debug("Error: #{pcs_out}")
    if try == tries-1
      delete_cib(cib)
      raise Puppet::Error, "push_cib_offline for #{cib} failed"
    end
    if try_sleep > 0
      Puppet.debug("Sleeping for #{try_sleep} seconds between tries")
      sleep try_sleep
    end
  end
end

# returns the storage map for the resource as a dictionary
def pcmk_get_bundle_storage_map(resource)
  storage_xpath = "/cib/configuration/resources/bundle[@id='#{resource}']/storage/storage-mapping"
  cib = backup_cib()
  cibxml = File.read(cib)
  storage_doc = REXML::Document.new cibxml
  ret = {}
  REXML::XPath.each(storage_doc, storage_xpath) do |element|
    attrs = {}
    element.attributes.each do |key, value|
      attrs[key] = value
    end
    ret[attrs['id']] = attrs
  end
  delete_cib(cib)
  Puppet.debug("pcmk_get_bundle_storage_map #{resource} returned #{ret}")
  ret
end

# The following function will take a resource_name an xml graph file as generated by crm_simulate and
# will return true if the resource_name is contained in the transition graph (i.e. the cluster would
# restart the resource) and false if not (i.e. the cluster would not restart the resource)
def pcmk_graph_contain_id?(resource_name, graph_file, is_bundle=false)
  graph = File.new(graph_file)
  graph_doc = REXML::Document.new graph
  xpath_query = '/transition_graph//primitive/@id'
  ids = []
  REXML::XPath.each(graph_doc, xpath_query) do |element|
    id = element.to_s
    # if we are a bundle we compare the start of the strings
    # because the primitive id will be in the form of galera-bundle-1 as opposed to galera-bundle
    if is_bundle then
      if id.start_with?(resource_name) then
        return true
      end
    else
      if id == resource_name then
        return true
      end
    end
  end
  return false
end

# we need to check if crm_diff is affected by rhbz#1561617
# crm_diff --cib -o xml1 -n xml2 will return 1 (aka diff needed)
# on broken versions. I will return 0 when crm_diff is fixed
# (aka no changes detected)
def is_crm_diff_buggy?
  xml1 = '''
<cib crm_feature_set="3.0.14" validate-with="pacemaker-2.10" epoch="86" num_updates="125" admin_epoch="0">
  <configuration>
    <resources>
      <bundle id="galera-bundle">
        <docker image="openstack-mariadb:pcmklatest"/>
        <storage>
          <storage-mapping target-dir="/foo" options="rw" id="mysql-foo" source-dir="/foo"/>
          <storage-mapping target-dir="/bar" options="rw" id="mysql-bar" source-dir="/bar"/>
        </storage>
      </bundle>
    </resources>
  </configuration>
</cib>
'''
  xml2 = '''
<cib crm_feature_set="3.0.14" validate-with="pacemaker-2.10" epoch="86" num_updates="125" admin_epoch="0">
  <configuration>
    <resources>
      <bundle id="galera-bundle">
        <docker image="openstack-mariadb:pcmklatest"/>
        <storage>
          <storage-mapping id="mysql-foo" options="rw" source-dir="/foo" target-dir="/foo"/>
          <storage-mapping id="mysql-bar" options="rw" source-dir="/bar" target-dir="/bar"/>
        </storage>
      </bundle>
    </resources>
  </configuration>
</cib>
'''
  cmd = "#{CRMDIFF_BIN} --cib --original-string='#{xml1}' --new-string='#{xml2}'"
  cmd_out = `#{cmd}`
  ret = $?.exitstatus
  return false if ret == 0
  return true if ret == 1
  raise Puppet::Error, "#{cmd} failed with (#{ret}): #{cmd_out}"
end

# This function will return true when a CIB diff xml has an empty meta_attribute change (either
# addition or removal). It does so by veryfiying that the diff has an empty meta_attribute node
# and when that is the case it verifies that the corresponding meta_attributes
# for the resource in the CIB is indeed either non-existing or has no children
def has_empty_meta_attributes?(cibfile, element)
  # First we verify that the cib diff does contain an empty meta_attributes node, like this:
  # <change operation='create' path='/cib/configuration/resources/primitive[@id=&apos;ip-172.16.11.97&apos;]' position='2'>
  #   <meta_attributes id='ip-172.16.11.97-meta_attributes'/>
  # </change>
  if element.attributes.has_key?('operation') and \
     ['delete', 'create'].include? element.attributes['operation'] and \
     element.attributes.has_key?('path')
    path = element.attributes['path']
    element.each_element('//meta_attributes') do |meta|
      # If the meta_attributes was an empty set we verify that it is so in the CIB as well
      # and if that is the case we return true
      if not meta.has_elements?
        begin
          meta_id = meta.attributes['id']
          orig_cib = File.read(cibfile)
          meta_doc = REXML::Document.new orig_cib
          meta_xpath = "//meta_attributes[@id='#{meta_id}']"
          meta_search = meta_doc.get_elements(meta_xpath)
          # If there are not meta_attributes at all or if we have a tag but it has no elements
          # then we return true
          if meta_search.empty? or (meta_search.length() > 0 and not meta_search[0].has_elements?)
            Puppet.debug("has_empty_meta_attributes? detected and empty meta_attribute change and empty meta_attribute in the CIB, skipping: #{meta_id}")
            return true
          end
        rescue
          # Should there be any kind of exception in the code above we take
          # the slightly safer path and we simply return false which implies
          # updating the CIB and pushing it to the live cluster
          return false
        end
      end
    end
  end
  return false
end


# same as pcmk_restart_resource? but using crm_diff
def pcmk_restart_resource_ng?(resource_name, cib)
  cmd = "#{CRMDIFF_BIN} --cib -o #{cib}.orig -n #{cib}"
  cmd_out = `#{cmd}`
  ret = $?.exitstatus
  # crm_diff returns 0 for no differences, 1 for differences, other return codes
  # for errors
  if not [0, 1].include? ret
    delete_cib(cib)
    raise Puppet::Error, "#{cmd} failed with (#{ret}): #{cmd_out}"
  end
  # If crm_diff says there are no differences (ret code 0), we can just
  # exit and state that nothing needs restarting
  return false if ret == 0
  # In case the return code is 1 we will need to make sure that the resource
  # we were passed is indeed involved in the change detected by crm_diff
  graph_doc = REXML::Document.new cmd_out
  # crm_diff --cib -o cib-orig.xml -n cib-vip-update.xml | \
  #   xmllint --xpath '/diff/change[@operation and contains(@path, "ip-192.168.24.6")]/change-result' -
  xpath_query = "/diff/change[@operation and @operation != 'move' and contains(@path, \"@id='#{resource_name}'\")]"
  REXML::XPath.each(graph_doc, xpath_query) do |element|
    # We need to check for removals of empty meta_attribute tags and ignore those
    # See https://bugzilla.redhat.com/show_bug.cgi?id=1568353 for pcs creating those spurious empty tags
    next if has_empty_meta_attributes?(cib, element)
    return true
  end
  return false
end

# This given a cib and a resource name, this method returns true if pacemaker
# will restart the resource false if no action will be taken by pacemaker
# Note that we need to leverage crm_simulate instead of crm_diff due to:
# https://bugzilla.redhat.com/show_bug.cgi?id=1561617
def pcmk_restart_resource?(resource_name, cib, is_bundle=false)
  tmpfile = pcmk_tmpname("#{PCMK_TMP_BASE}/puppet-cib-simulate", nil)
  cmd = "#{CRMSIMULATE_BIN} -x #{cib} -s -G#{tmpfile}"
  crm_out = `#{cmd}`
  if $?.exitstatus != 0
    FileUtils.rm(tmpfile, :force => true)
    delete_cib(cib)
    raise Puppet::Error, "#{cmd} failed with: #{crm_out}"
  end
  # Now in tmpfile we have the xml of the changes to the cluster
  # If tmpfile only contains one empy <transition_graph> no changes took place
  ret = pcmk_graph_contain_id?(resource_name, tmpfile, is_bundle)
  FileUtils.rm(tmpfile, :force => true)
  return ret
end

# This method takes a resource and a creation command and does the following
# 1. Deletes the resource from the offline CIB
# 2. Recreates the resource on the offline CIB
# 3. Verifies if the pacemaker will restart the resource and returns true if the answer is a yes
def pcmk_resource_has_changed?(resource, cmd_update, cmd_pruning='', is_bundle=false)
  cib = backup_cib()
  if not_empty_string(cmd_pruning)
    ret = pcs_offline(cmd_pruning, cib)
    if ret == false
      delete_cib(cib)
      raise Puppet::Error, "pcmk_update_resource #{cmd_pruning} returned error on #{resource[:name]}. This should never happen."
    end
  end
  ret = pcs_offline(cmd_update, cib)
  if ret == false
    delete_cib(cib)
    raise Puppet::Error, "pcmk_resource_has_changed? #{cmd_update} returned error #{resource[:name]}. This should never happen."
  end
  if is_crm_diff_buggy?
    ret = pcmk_restart_resource?(resource[:name], cib, is_bundle)
    Puppet.debug("pcmk_resource_has_changed returned #{ret} for resource #{resource[:name]}")
  else
    ret = pcmk_restart_resource_ng?(resource[:name], cib)
    Puppet.debug("pcmk_resource_has_changed (ng version) returned #{ret} for resource #{resource[:name]}")
  end
  delete_cib(cib)
  return ret
end

# This function will update a resource by making a cib backup,
# running a pruning command first and then running the update command.
# Finally it pushes the CIB back to the cluster.
def pcmk_update_resource(resource, cmd_update, cmd_pruning='', settle_timeout_secs=600)
  cib = backup_cib()
  if not_empty_string(cmd_pruning)
    ret = pcs_offline(cmd_pruning, cib)
    if ret == false
      delete_cib(cib)
      raise Puppet::Error, "pcmk_update_resource #{cmd_pruning} returned error on #{resource[:name]}. This should never happen."
    end
  end
  ret = pcs_offline(cmd_update, cib)
  if ret == false
    delete_cib(cib)
    raise Puppet::Error, "pcmk_update_resource #{cmd_update} returned error on #{resource[:name]}. This should never happen."
  end
  push_cib_offline(cib, resource[:tries], resource[:try_sleep], resource[:post_success_sleep])
  cmd = "#{TIMEOUT_BIN} #{settle_timeout_secs} #{CRMRESOURCE_BIN} --wait"
  cmd_out = `#{cmd}`
  ret = $?.exitstatus
  Puppet.debug("pcmk_update_resource: #{cmd} returned (#{ret}): #{cmd_out}")
  delete_cib(cib)
end

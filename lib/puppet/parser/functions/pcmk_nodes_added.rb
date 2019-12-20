module Puppet::Parser::Functions
  newfunction(
      :pcmk_nodes_added,
      type: :rvalue,
      arity: -1,
      doc: <<-eof
Input data cluster_members string separated by a space:
* String A space-separated string containing a list of node names
* String A list containing either a single string (single ip) or a list of strings
  (multiple ipaddresses) associated to each cluster node
* String the version of pcs used
* Output of `crm_node -l` (only used to ease unit testing) (optional)

Output forms:
* array - output the plain array of nodes that have been added compared
          to the running cluster. It returns an empty array in case the
          cluster is not set up or if crm_node return an error
      eof
  ) do |args|
    # no point in doing this if the crm_node executable does not exist
    return [] if Facter::Util::Resolution.which('crm_node') == nil
    nodes = args[0]
    addr_list = args[1]
    pcs_version = args[2]
    crm_node_list = args[3]
    unless nodes.is_a? String
      fail "Got unsupported nodes input data: #{nodes.inspect}"
    end
    unless addr_list.is_a? Array
      fail "Got unsupported addr_list input data: #{addr_list.inspect}"
    end
    if crm_node_list && !crm_node_list.kind_of?(String) then
      fail "Got unsupported crm_node_list #{crm_node_list.inspect}"
    end
    node_list = nodes.split()
    fail "pcmk_cluster_setup: node list and addr list should be of the same size when defined and not empty" if addr_list.size > 0 and addr_list.size != node_list.size

    if crm_node_list && crm_node_list.kind_of?(String) then
      return [] if crm_node_list.empty?
      crm_nodes_output = crm_node_list
    else
      # A typical crm_node -l output is like the following:
      # [root@foobar-0 ~]# crm_node -l
      # 3 foobar-2 member
      # 1 foobar-0 member
      # 2 foobar-1 lost
      crm_nodes_output = `crm_node -l`
      # if the command fails we certainly did not add any nodes
      return [] if $?.exitstatus != 0
    end
    Puppet.debug("pcmk_nodes_added: crm_nodes_output #{crm_nodes_output}")

    crm_nodes = []
    crm_nodes_output.lines.each { |line|
      (id, node, state, _) = line.split(" ").collect(&:strip)
      valid_states = %w(member lost)
      state.downcase! if state
      crm_nodes.push(node.strip) if valid_states.include? state
    }
    nodes_added = node_list - crm_nodes

    if pcs_version =~ /0.10/
      # If the addr_list was specified we need to return a list in the form of
      # ['node1 addr=1.2.3.4', 'node2 addr=1.2.3.5 addr=1.2.3.6', 'node3 addr=1.2.3.7']
      if addr_list.size > 0
        ret = []
        nodes_addrs_added = node_list.zip(addr_list)
          .select { |node_addr| nodes_added.include?(node_addr[0]) }
        nodes_addrs_added.each do |node_addr|
          node = node_addr[0]
          ip = node_addr[1]
          # addr can be '1.2.3.4' or ['1.2.3.4', '1.2.3.5'] or
          if ip.is_a? String
            addr = "addr=#{ip}"
          elsif ip.is_a? Array
            addr = ''
            ip.each do |i|
              addr += "addr=#{i}"
              addr += " " if not i.equal?(ip.last)
            end
          else
            fail "pcmk_nodes_added: One of the addresses in addr_list is neither a String nor an Array"
          end
          ret << "#{node} #{addr}"
        end
      # only node_added is specified so we just return the original string
      else
        ret = nodes_added
      end
    elsif pcs_version =~ /0.9/
      # With pcs 0.9 only non-knet clusters are supported, aka only one address can be used
      # so we take the node name as we always did
      ret = nodes_added
    else
      fail("pcmk_nodes_added: pcs #{pcs_version} is unsupported")
    end

    Puppet.debug("pcmk_nodes_added: #{ret} [#{node_list} - #{crm_nodes}]")
    ret
  end
end

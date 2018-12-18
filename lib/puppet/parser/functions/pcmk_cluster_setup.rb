require_relative '../../provider/pcmk_common'

module Puppet::Parser::Functions
  newfunction(
      :pcmk_cluster_setup,
      type: :rvalue,
      arity: -1,
      doc: <<-eof
Input data cluster_members string separated by a space:
* String A space-separated string containing a list of node names
* String A list containing either a single string (single ip) or a list of strings
  (multiple ipaddresses) associated to each cluster node
* String the version of pcs used

Output forms:
* string - Output A string to be used in the cluster setup call to pcs
      eof
  ) do |args|
    nodes = args[0]
    addr_list = args[1]
    pcs_version = args[2]
    fail "pcmk_cluster_setup: Got unsupported nodes input data: #{nodes.inspect}" if not nodes.is_a? String
    fail "pcmk_cluster_setup: Got unsupported addr_list input data: #{addr_list.inspect}" if not addr_list.is_a? Array
    fail "pcmk_cluster_setup: Got unsupported version input data: #{pcs_version.inspect}" if not pcs_version.is_a? String
    node_list = nodes.split()
    fail "pcmk_cluster_setup: node list and addr list should be of the same size when defined and not empty" if addr_list.size > 0 and addr_list.size != node_list.size
    # pcs 0.10 supports knet clusters which require addresses to be specified
    if pcs_version =~ /0.10/
      # If the addr_list was specified we need to return a string in the form of
      # node1 addr=1.2.3.4 node2 addr=1.2.3.5 addr=1.2.3.6 node3 addr=1.2.3.7
      if addr_list.size > 0
        ret = ''
        node_list.zip(addr_list).each do |node, ip|
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
            fail "pcmk_cluster_setup: One of the addresses in addr_list is neither a String nor an Array"
          end
          ret += "#{node} #{addr}"
          ret += " " if not node.equal?(node_list.last)
        end
      # only node_list is specified so we just return the original string
      else
        ret = nodes.strip()
      end
      ret
    elsif pcs_version =~ /0.9/
      # With pcs 0.9 only non-knet clusters are supported, aka only one address can be used
      # so we take the node name as we always did
      nodes.strip()
    else
      fail("pcmk_cluster_setup: pcs #{pcs_version} is unsupported")
    end
  end
end

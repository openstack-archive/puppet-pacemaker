# == Class: pacemaker::corosync
#
# A class to setup a pacemaker cluster
#
# === Parameters
# [*cluster_name*]
#   The name of the cluster (no whitespace)
# [*cluster_members*]
#   A space-separted list of cluster IP's or names
# [*setup_cluster*]
#   If your cluster includes pcsd, this should be set to true for just
#    one node in cluster.  Else set to true for all nodes.

class pacemaker::corosync(
  $cluster_name = 'clustername',
  $cluster_members,
  $setup_cluster = true,
) inherits pacemaker {
  include ::pacemaker::params

  firewall { '001 corosync mcast':
    proto  => 'udp',
    dport  => ['5404', '5405'],
    action => 'accept',
  }

  if $pcsd_mode {
    firewall { '001 pcsd':
      proto  => 'tcp',
      dport  => ['2224'],
      action => 'accept',
    }
    # we have more fragile when-to-start pacemaker conditions with pcsd
    exec {"enable-not-start-$cluster_name":
      command => "/usr/sbin/pcs cluster enable"
    }
    ->
    exec {"Set password for hacluster user on $cluster_name":
      command => "/bin/echo ${::pacemaker::params::hacluster_pwd} | /usr/bin/passwd --stdin hacluster",
      creates => "/etc/cluster/cluster.conf",
      require => Class["::pacemaker::install"],
    }
    ->
    exec {"auth-successful-across-all-nodes":
      command => "/usr/sbin/pcs cluster auth $cluster_members -u hacluster -p ${::pacemaker::params::hacluster_pwd} --force",
      timeout   => 3600,
      tries     => 360,
      try_sleep => 10,
    }
    ->
    Exec["wait-for-settle"]
  }

  if $setup_cluster {
    exec {"Create Cluster $cluster_name":
      creates => "/etc/cluster/cluster.conf",
      command => "/usr/sbin/pcs cluster setup --name $cluster_name $cluster_members",
      unless => "/usr/bin/test -f /etc/corosync/corosync.conf",
      require => Class["::pacemaker::install"],
    }
    ->
    exec {"Start Cluster $cluster_name":
      unless => "/usr/sbin/pcs status >/dev/null 2>&1",
      command => "/usr/sbin/pcs cluster start --all",
      require => Exec["Create Cluster $cluster_name"],
    }
    if $pcsd_mode {
      Exec["auth-successful-across-all-nodes"] ->
        Exec["Create Cluster $cluster_name"]
    }
    Exec["Start Cluster $cluster_name"] ->
      Exec["wait-for-settle"]
  }

  exec {"wait-for-settle":
    timeout   => 3600,
    tries     => 360,
    try_sleep => 10,
    command   => "/usr/sbin/pcs status | grep -q 'partition with quorum' > /dev/null 2>&1",
    unless    => "/usr/sbin/pcs status | grep -q 'partition with quorum' > /dev/null 2>&1",
    notify    => Notify["pacemaker settled"],
  }

  notify {"pacemaker settled":
    message => "Pacemaker has reported quorum achieved",
  }
}

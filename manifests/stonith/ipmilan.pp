class pacemaker::stonith::ipmilan($address, $user="stonith", $password, $no_location_rule="false", $cloned="false", $ensure=present)
  inherits pacemaker::corosync {
    package { "ipmitool":
        ensure => installed,
    }

    if($ensure == absent) {
        exec { "Removing stonith::ipmilan ${address}":
        command => "/usr/sbin/pcs stonith delete stonith-ipmilan-${address}",
        onlyif  => "/usr/sbin/pcs stonith show stonith-ipmilan-${address} > /dev/null 2>&1",
        require => Exec["Start Cluster $cluster_name"],
        }
    } else {
        exec { "Creating stonith::ipmilan ${address}":
        command => "/usr/sbin/pcs stonith create stonith-ipmilan-${address} fence_ipmilan pcmk_host_list=\"${cluster_members}\" ipaddr=${address} login=${user} passwd=${password} op monitor interval=20s",
        unless  => "/usr/sbin/pcs stonith show stonith-ipmilan-${address} > /dev/null 2>&1",
        require => [Package["ipmitool"],Exec["Start Cluster $cluster_name"],Package["pcs"]]
        }
    }
}

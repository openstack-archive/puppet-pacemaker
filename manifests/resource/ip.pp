class pacemaker::resource::ip($ip_address, $cidr_netmask=32, $interval="30s", $stickiness=0, $ensure=present) 
  inherits pacemaker::corosync {
    if($ensure == absent) {
        exec { "Removing ip ${ip_address}":
        command => "/usr/sbin/pcs resource delete ip-${ip_address}",
        onlyif  => "/usr/sbin/pcs resource show ip-${ip_address} > /dev/null 2>&1",
        require => Exec["Start Cluster $cluster_name"],
        }
    } else {
        exec { "Creating ip ${ip_address}":
        command => "/usr/sbin/pcs resource create ip-${ip_address} IPaddr2 ip=${ip_address} cidr_netmask=${cidr_netmask} op monitor interval=${interval}",
        unless  => "/usr/sbin/pcs resource show ip-${ip_address} > /dev/null 2>&1",
        require => [Exec["Start Cluster $cluster_name"],Package["pcs"]]
        }
    }
}

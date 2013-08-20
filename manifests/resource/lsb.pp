class pacemaker::resource::lsb($interval="30s", $stickiness=0, $ensure=present)
  inherits pacemaker::corosync {
    if($ensure == absent) {
        exec { "Removing lsb ${name}":
        command => "/usr/sbin/pcs resource delete lsb-${name}",
        onlyif  => "/usr/sbin/pcs resource show lsb-${name} > /dev/null 2>&1",
        require => Exec["Start Cluster $cluster_name"],
        }
    } else {
        exec { "Creating lsb ${name}":
    	command => "/usr/sbin/pcs resource create lsb-${name} lsb:${name} op monitor interval=${interval}",
        unless  => "/usr/sbin/pcs resource show lsb-${name} > /dev/null 2>&1",
        require => [Exec["Start Cluster $cluster_name"], Package["pcs"]]
        }
    }
}

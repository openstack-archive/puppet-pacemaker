class pacemaker::resource::lsb($group=nil, $interval="30s", $stickiness=0, $ensure=present)
  inherits pacemaker::corosync {

    $resource_id = "lsb-${name}"

    if($ensure == absent) {
        exec { "Removing lsb ${name}":
        command => "/usr/sbin/pcs resource delete ${resource_id}",
        onlyif  => "/usr/sbin/pcs resource show ${resource_id} > /dev/null 2>&1",
        require => Exec["Start Cluster $cluster_name"],
        }
    } else {
        $group_option = $group ? {
            ''      => '',
            default => " --group ${group}"
        }

        exec { "Creating lsb ${name}":
    	command => "/usr/sbin/pcs resource create ${resource_id} lsb:${name} op monitor interval=${interval}${group_option}",
        unless  => "/usr/sbin/pcs resource show ${resource_id} > /dev/null 2>&1",
        require => [Exec["Start Cluster $cluster_name"], Package["pcs"]]
        }

        pacemaker::resource::group { "${resource_id}-${group}":
            resource_id => $resource_id,
            resource_group => $group,
            require => Exec["Creating lsb ${name}"],
        }
    }
}

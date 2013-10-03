class pacemaker::resource::filesystem($device, $directory, $fstype, $group=nil, $interval="30s", $ensure=present) 
  inherits pacemaker::corosync {

    $resource_id = delete("fs-${directory}", '/')
    if($ensure == absent) {
        exec { "Removing ip ${resource_id}":
        command => "/usr/sbin/pcs resource delete ${resource_id}",
        onlyif  => "/usr/sbin/pcs resource show ${resource_id} > /dev/null 2>&1",
        require => Exec["Start Cluster $cluster_name"],
        }
    } else {
        $group_options = $group ? {
            ''      => '',
            default => " --group ${group}"
        }

        exec { "Creating ip ${resource_id}":
        command => "/usr/sbin/pcs resource create ${resource_id} Filesystem device=${device} directory=${directory} fstype=${fstype} op monitor interval=${interval}${group_option}",
        unless  => "/usr/sbin/pcs resource show ${resource_id} > /dev/null 2>&1",
        require => [Exec["Start Cluster $cluster_name"],Package["pcs"]]
        }

        pacemaker::resource::group { "${resource_id}-${group}":
            resource_id => $resource_id,
            resource_group => $group,
            require => Exec["Creating ip ${resource_id}"],
        }
    }
}


class pacemaker::resource::mysql($name, $group=nil, $interval="30s", $stickiness=0, $ensure=present,
                               $replication_user='', $replication_passwd='', 
                               $max_slave_lag=0, $evict_outdated_slaves=false, $enable_creation=true)
  inherits pacemaker::corosync {

    $resource_id = "mysql-${name}"

    if($ensure == absent) {
        exec { "Removing MySQL ${name}":
        command => "/usr/sbin/pcs resource delete ${resource_id}",
        onlyif  => "/usr/sbin/pcs resource show ${resource_id} > /dev/null 2>&1",
        require => Exec["Start Cluster $cluster_name"],
        }
    } else {
        $group_options = $group ? {
            ''      => '',
            default => " --group ${group}"
        }
        $replication_options = $replication_user ? {
            ''      => '',
            default => " replication_user=$replication_user replication_passwd=$replication_passwd max_slave_lag=$max_slave_lag evict_outdated_slaves=$evict_outdated_slaves"
        }

        exec { "Creating MySQL ${name}":
    	command => "/usr/sbin/pcs resource create ${resource_id} mysql enable_creation=true${replication_options} op monitor interval=${interval}${group_option}",
        unless  => "/usr/sbin/pcs resource show ${resource_id} > /dev/null 2>&1",
        require => [Exec["Start Cluster $cluster_name"], Package["pcs"]]
        }

        pacemaker::resource::group { "${resource_id}-${group}":
            resource_id => $resource_id,
            resource_group => $group,
            require => Exec["Creating MySQL ${name}"],
        }
    }
}

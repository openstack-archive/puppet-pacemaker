define pacemaker::stonith::ipmilan($hostlist, $address, $user="stonith", $password, $no_location_rule="false", $cloned="false") {
    package { "ipmitool":
        ensure => installed,
    }

    if($ensure == absent) {
        exec { "Removing stonith::ipmilan ${name}":
        command => "/usr/sbin/crm_resource -D -r stonith-ipmilan-${name} -t primitive",
        onlyif  => "/usr/sbin/crm_resource -r stonith-ipmilan-${name} -t primitive -q > /dev/null 2>&1",
        require => Service["pacemaker"]
        }
    } else {
        exec { "Creating stonith::ipmilan ${name}":
        command => "/usr/sbin/pcs stonith create stonith-ipmilan-${name} fence_ipmilan pcmk_host_list=\"${hostlist}\" ipaddr=${address} login=${user} passwd=${password} op monitor interval=20s",
        unless  => "/usr/sbin/crm_resource -r stonith-ipmilan-${name} -t primitive -q > /dev/null 2>&1",
        require => [Package["ipmitool"],Service["pacemaker"],Package["pcs"]]
        }
    }
}

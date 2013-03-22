define pacemaker::resources::lsb($stickiness=0, $ensure = present) {
    if($ensure == absent) {
        exec { "Removing lsb ${name}":
    	command => "/usr/sbin/crm_resource -D -r lsb-${name} -t primitive",
    	onlyif  => "/usr/sbin/crm_resource -r lsb-${name} -t primitive -q > /dev/null 2>&1",
        require => Service["pacemaker"]
        }
    } else {
        exec { "Creating lsb ${name}":
    	command => "/usr/sbin/pcs resource create lsb-${name} lsb:${name} op monitor interval=30s",
    	unless  => "/usr/sbin/crm_resource -r lsb-${name} -t primitive -q > /dev/null 2>&1",
        require => [Service["pacemaker"],Package["pcs"]]
        }
    }
}


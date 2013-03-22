define pacemaker::resources::ip($address, $stickiness=0, $ensure = present) {
    if($ensure == absent) {
        exec { "Removing ip ${name}":
    	command => "/usr/sbin/crm_resource -D -r ip-${name} -t primitive",
    	onlyif  => "/usr/sbin/crm_resource -r ip-${name} -t primitive -q > /dev/null 2>&1",
        require => Service["pacemaker"]
        }
    } else {
        exec { "Creating ip ${name}":
    	command => "/usr/sbin/pcs resource create ip-${name} IPaddr2 ip=${address} cidr_netmask=32 op monitor interval=30s",
    	unless  => "/usr/sbin/crm_resource -r ip-${name} -t primitive -q > /dev/null 2>&1",
        require => [Service["pacemaker"],Package["pcs"]]
        }
    }
}


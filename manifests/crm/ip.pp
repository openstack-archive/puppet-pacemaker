define pacemaker::crm::ip($address, $stickiness=0, $ensure = present) {
    if($ensure == absent) {
        exec { "Removing ip ${name}":
    	command => "/usr/sbin/crm_resource -D -r ip-${name} -t primitive",
    	onlyif  => "/usr/sbin/crm_resource -r ip-${name} -t primitive -q > /dev/null 2>&1",
        }
    } else {
        exec { "Creating ip ${name}":
    	command => "/usr/sbin/crm -F configure primitive ip-${name} ocf:heartbeat:IPaddr2 params ip=${address} cidr_netmask=32 op monitor interval=\"20\"",
    	unless  => "/usr/sbin/crm_resource -r ip-${name} -t primitive -q > /dev/null 2>&1",
        }
    }
}


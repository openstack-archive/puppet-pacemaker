class pacemaker::corosync($cluster_name, $cluster_members) inherits pacemaker {

    firewall { '001 corosync mcast':
        proto    => 'udp',
        dport    => ['5404', '5405'],
        action   => 'accept',
    }

    package {["pacemaker", "pcs", "cman"]:
	ensure  => "installed",
    }

    exec {"Set password for hacluster user on $cluster_name":
        command => "/bin/echo CHANGEME | /usr/bin/passwd --stdin hacluster",
        creates => "/etc/cluster/cluster.conf",
        require => [Package["pcs"], Package["pacemaker"]]
    }
    
    exec {"Create Cluster $cluster_name":
        creates => "/etc/cluster/cluster.conf",
        command => "/usr/sbin/pcs cluster setup --name $cluster_name $cluster_members",
        require => [Package["pcs"], Package["cman"]],
    }

    exec {"Start Cluster $cluster_name":
        unless => "/usr/sbin/pcs status > /dev/null 2>&1",
        command => "/usr/sbin/pcs cluster start",
        require => Exec["Create Cluster $cluster_name"],
    }
}

class pacemaker::corosync($cluster_name, $cluster_members) inherits pacemaker {

    firewall { '001 corosync mcast':
        proto    => 'udp',
        dport    => ['5404', '5405'],
        action   => 'accept',
    }

    #exec {"Disable RGManager":
    #    subscribe   => Exec["Create Cluster"],
    #    refreshonly => true,
    #    command     => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --setrm disabled=1",
    #    require     => [Package["pcs"], Exec["Create Cluster"]],
    #}

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

define pacemaker::fencing_redirect() {

    exec {"Setup Pacemaker Fencing Device":
        subscribe   => Exec["Create Cluster"],
        refreshonly => true,
        command     => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --addfencedev pcmk-redirect agent=fence_pcmk",
        unless      => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --lsfencedev | grep 'pcmk-redirect: agent=fence_pcmk'",
        require     => [Package["pcs"], Exec["Create Cluster"]],
    }

    exec {"Create Node $name":
        command => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --addnode $name",
        unless  => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --lsnodes | grep $name:",
        require => [Package["pcs"], Exec["Create Cluster"]],
        notify  => Service["cman"],
    }

    exec {"Add Fencing Redirect Method to Node $name":
        subscribe => Exec["Create Node $name"],
        #refreshonly => true,
        command => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --addmethod pcmk-redirect $name",
        unless  => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --lsfenceinst $name | grep '  pcmk-redirect'",
        require => [Package["pcs"],Exec["Create Node $name"]]
    }

    exec {"Activate Fencing Redirect for Node $name":
        subscribe => Exec["Create Node $name"],
        #refreshonly => true,
        command => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --addfenceinst pcmk-redirect $name pcmk-redirect port=$name",
        unless  => "/usr/sbin/pcs -f /etc/cluster/cluster.conf --lsfenceinst $name | grep 'pcmk-redirect: port=$name'",
        require => [Package["pcs"], Exec["Add Fencing Redirect Method to Node $name"]]
    }
}

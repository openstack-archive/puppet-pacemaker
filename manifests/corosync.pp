define pacemaker::corosync() {

    package {["pacemaker", "cman",
              "ccs", "resource-agents",
              "pacemaker-cli"]:
	    ensure  => "installed",
    }


    file {"/etc/sysconfig/cman":
        source => "puppet:///modules/pacemaker/cman",
        require => Package["cman"], 
    }

    exec {"Create Cluster":
        creates => "/etc/cluster/cluster.conf",
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --createcluster $name",
        require => Package["ccs"], 
    }

    exec {"Setup Pacemaker Fencing Device":
        subscribe => Exec["Create Cluster"],
        refreshonly => true,
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --addfencedev pcmk-redirect agent=fence_pcmk",
        require => Package["ccs"], 
    }
}

define pacemaker::corosync::node() {

   exec {"Create Node $name":
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --addnode $name",
        unless => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --lsnodes | grep $name:",
        require => Package["ccs"], 
    }

    exec {"Add Fencing Redirect Method to Node $name":
        subscribe => Exec["Create Node $name"],
        refreshonly => true,
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --addmethod pcmk-redirect $name",
        require => Package["ccs"], 
    }

    exec {"Activte Fencing Redirect for Node $name":
        subscribe => Exec["Create Node $name"],
        refreshonly => true,
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --addfenceinst pcmk-redirect $name pcmk-redirect port=$name",
        require => [Package["ccs"], Service["cman"]]
    }

    service { "cman":
        ensure => "running",
        require => File["/etc/sysconfig/cman"],
        hasstatus => true,
    }
    
    service { "pacemaker":
        ensure => "running",
        require => Service["cman"],
        hasstatus => true,
    }
}

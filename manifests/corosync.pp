define pacemaker::corosync() {

    package {["pacemaker", "cman", "corosync",
              "ccs", "pacemaker-cli"]:
	    ensure  => "installed",
    }

    firewall { '001 corosync mcast':
        proto    => 'udp',
        dport    => ['5404', '5405'],
        action   => 'accept',
    }

    file {"/etc/sysconfig/cman":
        source  => "puppet:///modules/pacemaker/etc/sysconfig/cman",
        require => Package["cman"], 
    }

    file {"/etc/corosync/service.d/pcmk":
        source  => "puppet:///modules/pacemaker/etc/corosync/service.d/pcmk",
        require => Package["corosync"], 
    }

    exec {"Create Cluster":
        creates => "/etc/cluster/cluster.conf",
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --createcluster $name",
        require => Package["ccs"], 
    }

    exec {"Setup Pacemaker Fencing Device":
        subscribe   => Exec["Create Cluster"],
        refreshonly => true,
        command     => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --addfencedev pcmk-redirect agent=fence_pcmk",
        unless      => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --lsfencedev | grep 'pcmk-redirect: agent=fence_pcmk'",
        require     => [Package["ccs"], Exec["Create Cluster"]],
    }

    service { "cman":
        ensure    => "running",
        require   => [File["/etc/sysconfig/cman"],
                      File["/etc/corosync/service.d/pcmk"],
                      Firewall['001 corosync mcast']],
        hasstatus => true,
    }
    
    service { "pacemaker":
        ensure    => "running",
        require   => Service["cman"],
        hasstatus => true,
    }
}

define pacemaker::corosync::node() {

    exec {"Create Node $name":
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --addnode $name",
        unless  => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --lsnodes | grep $name:",
        require => [Package["ccs"], Exec["Create Cluster"]],
        notify  => Service["cman"],
    }

    exec {"Add Fencing Redirect Method to Node $name":
        subscribe => Exec["Create Node $name"],
        #refreshonly => true,
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --addmethod pcmk-redirect $name",
        unless  => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --lsfenceinst $name | grep '  pcmk-redirect'",
        require => [Package["ccs"],Exec["Create Node $name"]]
    }

    exec {"Activate Fencing Redirect for Node $name":
        subscribe => Exec["Create Node $name"],
        #refreshonly => true,
        command => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --addfenceinst pcmk-redirect $name pcmk-redirect port=$name",
        unless  => "/usr/sbin/ccs -f /etc/cluster/cluster.conf --lsfenceinst $name | grep 'pcmk-redirect: port=$name'",
        require => [Package["ccs"], Exec["Add Fencing Redirect Method to Node $name"]]
    }
}

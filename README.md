# Pacemaker module for puppet

This module manages pacemaker on Linux distros with the ccs tool.

## Description

This module uses the fact osfamily which is supported by Facter 1.6.1+. If you do not have facter 1.6.1 in your environment, the following manifests will provide the same functionality in site.pp (before declaring any node):

    if ! $::osfamily {
      case $::operatingsystem {
        'RedHat', 'Fedora', 'CentOS', 'Scientific', 'SLC', 'Ascendos', 'CloudLinux', 'PSBM', 'OracleLinux', 'OVS', 'OEL': {
          $osfamily = 'RedHat'
        }
        'ubuntu', 'debian': {
          $osfamily = 'Debian'
        }
        'SLES', 'SLED', 'OpenSuSE', 'SuSE': {
          $osfamily = 'Suse'
        }
        'Solaris', 'Nexenta': {
          $osfamily = 'Solaris'
        }
        default: {
          $osfamily = $::operatingsystem
        }
      }
    }

This module is based on work by Dan Radez

## Usage

### pacemaker
Installs Pacemaker and corosync and creates a cluster

pacemaker::corosync { "cluster-name": }

### Add some Nodes
pacemaker::corosync::node { "10.10.10.1": }
pacemaker::corosync::node { "10.10.10.2": }

### Add a stonith device
pacemaker::stonith::ipmilan { "10.10.10.100":
    address => "10.10.10.100",
    user => "admin",
    password => "admin",
    hostlist => "10.10.10.1 10.10.10.2",
}


### Add a floating ip
pacemaker::crm::ip { "10.10.10.3":
    address => "10.10.10.3",
}

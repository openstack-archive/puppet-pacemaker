# This class should be included on all nodes that are
# part of a qpid cluster
# It ensures that the qpid cluster package is installed
# and that the nessesary configs are inplace for
# the qpid clustering to start using the pacemaker
# corosync instance

class pacemaker::resource::qpid($name,
                                $cluster_name,
                                $clone=true,
                                $group='',
                                $interval="30s",
                                $stickiness=0,
                                $ensure=present) {

  package { "qpid-cpp-server-cluster":
    ensure => installed,
  }

  file_line { 'Set Qpid Cluster Name':
    path    => '/etc/qpidd.conf',
    match   => '^[ ]*cluster_name=',
    line    => "cluster_name='${cluster_name}'",
  }

  # TODO: this should be replaced with an exec once
  # https://bugzilla.redhat.com/show_bug.cgi?id=1019368
  # has been completed
  augeas { "uidgid in cluster.conf":
    lens    => "Xml.lns",
    incl    => "/etc/cluster/cluster.conf",
    changes => [
      "set cluster/uidgid/#attribute/uid qpidd",
      "set cluster/uidgid/#attribute/gid qpidd",
    ],
    require => Package['qpid-cpp-server-cluster'],
  }

  pacemaker::resource::base { "qpidd":
    resource_type   => "lsb:qpidd",
    resource_params => "",
    group           => $group,
    clone           => $clone,
    interval        => "30s",
    ensure          => $ensure,
  }

}

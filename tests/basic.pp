# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation errors
# and view a log of events) or by fully applying the test in a virtual environment
# (to compare the resulting system state to the desired state).
#
# Learn more about module testing here: http://docs.puppetlabs.com/guides/tests_smoke.html
#
include ::pacemaker

package { 'haproxy':
  ensure => present,
}

class {'::pacemaker::corosync':
  cluster_name    => 'beaker_one_node_cluster',
  cluster_members => $::hostname,
}

### Disable stonith
class {'::pacemaker::stonith':
  disable => true,
}
### Add a stonith device
pacemaker::stonith::fence_ipmilan { 'ipmi_fence':
  ipaddr => '10.10.10.100',
  login  => 'admin',
  passwd => 'admin',
}

pacemaker::resource::ip {'vip':
  ensure             => present,
  ip_address         => '192.168.201.59',
  nic                => 'tap0',
  cidr_netmask       => '',
  post_success_sleep => 0,
  tries              => 1,
  try_sleep          => 1,
}

pacemaker::resource::ip {'vip6':
  ensure             => present,
  ip_address         => '2001:dead::28',
  nic                => 'tap0',
  cidr_netmask       => '',
  post_success_sleep => 0,
  tries              => 1,
  try_sleep          => 1,
}

# The haproxy is not configured!
pacemaker::resource::service { 'haproxy':
  clone_params => true,
  require      => Package['haproxy']
}


pacemaker::constraint::colocation { 'control_vip-with-haproxy':
  source  => 'ip-192.168.201.59',
  target  => 'haproxy-clone',
  score   => 'INFINITY',
  require => [Pacemaker::Resource::Service['haproxy'],
              Pacemaker::Resource::Ip['vip']],
}

pacemaker::constraint::base { 'public_vip-then-haproxy':
  constraint_type   => 'order',
  first_resource    => 'ip-192.168.201.59',
  second_resource   => 'haproxy-clone',
  first_action      => 'start',
  second_action     => 'start',
  constraint_params => 'kind=Optional',
  require           => [Pacemaker::Resource::Service['haproxy'],
                        Pacemaker::Resource::Ip['vip']],
}

pacemaker::constraint::colocation { 'control_vip6-with-haproxy':
  source  => 'ip-2001.dead..28',
  target  => 'haproxy-clone',
  score   => 'INFINITY',
  require => [Pacemaker::Resource::Service['haproxy'],
              Pacemaker::Resource::Ip['vip6']],
}

pacemaker::constraint::base { 'public_vip6-then-haproxy':
  constraint_type   => 'order',
  first_resource    => 'ip-2001.dead..28',
  second_resource   => 'haproxy-clone',
  first_action      => 'start',
  second_action     => 'start',
  constraint_params => 'kind=Optional',
  require           => [Pacemaker::Resource::Service['haproxy'],
                        Pacemaker::Resource::Ip['vip6']],
}

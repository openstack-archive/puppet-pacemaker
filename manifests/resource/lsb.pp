class pacemaker::resource::lsb($group='',
                               $interval="30s",
                               $ensure=present) {

  pacemaker::resource::base { "lsb-${name}":
    resource_type   => "lsb:${name}",
    resource_params => "",
    group           => $group,
    interval        => "30s",
    ensure          => $ensure,
  }

}

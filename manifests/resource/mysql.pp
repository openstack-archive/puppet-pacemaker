class pacemaker::resource::mysql($name,
                                 $group='',
                                 $clone=false,
                                 $interval="30s",
                                 $stickiness=0,
                                 $ensure=present,
                                 $replication_user='',
                                 $replication_passwd='', 
                                 $max_slave_lag=0,
                                 $evict_outdated_slaves=false,
                                 $enable_creation=true) {

  $replication_options = $replication_user ? {
      ''      => '',
      default => " replication_user=$replication_user replication_passwd=$replication_passwd max_slave_lag=$max_slave_lag evict_outdated_slaves=$evict_outdated_slaves"
  }

  pacemaker::resource::base { "mysql-${name}":
    resource_type   => "mysql",
    resource_params => "enable_creation=${enable_creation}${replication_options}",
    group           => $group,
    interval        => "30s",
    ensure          => $ensure,
  }

}

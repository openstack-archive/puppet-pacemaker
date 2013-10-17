define pacemaker::resource::base ($resource_type,
                                  $resource_params,
                                  $group='',
                                  $interval='30s',
                                  $ensure=present) {

  if($ensure == absent) {
    exec { "Removing ${name}":
      command => "/usr/sbin/pcs resource delete ${name}",
      onlyif  => "/usr/sbin/pcs resource show ${name}",
      require => Exec["Start Cluster ${corosync::cluster_name}"],
    }
  } else { 
    $group_options = $group ? {
      ''      => '',
      default => " --group ${group}"
    }

    exec { "Creating ${name}":
      command => "/usr/sbin/pcs resource create ${name} ${resource_type} ${resource_params} op monitor interval=${interval}${group_option}",
      unless  => "/usr/sbin/pcs resource show ${name} > /dev/null 2>&1",
      require => [Exec["Start Cluster ${corosync::cluster_name}"],Package["pcs"]]
    }

    pacemaker::resource::group { "${name}-${group}":
      resource_id    => $name,
      resource_group => $group,
      require        => Exec["Creating ${name}"],
    }
  }
}

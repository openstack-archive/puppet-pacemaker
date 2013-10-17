class pacemaker::resource::filesystem($device,
                                      $directory,
                                      $fstype,
                                      $group='',
                                      $interval="30s",
                                      $ensure=present) 

  pacemaker::resource::base { delete("fs-${directory}", '/'):
    resource_type   => "Filesystem",
    resource_params => "device=${device} directory=${directory} fstype=${fstype}",
    group           => $group,
    interval        => "30s",
    ensure          => $ensure,
  }
}

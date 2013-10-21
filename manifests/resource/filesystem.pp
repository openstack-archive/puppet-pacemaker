class pacemaker::resource::filesystem($device,
                                      $directory,
                                      $fstype,
                                      $group='',
                                      $interval="30s",
                                      $ensure=present) {
  $resource_id = delete("fs-${directory}", '/')
  pacemaker::resource::base { $resource_id:
    resource_type   => "Filesystem",
    resource_params => "device=${device} directory=${directory} fstype=${fstype}",
    group           => $group,
    interval        => "30s",
    ensure          => $ensure,
  }
}

define pacemaker::resource::route(
  $ensure       = 'present'
  $src          = '',
  $dest         = '',
  $gateway      = '',
  $nic          = '',
  $clone_params = undef,
  $group_params = undef,
) {

  $nic_option = $nic ? {
      ''      => '',
      default => " device=${nic}"
  }

  $src_option = $src ? {
      ''      => '',
      default => " source=${src}"
  }

  $dest_option = $dest ? {
      ''      => '',
      default => " destination=${dest}"
  }

  $gw_option = $gateway ? {
      ''      => '',
      default => " gateway=${gateway}"
  }

  pcmk_resource { "route-${name}-${group}":
    ensure          => $ensure,
    resource_type   => 'Route',
    resource_params => "${dest_option} ${src_option} ${nic_option} ${gw_option}",
    group_params    => $group_params,
    clone_params    => $clone_params,
  }

}

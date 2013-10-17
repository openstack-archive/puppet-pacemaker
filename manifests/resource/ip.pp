class pacemaker::resource::ip($ip_address,
                              $cidr_netmask=32,
                              $nic='',
                              $group='',
                              $interval="30s",
                              $ensure=present) {

  $nic_option = $nic ? {
      ''      => '',
      default => " nic=$nic"
  }

  pacemaker::resource::base { "ip-${ip_address}":
    resource_type   => "IPaddr2",
    resource_params => "ip=${ip_address} cidr_netmask=${cidr_netmask}${nic_option}",
    group           => $group,
    interval        => "30s",
    ensure          => $ensure,
  }

}

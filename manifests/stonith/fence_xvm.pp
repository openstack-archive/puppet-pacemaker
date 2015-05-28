class pacemaker::stonith::fence_xvm (
  $debug = undef,
  $ip_family = undef,
  $multicast_address = undef,
  $ipport = undef,
  $retrans = undef,
  $auth = undef,
  $hash = undef,
  $key_file = undef,
  $port = undef,
  $use_uuid = undef,
  $timeout = undef,
  $delay = undef,
  $domain = undef,

  $interval = "60s",
  $ensure = present,
  $pcmk_host_list = undef,

  $manage_key_file = false,
  $key_file = "/etc/cluster/fence_xvm.key",
  $key_file_password = "123456",
  $manage_fw = true,
) {
  $real_address = "$(corosync-cfgtool -a $(crm_node -n))"

  $debug_chunk = $debug ? {
    undef => "",
    default => "debug=\"${debug}\"",
  }
  $ip_family_chunk = $ip_family ? {
    undef => "",
    default => "ip_family=\"${ip_family}\"",
  }
  $multicast_address_chunk = $multicast_address ? {
    undef => "",
    default => "multicast_address=\"${multicast_address}\"",
  }
  $ipport_chunk = $ipport ? {
    undef => "",
    default => "ipport=\"${ipport}\"",
  }
  $retrans_chunk = $retrans ? {
    undef => "",
    default => "retrans=\"${retrans}\"",
  }
  $auth_chunk = $auth ? {
    undef => "",
    default => "auth=\"${auth}\"",
  }
  $hash_chunk = $hash ? {
    undef => "",
    default => "hash=\"${hash}\"",
  }
  $key_file_chunk = $key_file ? {
    undef => "",
    default => "key_file=\"${key_file}\"",
  }
  $port_chunk = $port ? {
    undef => "",
    default => "port=\"${port}\"",
  }
  $use_uuid_chunk = $use_uuid ? {
    undef => "",
    default => "use_uuid=\"${use_uuid}\"",
  }
  $timeout_chunk = $timeout ? {
    undef => "",
    default => "timeout=\"${timeout}\"",
  }
  $delay_chunk = $delay ? {
    undef => "",
    default => "delay=\"${delay}\"",
  }
  $domain_chunk = $domain ? {
    undef => "",
    default => "domain=\"${domain}\"",
  }

  $pcmk_host_value_chunk = $pcmk_host_list ? {
    undef => '$(/usr/sbin/crm_node -n)',
    default => "${pcmk_host_list}",
  }

  $resource_name = $pcmk_host_list ? {
    undef => $::hostname,
    default => "${pcmk_host_list}",
  }

  if($ensure == absent) {
    exec { "Delete stonith::fence_xvm for ${resource_name}":
      command => "/usr/sbin/pcs stonith delete stonith-fence_xvm-${real_address}",
      onlyif => "/usr/sbin/pcs stonith show stonith-fence_xvm-${real_address} > /dev/null 2>&1",
      require => Class["pacemaker::corosync"],
    }
  } else {
    if $manage_key_file {
      file { "$key_file":
        content => "$key_file_password",
      }
    }
    if $manage_fw {
      firewall { "003 fence_xvm":
        proto    => 'igmp',
        action   => 'accept',
      }
      firewall { "004 fence_xvm":
        proto    => 'udp',
        dport     => '1229',
        action   => 'accept',
      }
      firewall { "005 fence_xvm":
        proto    => 'tcp',
        dport     => '1229',
        action   => 'accept',
      }
    }

    package {
      "fence-virt": ensure => installed,
    } ->
    exec { "Create stonith::fence_xvm for ${resource_name}":
      command => "/usr/sbin/pcs stonith create stonith-fence_xvm-${real_address} fence_xvm pcmk_host_list=\"${pcmk_host_value_chunk}\" ${debug_chunk} ${ip_family_chunk} ${multicast_address_chunk} ${ipport_chunk} ${retrans_chunk} ${auth_chunk} ${hash_chunk} ${key_file_chunk} ${port_chunk} ${use_uuid_chunk} ${timeout_chunk} ${delay_chunk} ${domain_chunk}  op monitor interval=${interval}",
      unless => "/usr/sbin/pcs stonith show stonith-fence_xvm-${real_address} > /dev/null 2>&1",
      require => Class["pacemaker::corosync"],
    } ->
    exec { "Add non-local constraint stonith::fence_xvm for ${resource_name}":
      command => "/usr/sbin/pcs constraint location stonith-fence_xvm-${real_address} avoids ${pcmk_host_value_chunk}"
    }
  }
}

class pacemaker::params {

  $hacluster_pwd         = 'CHANGEME'
  case $::osfamily {
    redhat: {
      if $::operatingsystemrelease =~ /^6\..*$/ {      
        $package_list = ["pacemaker", "pcs", "cman"]
        # TODO in el6.6, $pcsd_mode should be true
        $pcsd_mode = false
      } else {
        $package_list = ["pacemaker", "pcs"]
        $pcsd_mode = true
      }
      $service_name = 'pacemaker'
    }
    default: {
      case $::operatingsystem {
        default: {
          fail("Unsupported platform: ${::osfamily}/${::operatingsystem}")
        }
      }
    }
  }
}

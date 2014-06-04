class pacemaker::params {

  $hacluster_pwd         = 'CHANGEME'
  case $::osfamily {
    redhat: {
      if $::operatingsystemrelease =~ /^6\..*$/ {      
        $package_list = ["pacemaker", "pcs", "cman"]
      } else {
        $package_list = ["pacemaker", "pcs"]
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

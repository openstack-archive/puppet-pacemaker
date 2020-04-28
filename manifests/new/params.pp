# == Class: pacemaker::new::params
#
# Common default parameter values for the Paceamker module
#
class pacemaker::new::params {
  $release = split($::os['release']['full'], '[.]')
  $major = $::os['release']['major']
  $minor = $::os['release']['minor']

  if $::os['family'] == 'RedHat' {
    $package_list  = ['pacemaker', 'pcs', 'fence-agents-all', 'pacemaker-libs']
    $pcsd_mode     = true
    $cluster_user  = 'hacluster'
    $cluster_group = 'haclient'
    $log_file_path = '/var/log/cluster/corosync.log'
  } elsif $::os['family'] == 'Debian' {
    $pcsd_mode = false
    if ($::os['name'] == 'Ubuntu') and (versioncmp($::os['release']['full'], '16') >= 0) {
      $package_list = ['dbus', 'pacemaker', 'corosync', 'pacemaker-cli-utils', 'resource-agents', 'crmsh']
    } else {
      $package_list = ['pacemaker-mgmt', 'pacemaker', 'corosync', 'pacemaker-cli-utils', 'resource-agents', 'crmsh']
    }
    $cluster_user  = 'root'
    $cluster_group = 'root'
    $log_file_path = '/var/log/corosync/corosync.log'
  } else {
    fail("OS '${::os['name']}' is not supported!")
  }

  $firewall_ipv6_manage     = true
  $firewall_corosync_manage = true
  $firewall_corosync_ensure = 'present'
  $firewall_corosync_dport  = ['5404', '5405']
  $firewall_corosync_proto  = 'udp'
  $firewall_corosync_action = 'accept'
  $firewall_pcsd_manage     = $pcsd_mode
  $firewall_pcsd_ensure     = 'present'
  $firewall_pcsd_dport      = ['2224']
  $firewall_pcsd_action     = 'accept'

  $cluster_nodes       = ['localhost']
  $cluster_rrp_nodes   = undef
  $cluster_name        = 'clustername'
  $cluster_setup       = true
  $cluster_config_path = '/etc/corosync/corosync.conf'
  $cluster_options     = {}
  $cluster_interfaces  = []
  $cluster_log_subsys  = []
  $plugin_version      = '1'

  $cluster_auth_key     = undef
  $cluster_auth_enabled = false

  $pcs_bin_path       = '/usr/sbin/pcs'
  $cluster_password   = 'CHANGEME'

  $package_manage     = true
  $package_ensure     = 'installed'
  $package_provider   = undef

  $pcsd_manage        = $pcsd_mode
  $pcsd_service       = 'pcsd'
  $pcsd_enable        = true
  $pcsd_provider      = undef
  $corosync_manage    = true
  $corosync_service   = 'corosync'
  $corosync_enable    = true
  $corosync_provider  = undef
  $pacemaker_manage   = true
  $pacemaker_service  = 'pacemaker'
  $pacemaker_enable   = true
  $pacemaker_provider = undef

}

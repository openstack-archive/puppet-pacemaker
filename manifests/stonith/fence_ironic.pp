# == Define: pacemaker::stonith::fenceironic_
#
# Configures stonith to use fence_ironic
#
# === Parameters:
#
# [*debug*]
#   (optional) Specify (stdin) or increment (command line) debug level
#   Defaults to undef
#
# [*auth-url*]
#   Keystone URL to authenticate against
#   Defaults to undef
#
# [*tenant-name*]
#   Keystone tenant name to authenticate with
#   Defaults to undef
#
# [*login*]
#   Keystone username to authenticate with
#   Defaults to undef
#
# [*passwd*]
#   Keystone password to authenticate with
#   Defaults to undef
#
# [*pcmk_host_map*]
#   Mapping of Ironic UUID to node name
#   Defaults to undef
#
# [*timeout*]
#   (optional) Fencing timeout (in seconds)
#   Defaults to undef
#
# [*delay*]
#   (optional) Fencing delay (in seconds)
#   Defaults to undef
#
# [*interval*]
#   (optional) Monitor interval
#   Defaults to 60s
#
# [*ensure*]
#   (optional) Whether to make sure resource is present or absent
#   Defaults to present
#
# [*pcmk_host_list*]
#   (optional) List of nodes
#   Defaults to undef
#
# [*tries*]
#   (optional) How many times to attempt creating or deleting this resource
#   Defaults to undef
#
# [*try_sleep*]
#   (optional) How long to wait between tries
#   Defaults to undef
#
# === Dependencies
#  openstack command line interface
#
# === Authors:
#  Chris Jones <cmsj@tenshu.net>
#
# === Copyright
#
# Copyright (C) 2016 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
define pacemaker::stonith::fence_ironic (
  $debug             = undef,
  $auth_url          = undef,
  $login             = undef,
  $passwd            = undef,
  $tenant_name       = undef,
  $pcmk_host_map     = undef,
  $timeout           = undef,
  $delay             = undef,
  $domain            = undef,

  $interval          = '60s',
  $ensure            = present,
  $pcmk_host_list    = undef,

  $tries             = undef,
  $try_sleep         = undef,
) {
  $debug_chunk = $debug ? {
    undef   => '',
    default => "debug=\"${debug}\"",
  }
  $auth_url_chunk = $auth_url ? {
    undef   => '',
    default => "auth-url=\"${auth_url}\"",
  }
  $login_chunk = $login ? {
    undef   => '',
    default => "login=\"${login}\"",
  }
  $passwd_chunk = $passwd ? {
    undef   => '',
    default => "passwd=\"${passwd}\"",
  }
  $tenant_name_chunk = $tenant_name ? {
    undef   => '',
    default => "tenant-name=\"${tenant_name}\"",
  }
  $pcmk_host_map_chunk = $pcmk_host_map ? {
    undef   => '',
    default => "pcmk_host_map=\"${pcmk_host_map}\"",
  }
  $timeout_chunk = $timeout ? {
    undef   => '',
    default => "timeout=\"${timeout}\"",
  }
  $delay_chunk = $delay ? {
    undef   => '',
    default => "delay=\"${delay}\"",
  }
  $domain_chunk = $domain ? {
    undef   => '',
    default => "domain=\"${domain}\"",
  }

  $pcmk_host_value_chunk = $pcmk_host_list ? {
    undef   => '$(/usr/sbin/crm_node -n)',
    default => $pcmk_host_list,
  }

  # $title can be a mac address, remove the colons for pcmk resource name
  $safe_title = regsubst($title, ':', '', 'G')

  if($ensure == absent) {
    exec { "Delete stonith-fence_ironic-${safe_title}":
      command => "/usr/sbin/pcs stonith delete stonith-fence_ironic-${safe_title}",
      onlyif  => "/usr/sbin/pcs stonith show stonith-fence_ironic-${safe_title} > /dev/null 2>&1",
      require => Class['pacemaker::corosync'],
    }
  } else {
    package {
      'fence-agents-ironic': ensure => installed,
    } ->
    exec { "Create stonith-fence_ironic-${safe_title}":
      command   => "/usr/sbin/pcs stonith create stonith-fence_ironic-${safe_title} fence_ironic ${auth_url_chunk} ${login_chunk} ${passwd_chunk} ${tenant_name_chunk} ${pcmk_host_map_chunk} ${debug_chunk} ${timeout_chunk} ${delay_chunk} ${domain_chunk}  op monitor interval=${interval}",
      unless    => "/usr/sbin/pcs stonith show stonith-fence_ironic-${safe_title} > /dev/null 2>&1",
      tries     => $tries,
      try_sleep => $try_sleep,
      require   => Class['pacemaker::corosync'],
    } ~>
    exec { "Add non-local constraint for stonith-fence_ironic-${safe_title}":
      command     => "/usr/sbin/pcs constraint location stonith-fence_ironic-${safe_title} avoids ${pcmk_host_value_chunk}",
      tries       => $tries,
      try_sleep   => $try_sleep,
      refreshonly => true,
    }
  }
}

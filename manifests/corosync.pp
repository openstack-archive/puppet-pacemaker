# == Class: pacemaker::corosync
#
# A class to setup a pacemaker cluster
#
# === Parameters
# [*cluster_members*]
#   (required) A space-separted list of cluster IP's or names to run the
#   authentication against
#
# [*cluster_members_addr*]
#   (optional) An array of arrays containing the node addresses to be used
#   As ring addresses in corosync (as required by corosync3+knet). For example:
#   [[10.0.0.1], [10.0.0.10], [10.0.0.20,10.0.0.21]] with nodes [n1, n2, n3]
#   will create the cluster as follows:
#   pcs cluster setup clustername n1 addr=10.0.0.1 n2 addr=10.0.0.10 \
#     n3 addr=10.0.0.20 addr=10.0.0.21
#   Defaults to []
#
# [*cluster_members_rrp*]
#   (optional) A space-separated list of cluster IP's or names pair where each
#   component represent a resource on respectively ring0 and ring1
#   Defaults to undef
#
# [*cluster_name*]
#   (optional) The name of the cluster (no whitespace)
#   Defaults to 'clustername'
#
# [*cluster_setup_extras*]
#   (optional) Hash additional configuration when pcs cluster setup is run
#   Example : {'--token' => '10000', '--ipv6' => '', '--join' => '100' }
#   Defaults to {}
#
# [*cluster_start_timeout*]
#   (optional) Timeout to wait for cluster start.
#   Defaults to 300
#
# [*cluster_start_tries*]
#   (optional) Number of tries for cluster start.
#   Defaults to 10
#
# [*cluster_start_try_sleep*]
#   (optional) Time to sleep after each cluster start try.
#   Defaults to 20
#
# [*manage_fw*]
#   (optional) Manage or not IPtables rules.
#   Defaults to true
#
# [*remote_authkey*]
#   (optional) Value of /etc/pacemaker/authkey.  Useful for pacemaker_remote.
#   Defaults to undef
#
# [*settle_timeout*]
#   (optional) Timeout to wait for settle.
#   Defaults to 3600
#
# [*settle_tries*]
#   (optional) Number of tries for settle.
#   Defaults to 360
#
# [*settle_try_sleep*]
#   (optional) Time to sleep after each seetle try.
#   Defaults to 10
#
# [*setup_cluster*]
#   (optional) If your cluster includes pcsd, this should be set to true for
#   just one node in cluster.  Else set to true for all nodes.
#   Defaults to true
#
# [*pcsd_debug*]
#   (optional) Enable pcsd debugging
#   Defaults to false
#
# [*tls_priorities*]
#   (optional) Sets PCMK_tls_priorities in /etc/sysconfig/pacemaker when set
#   Defaults to undef
#
# === Dependencies
#
#  None
#
# === Authors
#
#  Crag Wolfe <cwolfe@redhat.com>
#  Jason Guiditta <jguiditt@redhat.com>
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
class pacemaker::corosync(
  $cluster_members,
  $cluster_members_addr    = [],
  $cluster_members_rrp     = undef,
  $cluster_name            = 'clustername',
  $cluster_setup_extras    = {},
  $cluster_start_timeout   = '300',
  $cluster_start_tries     = '10',
  $cluster_start_try_sleep = '20',
  $manage_fw               = true,
  $remote_authkey          = undef,
  $settle_timeout          = '3600',
  $settle_tries            = '360',
  $settle_try_sleep        = '10',
  $setup_cluster           = true,
  $pcsd_debug              = false,
  $tls_priorities          = undef,
) inherits pacemaker {
  include ::pacemaker::params
  if ! $cluster_members_rrp {
    if $::pacemaker::pcs_010 {
      $cluster_members_rrp_real = pcmk_cluster_setup($cluster_members, $cluster_members_addr, '0.10')
    } else {
      $cluster_members_rrp_real = pcmk_cluster_setup($cluster_members, $cluster_members_addr, '0.9')
    }
  } else {
    $cluster_members_rrp_real = $cluster_members_rrp
  }
  $cluster_setup_extras_real = inline_template('<%= @cluster_setup_extras.flatten.join(" ") %>')

  if $manage_fw {
    firewall { '001 corosync mcast':
      proto  => 'udp',
      dport  => ['5404', '5405'],
      action => 'accept',
    }
    firewall { '001 corosync mcast ipv6':
      proto    => 'udp',
      dport    => ['5404', '5405'],
      action   => 'accept',
      provider => 'ip6tables',
    }
  }

  if $pacemaker::pcsd_mode {
    if $manage_fw {
      firewall { '001 pcsd':
        proto  => 'tcp',
        dport  => ['2224'],
        action => 'accept',
      }
      firewall { '001 pcsd ipv6':
        proto    => 'tcp',
        dport    => ['2224'],
        action   => 'accept',
        provider => 'ip6tables',
      }
    }

    $pcsd_debug_str = bool2str($pcsd_debug)
    file_line { 'pcsd_debug_ini':
      path    => $::pacemaker::pcsd_sysconfig,
      line    => "PCSD_DEBUG=${pcsd_debug_str}",
      match   => '^PCSD_DEBUG=',
      require => Class['::pacemaker::install'],
      before  => Service['pcsd'],
      notify  => Service['pcsd'],
    }
    if $tls_priorities != undef {
      file_line { 'tls_priorities':
        path    => $::pacemaker::pcmk_sysconfig,
        line    => "PCMK_tls_priorities=${tls_priorities}",
        match   => '^PCMK_tls_priorities=',
        require => Class['::pacemaker::install'],
        before  => Service['pcsd'],
      }
    }

    user { 'hacluster':
      password => pw_hash($::pacemaker::hacluster_pwd, 'SHA-512', fqdn_rand_string(10)),
      groups   => 'haclient',
      require  => Class['::pacemaker::install'],
      before   => Service['pcsd'],
      notify   => Exec['reauthenticate-across-all-nodes'],
    }

    # pcs-0.10.x has different commands to set up the cluster
    if $::pacemaker::pcs_010 {
      $cluster_setup_cmd = "${::pacemaker::pcs_bin} cluster setup ${cluster_name} ${cluster_members_rrp_real}"
      $cluster_reauthenticate_cmd = "${::pacemaker::pcs_bin} host auth ${cluster_members} -u hacluster -p ${::pacemaker::hacluster_pwd}"
      $cluster_authenticate_cmd = "${::pacemaker::pcs_bin} host auth ${cluster_members} -u hacluster -p ${::pacemaker::hacluster_pwd}"
      $cluster_authenticate_unless = "${::pacemaker::pcs_bin} host auth ${cluster_members} -u hacluster -p ${::pacemaker::hacluster_pwd} | grep 'Already authorized'"
    } else {
      $cluster_setup_cmd = "${::pacemaker::pcs_bin} cluster setup --wait --name ${cluster_name} ${cluster_members_rrp_real} ${cluster_setup_extras_real}"
      $cluster_reauthenticate_cmd = "${::pacemaker::pcs_bin} cluster auth ${cluster_members} -u hacluster -p ${::pacemaker::hacluster_pwd} --force"
      $cluster_authenticate_cmd = "${::pacemaker::pcs_bin} cluster auth ${cluster_members} -u hacluster -p ${::pacemaker::hacluster_pwd}"
      $cluster_authenticate_unless = "${::pacemaker::pcs_bin} cluster auth ${cluster_members} -u hacluster -p ${::pacemaker::hacluster_pwd} | grep 'Already authorized'"
    }


    exec { 'reauthenticate-across-all-nodes':
      command     => $cluster_reauthenticate_cmd,
      refreshonly => true,
      timeout     => $settle_timeout,
      tries       => $settle_tries,
      try_sleep   => $settle_try_sleep,
      require     => Service['pcsd'],
      tag         => 'pacemaker-auth',
    }

    exec { 'auth-successful-across-all-nodes':
      command     => $cluster_authenticate_cmd,
      refreshonly => true,
      timeout     => $settle_timeout,
      tries       => $settle_tries,
      try_sleep   => $settle_try_sleep,
      require     => [Service['pcsd'], User['hacluster']],
      unless      => $cluster_authenticate_unless,
      tag         => 'pacemaker-auth',
    }

    Exec <|tag == 'pacemaker-auth'|> -> Exec['wait-for-settle']
  }

  if $setup_cluster {
    # Detect if we are trying to add some nodes by comparing
    # $cluster_members and the actual running nodes in the cluster
    if $::pacemaker::pcs_010 {
      $nodes_added = pcmk_nodes_added($cluster_members, $cluster_members_addr, '0.10')
      $node_add_start_part = '--start'
    } else {
      $nodes_added = pcmk_nodes_added($cluster_members, $cluster_members_addr, '0.9')
      $node_add_start_part = ''
    }
    # If we're rerunning this puppet manifest and $cluster_members
    # contains more nodes than the currently running cluster
    if count($nodes_added) > 0 {
      $nodes_added.each |$node_to_add| {
        $node_name = split($node_to_add, ' ')[0]
        exec {"Adding Cluster node: ${node_to_add} to Cluster ${cluster_name}":
          unless    => "${::pacemaker::pcs_bin} status 2>&1 | grep -e \"^Online:.* ${node_name} .*\"",
          command   => "${::pacemaker::pcs_bin} cluster node add ${node_to_add} ${node_add_start_part} --wait",
          timeout   => $cluster_start_timeout,
          tries     => $cluster_start_tries,
          try_sleep => $cluster_start_try_sleep,
          notify    => Exec["node-cluster-start-${node_name}"],
          tag       => 'pacemaker-scaleup',
        }
        exec {"node-cluster-start-${node_name}":
          unless      => "${::pacemaker::pcs_bin} status 2>&1 | grep -e \"^Online:.* ${node_name} .*\"",
          command     => "${::pacemaker::pcs_bin} cluster start ${node_name} --wait",
          timeout     => $cluster_start_timeout,
          tries       => $cluster_start_tries,
          try_sleep   => $cluster_start_try_sleep,
          refreshonly => true,
          tag         => 'pacemaker-scaleup',
        }
      }
      Exec <|tag == 'pacemaker-auth'|> -> Exec <|tag == 'pacemaker-scaleup'|>
    }

    Exec <|tag == 'pacemaker-auth'|>
    ->
    exec {"Create Cluster ${cluster_name}":
      creates   => '/etc/cluster/cluster.conf',
      command   => $cluster_setup_cmd,
      timeout   => $cluster_start_timeout,
      tries     => $cluster_start_tries,
      try_sleep => $cluster_start_try_sleep,
      unless    => '/usr/bin/test -f /etc/corosync/corosync.conf',
      require   => Class['::pacemaker::install'],
    }
    ->
    exec {"Start Cluster ${cluster_name}":
      unless    => "${::pacemaker::pcs_bin} status >/dev/null 2>&1",
      command   => "${::pacemaker::pcs_bin} cluster start --all",
      timeout   => $cluster_start_timeout,
      tries     => $cluster_start_tries,
      try_sleep => $cluster_start_try_sleep,
      require   => Exec["Create Cluster ${cluster_name}"],
    }
    if $pacemaker::pcsd_mode {
      Exec['auth-successful-across-all-nodes'] ->
        Exec["Create Cluster ${cluster_name}"]
    }
    Exec["Start Cluster ${cluster_name}"]
    ->
    Service <| tag == 'pcsd-cluster-service' |>
    ->
    Exec['wait-for-settle']
  }

  # pcs 0.10/pcmk 2.0 take care of the authkey internally by themselves
  if $remote_authkey and !$::pacemaker::pcs_010 {
    file { 'etc-pacemaker':
      ensure => directory,
      path   => '/etc/pacemaker',
      owner  => 'hacluster',
      group  => 'haclient',
      mode   => '0750',
    } ->
    file { 'etc-pacemaker-authkey':
      path    => '/etc/pacemaker/authkey',
      owner   => 'hacluster',
      group   => 'haclient',
      mode    => '0640',
      content => $remote_authkey,
    }
    File['etc-pacemaker-authkey'] -> Service['pcsd']
  }

  exec {'wait-for-settle':
    timeout   => $settle_timeout,
    tries     => $settle_tries,
    try_sleep => $settle_try_sleep,
    command   => "${::pacemaker::pcs_bin} status | grep -q 'partition with quorum' > /dev/null 2>&1",
    unless    => "${::pacemaker::pcs_bin} status | grep -q 'partition with quorum' > /dev/null 2>&1",
  }
  Exec<| title == 'wait-for-settle' |> -> Pcmk_constraint<||>
  Exec<| title == 'wait-for-settle' |> -> Pcmk_resource<||>
  Exec<| title == 'wait-for-settle' |> -> Pcmk_property<||>
  Exec<| title == 'wait-for-settle' |> -> Pcmk_bundle<||>
}

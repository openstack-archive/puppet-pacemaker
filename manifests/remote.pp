# Copyright 2016 Red Hat, Inc.
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
# == Class: pacemaker::remote
#
# Pacemaker remote manifest. This class is a small helper to set up a pacemaker
# remote node. It does not create the pacemaker-remote resource in the CIB but only
# sets up the remote service
#
# === Parameters
#
# [*use_pcsd*]
#   (optional) Should the remote use pcsd to be setup
#   Defaults to false
#
# [*manage_fw*]
#   (optional) Manage or not IPtables rules.
#   Defaults to true
#
# [*remote_authkey*]
#   (Required) Authkey for pacemaker remote nodes
#   Defaults to undef
#
# [*pcsd_debug*]
#   (optional) Enable pcsd debugging
#   Defaults to false
#
# [*pcsd_bind_addr*]
#   (optional) List of IP addresses pcsd should bind to
#   Defaults to undef
#
# [*tls_priorities*]
#   (optional) Sets PCMK_tls_priorities in /etc/sysconfig/pacemaker when set
#   Defaults to undef
#
class pacemaker::remote (
  $remote_authkey,
  $use_pcsd        = false,
  $pcs_user        = 'hacluster',
  $pcs_password    = undef,
  $manage_fw       = true,
  $pcsd_debug      = false,
  $pcsd_bind_addr  = undef,
  $tls_priorities  = undef,
) {
  include ::pacemaker::params
  ensure_resource('package', $::pacemaker::params::pcmk_remote_package_list, {
    ensure => present
  })
  # pacemaker remote needs pcsd only with pcs >= 0.10
  if $use_pcsd {
    include ::pacemaker::install
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
      path    => $::pacemaker::params::pcsd_sysconfig,
      line    => "PCSD_DEBUG=${pcsd_debug_str}",
      match   => '^PCSD_DEBUG=',
      require => Class['::pacemaker::install'],
      before  => Service['pcsd'],
      notify  => Service['pcsd'],
    }

    if $pcsd_bind_addr != undef {
      file_line { 'pcsd_bind_addr':
        path    => $::pacemaker::pcsd_sysconfig,
        line    => "PCSD_BIND_ADDR='${pcsd_bind_addr}'",
        match   => '^PCSD_BIND_ADDR=',
        require => Class['::pacemaker::install'],
        before  => Service['pcsd'],
        notify  => Service['pcsd'],
      }
    }
    else {
      file_line { 'pcsd_bind_addr':
        ensure            => absent,
        path              => $::pacemaker::params::pcsd_sysconfig,
        match             => '^PCSD_BIND_ADDR=*',
        require           => Class['::pacemaker::install'],
        before            => Service['pcsd'],
        notify            => Service['pcsd'],
        match_for_absence => true,
      }
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

    user { $pcs_user:
      password => pw_hash($pcs_password, 'SHA-512', fqdn_rand_string(10)),
      groups   => 'haclient',
      require  => Class['::pacemaker::install'],
      before   => Service['pcsd'],
    }
    # only set up pcsd, not the other cluster services which have
    # very specific setup and when-to-start-up requirements
    # that are taken care of in corosync.pp
    service { 'pcsd':
      ensure     => running,
      hasstatus  => true,
      hasrestart => true,
      enable     => true,
      require    => Class['::pacemaker::install'],
    }
  } else {
  # This gets managed by pcsd directly when pcs is < 0.10
    Package<| title == 'pacemaker-remote' |> -> File <| title == 'etc-pacemaker' |>
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
    } ->
    service { 'pacemaker_remote':
      ensure => running,
      enable => true,
    }
  }
}

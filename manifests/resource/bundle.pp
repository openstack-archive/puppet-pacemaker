# == Define: pacemaker::resource::bundle
#
# A resource type to create pacemaker bundle resources, provided
# for convenience.
#
# === Parameters
#
# [*ensure*]
#   (optional) Whether to make sure resource is created or removed
#   Defaults to present
#
# [*image*]
#   (required) Container image to be used by the bundle
#   Defaults to undef
#
# [*container_options*]
#   (optional) Options to be added to the pcs container argument
#   Defaults to undef
#
# [*replicas*]
#   (optional) Number of replicas to be used for the containers
#   Defaults to undef
#
# [*masters*]
#   (optional) Number of masters to be set in the bundle
#   Defaults to undef
#
# [*promoted_max*]
#   (optional) Number of masters to be set in the bundle. Supersedes
#   deprecated option 'masters' in pacemaker 2
#   Defaults to undef
#
# [*options*]
#   (optional) Options to be passed to the docker run command
#   Defaults to undef
#
# [*run_command*]
#   (optional) run-command to be used when starting the container
#   Defaults to undef
#
# [*storage_maps*]
#   (optional) Hash defining the docker volume mappings. Must
#   be a hash of hashes like the following:
#   storage_maps => {
#     'mysql-cfg-files'  => { 'source-dir' => '/var/lib/kolla/config_files/mysql.json',
#                             'target-dir' => '/var/lib/kolla/config_files/config.json',
#                             'options'    => 'ro',
#                           },
#     'mysql-data-files' => { 'source-dir' => '/var/lib/config-data/mysql',
#                             'target-dir' => '/var/lib/kolla/config_files/src',
#                             'options'    => 'rw',
#                           },
#   }
#
# [*network*]
#   (optional) Parameters passed to the network argument of pcs
#   Defaults to undef
#
# [*post_success_sleep*]
#   (optional) How long to wait acfter successful action
#   Defaults to 0
#
# [*tries*]
#   (optional) How many times to attempt to perform the action
#   Defaults to 1
#
# [*try_sleep*]
#   (optional) How long to wait between tries
#   Defaults to 0
#
# [*verify_on_create*]
#   (optional) Whether to verify creation of resource
#   Defaults to false
#
# [*force*]
#   (optional) Whether to force creation via pcs --force
#   Defaults to false
#
# [*location_rule*]
#   (optional) Add a location constraint before actually enabling
#   the resource. Must be a hash like the following example:
#   location_rule => {
#     resource_discovery => 'exclusive',    # optional
#     role               => 'master|slave', # optional
#     score              => 0,              # optional
#     score_attribute    => foo,            # optional
#     # Multiple expressions can be used
#     expression         => ['opsrole eq controller']
#   }
#   Defaults to undef
#
# [*deep_compare*]
#   (optional) Enable deep comparing of resources and bundles
#   When set to true a resource will be compared in full (options, meta parameters,..)
#   to the existing one and in case of difference it will be repushed to the CIB
#   Defaults to false
#
# [*update_settle_secs*]
#   (optional) When deep_compare is enabled and puppet updates a resource, this
#   parameter represents the number (in seconds) to wait for the cluster to settle
#   after the resource update.
#   Defaults to lookup('pacemaker::resource::bundle::update_settle_secs', undef, undef, 600) (seconds)
#
# === Dependencies
#
#  None
#
# === Authors
#
#  Michele Baldessari <michele@acksyn.org>
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
define pacemaker::resource::bundle(
  $ensure             = 'present',
  $image              = undef,
  $container_options  = undef,
  $replicas           = undef,
  $masters            = undef,
  $promoted_max       = undef,
  $options            = undef,
  $run_command        = undef,
  $storage_maps       = undef,
  $network            = undef,
  $post_success_sleep = 0,
  $tries              = 1,
  $try_sleep          = 0,
  $verify_on_create   = false,
  $force              = false,
  $location_rule      = undef,
  $container_backend  = 'docker',
  $deep_compare       = lookup('pacemaker::resource::bundle::deep_compare', undef, undef, false),
  $update_settle_secs = lookup('pacemaker::resource::bundle::update_settle_secs', undef, undef, 600),
  ) {
  if $image == undef {
    fail("Cannot create bundle ${name} without specifying an image")
  }
  # pcs resource bundle create foo container image=docker.io/nginxdemos/hello
  # replicas=1 masters=1 options="--uts=host --net=host --user=root
  # --log-driver=journald -e KOLLA_CONFIG_STRATEGY=COPY_ALWAYS"
  # run-command="/bin/bash" storage-map id=foo-storage-test source-dir=/tmp
  # target-dir=/var/log options=ro storage-map id=bar-storage-test
  # source-dir=/foo target-dir=/bar options=wr

  if $::pacemaker::pcs_010 {
    if $promoted_max and $masters {
      warning('Both \'masters\' and \'promoted_max\' specified, using option \'promoted_max\'')
    }

    # promoted_max supersedes masters in pacemaker 2 (pcs >= 0.10)
    if $promoted_max {
      $used_promoted_max = $promoted_max
    } else {
      $used_promoted_max = $masters
    }
    $used_masters = undef
  } else {
    if $promoted_max {
      fail('Cannot use \'promoted_max\' without pacemaker 2 and pcs >= 0.10')
    }
    $used_promoted_max = undef
    $used_masters = $masters
  }

  pcmk_bundle { $name:
    ensure             => $ensure,
    image              => $image,
    container_options  => $container_options,
    replicas           => $replicas,
    masters            => $used_masters,
    promoted_max       => $used_promoted_max,
    options            => $options,
    run_command        => $run_command,
    storage_maps       => $storage_maps,
    network            => $network,
    post_success_sleep => $post_success_sleep,
    tries              => $tries,
    try_sleep          => $try_sleep,
    verify_on_create   => $verify_on_create,
    force              => $force,
    location_rule      => $location_rule,
    container_backend  => $container_backend,
    deep_compare       => $deep_compare,
    update_settle_secs => $update_settle_secs,
  }
}

#
# Copyright (C) 2017 Red Hat, Inc.
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
require 'spec_helper'

describe 'pacemaker::stonith::fence_ipmilan', type: :define do

  let(:title) { 'test' }

  shared_examples_for 'pacemaker::stonith::fence_ipmilan' do
    let(:stonith_name) { "stonith-fence_ipmilan-#{title}" }
    context 'with defaults' do
      it {
        is_expected.to contain_package('fence-agents-ipmilan')
        is_expected.to contain_exec("Create #{stonith_name}").with(
          :command => "/usr/sbin/pcs stonith create #{stonith_name} fence_ipmilan pcmk_host_list=\"$(/usr/sbin/crm_node -n)\"                 op monitor interval=60s",
          :unless  => "/usr/sbin/pcs stonith show #{stonith_name} > /dev/null 2>&1"
        )
        is_expected.to contain_exec("Add non-local constraint for #{stonith_name}").with(
          :command => "/usr/sbin/pcs constraint location #{stonith_name} avoids $(/usr/sbin/crm_node -n)"
        )
      }
    end

    context 'with ensure absent' do
      let(:params) { {
        :ensure => 'absent'
      } }
      it {
        is_expected.to contain_exec('Delete stonith-fence_ipmilan-test').with(
          :command => '/usr/sbin/pcs stonith delete stonith-fence_ipmilan-test',
          :onlyif  => '/usr/sbin/pcs stonith show stonith-fence_ipmilan-test > /dev/null 2>&1'
        )
        is_expected.to_not contain_package('fence-agents-ipmilan')
        is_expected.to_not contain_exec('Create stonith-fence_ipmilan-test')
        is_expected.to_not contain_exec('Add non-local constraint for stonith-fence_ipmilan-test')
      }
    end

    context 'with params' do
      let(:params) { {
        :auth           => 'auth',
        :ipaddr         => 'ipaddr',
        :ipport         => 'ipport',
        :passwd         => 'passwd',
        :passwd_script  => 'passwd_script',
        :lanplus        => 'lanplus',
        :login          => 'login',
        :action         => 'action',
        :timeout        => 'timeout',
        :cipher         => 'cipher',
        :method         => 'method',
        :power_wait     => 'power_wait',
        :delay          => 'delay',
        :privlvl        => 'privlvl',
        :verbose        => 'verbose',
        :pcmk_host_list => 'pcmk_host_list',
        :tries          => 1,
        :try_sleep      => 5,
      } }

      it {
        is_expected.to contain_package('fence-agents-ipmilan')
        is_expected.to contain_exec("Create #{stonith_name}").with(
          :command => "/usr/sbin/pcs stonith create #{stonith_name} fence_ipmilan pcmk_host_list=\"pcmk_host_list\" auth=\"auth\" ipaddr=\"ipaddr\" ipport=\"ipport\" passwd=\"passwd\" passwd_script=\"passwd_script\" lanplus=\"lanplus\" login=\"login\" action=\"action\" timeout=\"timeout\" cipher=\"cipher\" method=\"method\" power_wait=\"power_wait\" delay=\"delay\" privlvl=\"privlvl\" verbose=\"verbose\"  op monitor interval=60s",
          :unless  => "/usr/sbin/pcs stonith show #{stonith_name} > /dev/null 2>&1"
        )
        is_expected.to contain_exec("Add non-local constraint for #{stonith_name}").with(
          :command   => "/usr/sbin/pcs constraint location #{stonith_name} avoids pcmk_host_list",
          :tries     => 1,
          :try_sleep => 5
        )
      }

    end
  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge({ :hostname => 'node.example.com' })
      end

      it_behaves_like 'pacemaker::stonith::fence_ipmilan'
    end
  end
end

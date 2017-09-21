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

  let(:pre_condition) { [
    'class pacemaker::corosync {}',
    'class { "pacemaker::corosync" : }'
  ] }


  shared_examples_for 'pacemaker::stonith::fence_ipmilan' do
    let(:stonith_name) { "stonith-fence_ipmilan-#{title}" }
    context 'with defaults' do
      it {
        is_expected.to contain_package('fence-agents-ipmilan')
        is_expected.to contain_pcmk_stonith("stonith-fence_ipmilan-#{title}").with(
          :ensure           => 'present',
          :pcmk_host_list   => "$(/usr/sbin/crm_node -n)",
          :stonith_type     => 'fence_ipmilan',
	)
      }
    end

    context 'with ensure absent' do
      let(:params) { {
        :ensure => 'absent'
      } }
      it {
        is_expected.to contain_pcmk_stonith("stonith-fence_ipmilan-#{title}").with(
          :ensure           => 'absent',
          :pcmk_host_list   => "$(/usr/sbin/crm_node -n)",
          :stonith_type     => 'fence_ipmilan',
        )
        is_expected.to_not contain_package('fence-agents-ipmilan')
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
        is_expected.to contain_pcmk_stonith("stonith-fence_ipmilan-#{title}").with(
          :ensure           => 'present',
          :pcmk_host_list   => 'pcmk_host_list',
          :stonith_type     => 'fence_ipmilan',
          :pcs_param_string => "auth=\"auth\" ipaddr=\"ipaddr\" ipport=\"ipport\" passwd=\"passwd\" passwd_script=\"passwd_script\" lanplus=\"lanplus\" login=\"login\" action=\"action\" timeout=\"timeout\" cipher=\"cipher\" method=\"method\" power_wait=\"power_wait\" delay=\"delay\" privlvl=\"privlvl\" verbose=\"verbose\"  op monitor interval=60s",
          :tries            => 1,
          :try_sleep        => 5,
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

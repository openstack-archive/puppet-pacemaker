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

describe 'pacemaker::stonith::level', type: :define do

  let(:title) { 'test' }

  let(:pre_condition) { [
    'class pacemaker::corosync {}',
    'class { "pacemaker::corosync" : }'
  ] }


  shared_examples_for 'pacemaker::stonith::level' do
    context 'with ensure absent' do
      let(:params) { {
        :ensure            => 'absent',
        :level             => '1',
        :target            => 'node-foo',
        :stonith_resources => ['ipmi-node-foo','fence-bar'],
        :tries             => 1,
        :try_sleep         => 5,
        :verify_on_create  => false,
      } }
      it {
        is_expected.to contain_pcmk_stonith_level("stonith-level-1-node-foo-ipmi-node-foo_fence-bar").with(
          :ensure            => 'absent',
          :level             => '1',
          :target            => 'node-foo',
          :stonith_resources => ['ipmi-node-foo','fence-bar'],
          :tries             => 1,
          :try_sleep         => 5,
          :verify_on_create  => false,
        )
      }
    end

    context 'with params' do
      let(:params) { {
        :level             => '1',
        :target            => 'node-foo',
        :stonith_resources => ['ipmi-node-foo','fence-bar'],
        :tries             => 1,
        :try_sleep         => 5,
        :verify_on_create  => false,
      } }

      it {
        is_expected.to contain_pcmk_stonith_level("stonith-level-1-node-foo-ipmi-node-foo_fence-bar").with(
          :ensure            => 'present',
          :level             => '1',
          :target            => 'node-foo',
          :stonith_resources => ['ipmi-node-foo','fence-bar'],
          :tries             => 1,
          :try_sleep         => 5,
          :verify_on_create  => false,
        )
      }

    end
  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge({ :hostname => 'node.example.com' })
      end

      it_behaves_like 'pacemaker::stonith::level'
    end
  end
end

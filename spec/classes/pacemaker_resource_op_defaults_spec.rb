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

describe 'pacemaker::resource_op_defaults', type: :class do

  let(:title) { 'foo' }

  shared_examples_for 'pacemaker::resource_op_defaults' do
    context 'with params' do
      let(:params) { {
        :defaults  => { 'timeout_test' => { 'name' => 'timeout', 'value' => '60s', }, },
        :tries     => 10,
        :try_sleep => 20,
      } }
      it { is_expected.to compile.with_all_deps }

      it {
        is_expected.to contain_pcmk_resource_op_default('timeout_test').with(
          :name  => 'timeout',
          :value => '60s',
          :tries     => 10,
          :try_sleep => 20,
        )
      }
    end

  end

  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) do
        facts.merge({ :hostname => 'node.example.com' })
      end

      it_behaves_like 'pacemaker::resource_op_defaults'
    end
  end
end

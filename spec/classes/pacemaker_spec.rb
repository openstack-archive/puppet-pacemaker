require 'spec_helper'

describe 'pacemaker::new', type: :class do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      if facts[:operatingsystem] == 'Ubuntu' and \
        facts[:operatingsystemmajrelease] == '18.04' and \
        facts[:puppetversion].split('.')[0].to_i < 5
        it "is unsuported" do
          skip "Puppet service provider supports Ubuntu 18.04 from version >=5 (got #{facts[:puppetversion]})"
        end
      else
        context 'with default parameters' do
          it { is_expected.to compile.with_all_deps }

          it { is_expected.to contain_class('pacemaker::new::params') }

          it { is_expected.to contain_class('pacemaker::new') }

          it { is_expected.to contain_class('pacemaker::new::firewall') }

          it { is_expected.to contain_class('pacemaker::new::install') }

          it { is_expected.to contain_class('pacemaker::new::setup') }

          it { is_expected.to contain_class('pacemaker::new::service') }
        end
      end
    end
  end
end

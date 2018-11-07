require 'spec_helper'

describe 'pacemaker::new::service', type: :class do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      if facts[:operatingsystem] == 'Ubuntu' \
        and facts[:operatingsystemmajrelease] == '18.04' \
        and facts[:puppetversion].split('.')[0].to_i < 5
        it "is unsuported" do
          skip "Puppet service provider supports Ubuntu 18.04 from version >=5 (got #{facts[:puppetversion]})"
        end
      else
        context 'with default parameters' do
          it { is_expected.to compile.with_all_deps }

          it { is_expected.to contain_class('pacemaker::new::params') }

          it { is_expected.to contain_class('pacemaker::new::service') }

          it { is_expected.to contain_service('corosync') }

          it { is_expected.to contain_service('pacemaker') }

          it { is_expected.to contain_service('pcsd') }
        end

        context 'with service manage disabled' do
          let(:params) do
            {
              :corosync_manage => false,
              :pacemaker_manage => false,
              :pcsd_manage => false,
            }
          end

          it { is_expected.to compile.with_all_deps }

          it { is_expected.to contain_class('pacemaker::new::params') }

          it { is_expected.to contain_class('pacemaker::new::service') }

          it { is_expected.not_to contain_service('corosync') }

          it { is_expected.not_to contain_service('pacemaker') }

          it { is_expected.not_to contain_service('pcsd') }
        end

      end
    end
  end
end

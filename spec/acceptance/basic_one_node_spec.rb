require 'spec_helper_acceptance'

describe 'One node install' do
  context 'Haproxy with ipv4 and ipv6 vip' do
    context 'System resource should be created' do
      it 'should be able to setup a new interface for testing' do
        # https://tickets.puppetlabs.com/browse/BKR-707
        # tag 'infra'
        shell 'ip tuntap add tap0 mode tap'
        shell 'ip addr add 192.168.201.88/24 brd + dev tap0'
        shell 'ip addr add 2001:dead::1/64 dev tap0'
        shell 'ip link set tap0 up'
      end
      describe interface('tap0') do
        it { should have_ipv4_address("192.168.201.88/24") }
        it { should have_ipv6_address("2001:dead::1/64") }
      end
    end

    context "Red-Hat OS family", :if => fact('osfamily').eql?('RedHat') do
      context "Pacemaker's manifest" do
        it_behaves_like 'puppet_apply_success_from_tests', 'basic'

        describe interface('tap0') do
          it { should have_ipv4_address("192.168.201.59/24") }
          it { should have_ipv6_address("2001:dead::28/64") }
        end

        describe process("haproxy") do
          it { should be_running }
        end
      end

      context 'Pacemaker resources should be created' do
        it 'should wait a little for the resources to be seen started' do
          shell 'sleep 10'
        end
        it 'should have find the resources' do
          shell 'pcs resource' do |result|
            expect(result.stdout).to include_regexp([
                                                      /haproxy-clone.*haproxy/,
                                                      /Started: \[ \S+ \]/,
                                                      /ip-192\.168\.201\.59.*Started/,
                                                      /ip-2001\.dead\.\.28.*Started/,
                                                    ])
          end
        end
        it 'should find the constraints' do
          shell 'pcs constraint' do |result|
            expect(result.stdout)
              .to include_regexp(
                    [
                      /stonith-fence_ipmilan-ipmi_fence/,
                      /start ip-192.168.201.59 then start haproxy-clone.*kind:Optional/,
                      /start ip-2001.dead..28 then start haproxy-clone.*kind:Optional/,
                      /ip-192.168.201.59 with haproxy-clone \(score:INFINITY\)/,
                      /ip-2001.dead..28 with haproxy-clone \(score:INFINITY\)/
                    ]
                  )
          end
        end
      end
    end
    context "Debian OS family", :if => fact('osfamily').eql?('Debian') do
      it "should fail on Debian OS family as PCSD isn't packaged" do
        apply_manifest(smoke_test_named('basic'), :expect_failures => true)
      end
    end
  end
end

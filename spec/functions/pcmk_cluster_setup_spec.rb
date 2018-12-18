require 'spec_helper'

describe 'pcmk_cluster_setup' do
  context 'interface' do
    it { is_expected.to run.with_params('n1', [], []).and_raise_error(Puppet::Error, /pcmk_cluster_setup: Got unsupported version input data/) }
    it { is_expected.to run.with_params(123,[], '0.9').and_raise_error(Puppet::Error, /pcmk_cluster_setup: Got unsupported nodes input data/) }
    it { is_expected.to run.with_params('foo', 'bar', '0.9').and_raise_error(Puppet::Error, /pcmk_cluster_setup: Got unsupported addr_list input data/) }
    it { is_expected.to run.with_params('n1 n2 n3', ['1', '2'], '0.9').and_raise_error(Puppet::Error, /pcmk_cluster_setup: node list and addr list should be of the same size when defined and not empty/) }
    it { is_expected.to run.with_params(123,[], '0.10').and_raise_error(Puppet::Error, /pcmk_cluster_setup: Got unsupported nodes input data/) }
    it { is_expected.to run.with_params('foo', 'bar', '0.10').and_raise_error(Puppet::Error, /pcmk_cluster_setup: Got unsupported addr_list input data/) }
    it { is_expected.to run.with_params('n1 n2 n3', ['1', '2'], '0.10').and_raise_error(Puppet::Error, /pcmk_cluster_setup: node list and addr list should be of the same size when defined and not empty/) }
    it { is_expected.to run.with_params('n1 n2 n3', ['1', ['2'], nil], '0.10').and_raise_error(Puppet::Error, /pcmk_cluster_setup: One of the addresses in addr_list is neither a String nor an Array/) }
  end

  it 'returns the original node string when no addresses are specified with pcs 0.10' do
    is_expected.to run.with_params('n1 n2 n3', [], '0.10').and_return('n1 n2 n3')
    is_expected.to run.with_params('n1 n2', [], '0.10').and_return('n1 n2')
    is_expected.to run.with_params('n1', [], '0.10').and_return('n1')
    is_expected.to run.with_params('n1 ', [], '0.10').and_return('n1')
  end

  it 'returns the original node string when no addresses are specified with pcs 0.9' do
    is_expected.to run.with_params('n1 n2 n3', [], '0.9').and_return('n1 n2 n3')
    is_expected.to run.with_params('n1 n2', [], '0.9').and_return('n1 n2')
    is_expected.to run.with_params('n1', [], '0.9').and_return('n1')
    is_expected.to run.with_params('n1 ', [], '0.9').and_return('n1')
  end

  it 'returns the correct cluster setup cmd given both nodes and ip address with pcs 0.10' do
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', ['1.1.1.1', '2.2.2.2', '3.3.3.3'], '0.10').and_return('ctr-0 addr=1.1.1.1 ctr-1 addr=2.2.2.2 ctr-2 addr=3.3.3.3')
    is_expected.to run.with_params('ctr-0 ctr-1', ['1.1.1.1', ['2.2.2.2', '3.3.3.3']], '0.10').and_return('ctr-0 addr=1.1.1.1 ctr-1 addr=2.2.2.2 addr=3.3.3.3')
    is_expected.to run.with_params('ctr-0', [['2.2.2.2', '3.3.3.3', '4.4.4.4']], '0.10').and_return('ctr-0 addr=2.2.2.2 addr=3.3.3.3 addr=4.4.4.4')
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', [['1.1.1.1'], ['2.2.2.2'], '3.3.3.3'], '0.10').and_return('ctr-0 addr=1.1.1.1 ctr-1 addr=2.2.2.2 ctr-2 addr=3.3.3.3')
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', [['1fe80::7ed:a95d:ed26:f5b', 'fe80::7ed:a95d:ed26:f5c', 'fe80::7ed:a95d:ed26:f5d'], ['1.1.1.1', '2.2.2.2'], '3.3.3.3'], '0.10').and_return('ctr-0 addr=1fe80::7ed:a95d:ed26:f5b addr=fe80::7ed:a95d:ed26:f5c addr=fe80::7ed:a95d:ed26:f5d ctr-1 addr=1.1.1.1 addr=2.2.2.2 ctr-2 addr=3.3.3.3')
  end

  it 'returns the correct cluster setup cmd given both nodes and ip address with pcs 0.9' do
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', ['1.1.1.1', '2.2.2.2', '3.3.3.3'], '0.9').and_return('ctr-0 ctr-1 ctr-2')
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', [['1fe80::7ed:a95d:ed26:f5b', 'fe80::7ed:a95d:ed26:f5c', 'fe80::7ed:a95d:ed26:f5d'], ['1.1.1.1', '2.2.2.2'], '3.3.3.3'], '0.9').and_return('ctr-0 ctr-1 ctr-2')
  end
end

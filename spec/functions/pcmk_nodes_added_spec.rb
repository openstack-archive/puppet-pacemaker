require 'spec_helper'

describe 'pcmk_nodes_added' do
  context 'interface' do
    it { is_expected.not_to eq(nil) }
    it { is_expected.to run.with_params(1).and_raise_error(Puppet::Error, /Got unsupported nodes input data/) }
    it { is_expected.to run.with_params('foo', []).and_raise_error(Puppet::Error, /Got unsupported crm_node_list/) }
  end

  it 'returns no added nodes because cluster is not set up' do
    is_expected.to run.with_params('foo', '').and_return([])
    is_expected.to run.with_params('foo bar', '').and_return([])
    is_expected.to run.with_params('', '').and_return([])
  end

  it 'returns added nodes when cluster is fully up' do
    crm_out = "\n3 ctr-2 member\n2 ctr-1 member\n1 ctr-0 member\n"
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', crm_out).and_return([])
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2 ctr-3', crm_out).and_return(['ctr-3'])
    is_expected.to run.with_params('ctr-1 ctr-3 ctr-2', crm_out).and_return(['ctr-3'])
    is_expected.to run.with_params('', crm_out).and_return([])
  end

  it 'returns added nodes when cluster is not fully up' do
    crm_out = "\n3 ctr-2 lost\n2 ctr-1 member\n1 ctr-0 member\n"
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', crm_out).and_return([])
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2 ctr-3', crm_out).and_return(['ctr-3'])
    is_expected.to run.with_params('ctr-1 ctr-3 ctr-2', crm_out).and_return(['ctr-3'])
    is_expected.to run.with_params('', crm_out).and_return([])
  end
end

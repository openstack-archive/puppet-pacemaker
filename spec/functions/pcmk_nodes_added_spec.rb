require 'spec_helper'

shared_examples_for 'pcmk_nodes_added without addrs' do |pcs_version|
  it 'returns no added nodes because cluster is not set up' do
    is_expected.to run.with_params('foo', [], pcs_version, '').and_return([])
    is_expected.to run.with_params('foo bar', [], pcs_version, '').and_return([])
    is_expected.to run.with_params('', [], pcs_version, '').and_return([])
  end

  it 'returns added nodes when cluster is fully up' do
    crm_out = "\n3 ctr-2 member\n2 ctr-1 member\n1 ctr-0 member\n"
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', [], pcs_version, crm_out).and_return([])
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2 ctr-3', [], pcs_version, crm_out).and_return(['ctr-3'])
    is_expected.to run.with_params('ctr-1 ctr-3 ctr-2', [], pcs_version, crm_out).and_return(['ctr-3'])
    is_expected.to run.with_params('', [], pcs_version, crm_out).and_return([])
  end

  it 'returns added nodes when cluster is not fully up' do
    crm_out = "\n3 ctr-2 lost\n2 ctr-1 member\n1 ctr-0 member\n"
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2', [], pcs_version, crm_out).and_return([])
    is_expected.to run.with_params('ctr-0 ctr-1 ctr-2 ctr-3', [], pcs_version, crm_out).and_return(['ctr-3'])
    is_expected.to run.with_params('ctr-1 ctr-3 ctr-2', [], pcs_version, crm_out).and_return(['ctr-3'])
    is_expected.to run.with_params('', [], pcs_version, crm_out).and_return([])
  end
end

describe 'pcmk_nodes_added' do
  context 'interface' do
    it { is_expected.not_to eq(nil) }
    it { is_expected.to run.with_params(1).and_raise_error(Puppet::Error, /Got unsupported nodes input data/) }
    it { is_expected.to run.with_params('foo', 'bar').and_raise_error(Puppet::Error, /Got unsupported addr_list input data/) }
    it { is_expected.to run.with_params('foo bar', ['1.2.3.4']).and_raise_error(Puppet::Error, /should be of the same size/) }
    it { is_expected.to run.with_params('foo', [], '0.9', []).and_raise_error(Puppet::Error, /Got unsupported crm_node_list/) }
  end

  context 'with pcs 0.9' do
    include_examples 'pcmk_nodes_added without addrs', '0.9'
  end

  context 'with pcs 0.10, without addr list' do
    include_examples 'pcmk_nodes_added without addrs', '0.10'
  end

  context 'with pcs 0.10 and addr list' do
    let (:pcs_version) { '0.10' }
    let (:nodes_1) { 'ctr-0' }
    let (:nodes_2) { 'ctr-0 ctr-1' }
    let (:nodes_3) { 'ctr-0 ctr-1 ctr-2' }
    let (:nodes_4) { 'ctr-0 ctr-1 ctr-2 ctr-3' }
    let (:nodes_4_alt) { 'ctr-3 ctr-0 ctr-2 ctr-1' }
    let (:addrs_1) { ['1.2.3.4'] }
    let (:addrs_2) { ['1.2.3.4', ['1.2.3.5', '1.2.3.6']] }
    let (:addrs_3) { ['1.2.3.4', ['1.2.3.5', '1.2.3.6'], '1.2.3.7'] }
    let (:addrs_4) { ['1.2.3.4', ['1.2.3.5', '1.2.3.6'], '1.2.3.7', ['1.2.3.8', '1.2.3.9']] }
    let (:addrs_4_alt) { ['1.2.3.8', '1.2.3.4', '1.2.3.7', ['1.2.3.5', '1.2.3.6']] }

    it 'returns no added nodes because cluster is not set up' do
      is_expected.to run.with_params(nodes_1, addrs_1, pcs_version, '').and_return([])
      is_expected.to run.with_params(nodes_2, addrs_2, pcs_version, '').and_return([])
      is_expected.to run.with_params('', [], pcs_version, '').and_return([])
    end

    it 'returns added nodes when cluster is fully up' do
      crm_out = "\n3 ctr-2 member\n2 ctr-1 member\n1 ctr-0 member\n"
      is_expected.to run.with_params(nodes_3, addrs_3, pcs_version, crm_out).and_return([])
      is_expected.to run.with_params(nodes_4, addrs_4, pcs_version, crm_out).and_return(['ctr-3 addr=1.2.3.8 addr=1.2.3.9'])
      is_expected.to run.with_params(nodes_4_alt, addrs_4_alt, pcs_version, crm_out).and_return(['ctr-3 addr=1.2.3.8'])
      is_expected.to run.with_params('', [], pcs_version, crm_out).and_return([])
    end

    it 'returns multiple added nodes' do
      crm_out = "\n1 ctr-0 member\n"
      is_expected.to run.with_params(nodes_4, addrs_4, pcs_version, crm_out).and_return(['ctr-1 addr=1.2.3.5 addr=1.2.3.6', 'ctr-2 addr=1.2.3.7', 'ctr-3 addr=1.2.3.8 addr=1.2.3.9'])
    end

    it 'returns added nodes when cluster is not fully up' do
      crm_out = "\n3 ctr-2 lost\n2 ctr-1 member\n1 ctr-0 member\n"
      is_expected.to run.with_params(nodes_3, addrs_3, pcs_version, crm_out).and_return([])
      is_expected.to run.with_params(nodes_4, addrs_4, pcs_version, crm_out).and_return(['ctr-3 addr=1.2.3.8 addr=1.2.3.9'])
      is_expected.to run.with_params('', [], pcs_version, crm_out).and_return([])
    end
  end
end

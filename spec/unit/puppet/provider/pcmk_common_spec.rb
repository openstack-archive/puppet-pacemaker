require 'spec_helper'

require_relative '../../../../lib/puppet/provider/pcmk_common'

describe "pcmk_common functions" do
  before(:all) do
    # FIXME: we need to stub this properly not via this hack
    PCMK_TMP_BASE = "/tmp"
    orig_cib = File.join File.dirname(__FILE__), 'cib-orig.xml'
    FileUtils.cp orig_cib, "cib-noop.xml"
    FileUtils.cp orig_cib, "cib-resource.xml"
    FileUtils.cp orig_cib, "cib-bundle.xml"
    FileUtils.cp orig_cib, "cib-noop.xml.orig"
    FileUtils.cp orig_cib, "cib-resource.xml.orig"
    FileUtils.cp orig_cib, "cib-bundle.xml.orig"
  end

  it "pcmk_graph_contain_id? raises proper exception" do
    expect { pcmk_graph_contain_id?('foo', 'bar') }.to raise_error(Errno::ENOENT)
  end

  it "pcs_offline noop update" do
    expect(pcs_offline('resource update ip-172.16.11.97 cidr_netmask=32', 'cib-noop.xml')).to eq ""
    expect(pcs_offline('resource update stonith-fence_ipmilan-stonith-fence-1 passwd=renVamyep3!', 'cib-noop.xml')).to eq ""
  end
  it "pcmk_restart_resource? noop" do
    expect(pcmk_restart_resource?('foo', "cib-noop.xml")).to eq false
    expect(pcmk_restart_resource?('ip-172.16.11.97', "cib-noop.xml")).to eq false
    expect(pcmk_restart_resource?('stonith-fence_ipmilan-stonith-fence-1', "cib-noop.xml")).to eq false
  end
  it "pcs_offline update to resource definition" do
    expect(pcs_offline('resource update ip-172.16.11.97 cidr_netmask=31', 'cib-resource.xml')).to eq ""
    expect(pcs_offline('resource update stonith-fence_ipmilan-stonith-fence-1 passwd=NewPassword', 'cib-resource.xml')).to eq ""
  end
  it "pcmk_restart_resource? vip resource" do
    expect(pcmk_restart_resource?('foo', "cib-resource.xml")).to eq false
    expect(pcmk_restart_resource?('ip-172.16.11.97', "cib-resource.xml")).to eq true
  end
  it "pcmk_restart_resource? stonith resource" do
    expect(pcmk_restart_resource?('foo', "cib-resource.xml")).to eq false
    expect(pcmk_restart_resource?('stonith-fence_ipmilan-stonith-fence-1', "cib-resource.xml")).to eq true
  end

  it "pcs_offline update to bundle definition" do
    # We effectively change the number of replicas from 3 to 2
    expect(pcs_offline('resource delete test_bundle', 'cib-bundle.xml')).not_to eq false
    cmd = 'resource bundle create test_bundle container docker image=docker.io/sdelrio/docker-minimal-nginx '\
          'replicas=2 options="--user=root --log-driver=journald -e KOLLA_CONFIG_STRATEGY=COPY_ALWAYS" '\
          'network=host storage-map id=haproxy-cfg-files source-dir=/var/lib/kolla/config_files/haproxy.json '\
          'target-dir=/var/lib/kolla/config_files/config.json options=ro storage-map id=haproxy-cfg-data '\
          'source-dir=/var/lib/config-data/puppet-generated/haproxy/ target-dir=/var/lib/kolla/config_files/src '\
          'options=ro storage-map id=haproxy-hosts source-dir=/etc/hosts target-dir=/etc/hosts options=ro '\
          'storage-map id=haproxy-localtime source-dir=/etc/localtime target-dir=/etc/localtime options=ro '\
          'storage-map id=haproxy-pki-extracted source-dir=/etc/pki/ca-trust/extracted '\
          'target-dir=/etc/pki/ca-trust/extracted options=ro storage-map id=haproxy-pki-ca-bundle-crt '\
          'source-dir=/etc/pki/tls/certs/ca-bundle.crt target-dir=/etc/pki/tls/certs/ca-bundle.crt options=ro '\
          'storage-map id=haproxy-pki-ca-bundle-trust-crt source-dir=/etc/pki/tls/certs/ca-bundle.trust.crt '\
          'target-dir=/etc/pki/tls/certs/ca-bundle.trust.crt options=ro storage-map id=haproxy-pki-cert '\
          'source-dir=/etc/pki/tls/cert.pem target-dir=/etc/pki/tls/cert.pem options=ro storage-map '\
          'id=haproxy-dev-log source-dir=/dev/log target-dir=/dev/log options=rw'
    expect(pcs_offline(cmd, 'cib-bundle.xml')).to eq ""
  end

  it "pcmk_restart_resource? bundle resource" do
    expect(pcmk_restart_resource?('foo', "cib-bundle.xml", true)).to eq false
    expect(pcmk_restart_resource?('test_bundle', "cib-bundle.xml", true)).to eq true
  end

  context 'when crm_diff is not buggy', if: is_crm_diff_buggy?() == false do
    it "pcmk_restart_resource_ng? noop" do
      expect(pcmk_restart_resource_ng?('foo', "cib-noop.xml")).to eq false
      expect(pcmk_restart_resource_ng?('ip-172.16.11.97', "cib-noop.xml")).to eq false
      expect(pcmk_restart_resource_ng?('stonith-fence_ipmilan-stonith-fence-1', "cib-noop.xml")).to eq false
    end
    it "pcmk_restart_resource_ng? vip resource" do
      expect(pcmk_restart_resource_ng?('foo', "cib-resource.xml")).to eq false
      expect(pcmk_restart_resource_ng?('ip-172.16.11.97', "cib-resource.xml")).to eq true
    end
    it "pcmk_restart_resource_ng? stonith resource" do
      expect(pcmk_restart_resource_ng?('foo', "cib-resource.xml")).to eq false
      expect(pcmk_restart_resource_ng?('stonith-fence_ipmilan-stonith-fence-1', "cib-resource.xml")).to eq true
    end
    it "pcmk_restart_resource_ng? bundle resource" do
      expect(pcmk_restart_resource_ng?('foo', "cib-bundle.xml")).to eq false
      expect(pcmk_restart_resource_ng?('test_bundle', "cib-bundle.xml")).to eq true
    end
  end
end

require 'facter'

if not File.exists?('/.dockerenv')
  Facter.add('pacemaker_node_name') do
    setcode do
      Facter::Core::Execution.exec 'crm_node -n'
    end
  end
end

require 'facter'

# Do not call crm_node -n when running inside a container
if not File.exists?('/.dockerenv') and not File.exists?('/run/.containerenv')
  Facter.add('pacemaker_node_name') do
    setcode do
      Facter::Core::Execution.exec 'crm_node -n'
    end
  end
end

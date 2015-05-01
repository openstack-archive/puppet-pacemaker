Puppet::Type.newtype(:pcmk_resource) do
  @doc = "Base resource definition for a pacemaker resource"

  ensurable

  newparam(:name) do
    desc "A unique name for the resource"
  end
  newparam(:resource_type) do
    desc "the pacemaker type to create"
  end
  newproperty(:op_params) do
    desc "op parameters"
  end
  newproperty(:meta_params) do
    desc "meta parameters"
  end
  newproperty(:resource_params) do
    desc "resource parameters"
  end
  newproperty(:clone_params) do
    desc "clone params"
  end
  newproperty(:group_params) do
    desc "A resource group to put the resource in"
  end
  newproperty(:master_params) do
    desc "set if this is a cloned resource"
  end
end

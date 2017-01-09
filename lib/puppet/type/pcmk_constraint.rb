require 'puppet/parameter/boolean'

Puppet::Type.newtype(:pcmk_constraint) do
    @doc = "Base constraint definition for a pacemaker constraint"

    ensurable

    newparam(:name) do
        desc "A unique name for the constraint"
    end

    newparam(:constraint_type) do
        desc "the pacemaker type to create"
        newvalues(:location, :colocation, :order)
    end
    newparam(:resource) do
        desc "resource list"
        newvalues(/.+/)
    end
    newparam(:location) do
        desc "location"
        newvalues(/.+/)
    end
    newparam(:score) do
        desc "Score"
    end
    newparam(:first_resource) do
        desc "First resource in ordering constraint"
    end
    newparam(:second_resource) do
        desc "Second resource in ordering constraint"
    end
    newparam(:first_action) do
        desc "First action in ordering constraint"
    end
    newparam(:second_action) do
        desc "Second action in ordering constraint"
    end
    newparam(:constraint_params) do
        desc "Constraint parameters in ordering constraint"
    end
    newparam(:master_slave, :boolean => true, :parent => Puppet::Parameter::Boolean) do
        desc "Enable master/slave support with multistage"
    end
end

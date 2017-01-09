require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_constraint).provide(:default) do
    desc 'A base constraint definition for a pacemaker constraint'

    ### overloaded methods
    def create
        resource_resource = @resource[:resource].gsub(':', '.')
        resource_name = @resource[:name].gsub(':', '.')
        resource_location = @resource[:location].gsub(':', '.')
        case @resource[:constraint_type]
        when :location
            cmd = 'constraint location add ' + resource_name + ' '  + resource_resource + ' ' + @resource[:location] + ' ' + @resource[:score]
        when :colocation
            resource_location = @resource[:location].gsub(':', '.')
            if @resource[:master_slave]
              cmd = 'constraint colocation add ' + resource_resource + ' with master ' + resource_location + ' ' + @resource[:score]
            else 
              cmd = 'constraint colocation add ' + resource_resource + ' with ' + resource_location + ' ' + @resource[:score]
            end
        else
            fail(String(@resource[:constraint_type]) + ' is an invalid location type')
        end

        # do pcs create
        pcs('create constraint', resource_name, cmd)
    end

    def destroy
        resource_resource = @resource[:resource].gsub(':', '.')
        resource_name = @resource[:name].gsub(':', '.')
        resource_location = @resource[:location].gsub(':', '.')
        case @resource[:constraint_type]
        when :location
            cmd = 'constraint location remove ' + resource_name
        when :colocation
            cmd = 'constraint colocation remove ' + resource_resource + ' ' + resource_location
        end

        pcs('constraint delete', resource_name, cmd)
    end

    def exists?
        resource_name = @resource[:name].gsub(':', '.')
        resource_resource = @resource[:resource].gsub(':', '.')
        resource_location = @resource[:location].gsub(':', '.')
        cmd = 'constraint ' + String(@resource[:constraint_type]) + ' show --full'
        pcs_out = pcs('show', resource_name, cmd)
        # find the constraint
        for line in pcs_out.lines.each do
            case @resource[:constraint_type]
            when :location
                return true if line.include? resource_name
            when :colocation
                if @resource[:master_slave]
                  return true if line.include? resource_resource + ' with ' + resource_location and line.include? "with-rsc-role:Master"
                else
                  return true if line.include? resource_resource + ' with ' + resource_location
                end
            end
        end
        # return false if constraint not found
        false
    end
end

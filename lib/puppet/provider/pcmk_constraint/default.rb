require_relative '../pcmk_common'

Puppet::Type.type(:pcmk_constraint).provide(:default) do
    desc 'A base constraint definition for a pacemaker constraint'

    ### overloaded methods
    def create
        resource_name = @resource[:name].gsub(':', '.')
        case @resource[:constraint_type]
        when :location
            resource_resource = @resource[:resource].gsub(':', '.')
            resource_location = @resource[:location].gsub(':', '.')
            cmd = 'constraint location add ' + resource_name + ' '  + resource_resource + ' ' + @resource[:location] + ' ' + @resource[:score]
        when :colocation
            resource_resource = @resource[:resource].gsub(':', '.')
            resource_location = @resource[:location].gsub(':', '.')
            if @resource[:master_slave]
              cmd = 'constraint colocation add ' + resource_resource + ' with master ' + resource_location + ' ' + @resource[:score]
            else 
              cmd = 'constraint colocation add ' + resource_resource + ' with ' + resource_location + ' ' + @resource[:score]
            end
        when :order
            first_resource = @resource[:first_resource].gsub(':', '.')
            second_resource = @resource[:second_resource].gsub(':', '.')
            constraint_params = @resource[:constraint_params]
            cmd = 'constraint order ' + @resource[:first_action] + ' ' + first_resource + ' then ' + @resource[:second_action] + ' ' + second_resource
            if not_empty_string(constraint_params)
              cmd += ' ' + constraint_params
            end
        else
            fail(String(@resource[:constraint_type]) + ' is an invalid location type')
        end

        # do pcs create
        pcs('create constraint', resource_name, cmd, @resource[:tries], @resource[:try_sleep])
    end

    def destroy
        resource_name = @resource[:name].gsub(':', '.')
        case @resource[:constraint_type]
        when :location
            cmd = 'constraint location remove ' + resource_name
        when :colocation
            resource_resource = @resource[:resource].gsub(':', '.')
            resource_location = @resource[:location].gsub(':', '.')
            cmd = 'constraint colocation remove ' + resource_resource + ' ' + resource_location
        when :order
            first_resource = @resource[:first_resource].gsub(':', '.')
            second_resource = @resource[:second_resource].gsub(':', '.')
            cmd = 'constraint order remove ' + first_resource + ' ' + second_resource
        end

        pcs('constraint delete', resource_name, cmd, @resource[:tries], @resource[:try_sleep])
    end

    def exists?
        resource_name = @resource[:name].gsub(':', '.')
        cmd = 'constraint ' + String(@resource[:constraint_type]) + ' show --full'
        pcs_out = pcs('show', resource_name, cmd)
        # find the constraint
        for line in pcs_out.lines.each do
            case @resource[:constraint_type]
            when :location
                return true if line.include? resource_name
            when :colocation
                resource_location = @resource[:location].gsub(':', '.')
                resource_resource = @resource[:resource].gsub(':', '.')
                if @resource[:master_slave]
                  # pacemaker 2.1 started returning Promoted instead of Master
                  # so we need to cater to both
                  return true if line =~ /(resource )?'?#{resource_resource}'? with ((Promoted )?resource )?'?#{resource_location}'?/ and line =~ /(with-rsc-role:(Master|Promoted)|Promoted resource)/
                else
                  return true if line =~ /(resource )?'?#{resource_resource}'? with (resource )?'?#{resource_location}'?/
                end
            when :order
                return true if line.include? resource_name
            end
        end
        # return false if constraint not found
        false
    end
end

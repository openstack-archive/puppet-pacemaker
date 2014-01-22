Puppet::Type.type(:pcmk_resource).provide(:default) do
    desc 'A base resource definition for a pacemaker resource'

    ### overloaded methods
    def create
        cmd = 'resource create ' + @resource[:name] + ' ' + @resource[:resource_type] + ' ' + @resource[:resource_params] + ' op monitor interval=' + @resource[:interval]
        # group defaults to empty
        if not @resource[:group].empty?
            cmd += ' --group ' + @resource[:group]
        end
        # clone defaults to false
        if @resource[:clone]
            cmd += ' --clone'
        end
        # do pcs create
        pcs('create', cmd)
    end

    def destroy
        cmd = 'resource delete ' + @resource[:name]
        pcs('delete', cmd)
    end

    def exists?
        cmd = 'resource show ' + @resource[:name] + ' > /dev/null 2>&1'
        pcs('show', cmd)
    end


    ### property methods
    def group
        # get the list of groups and their resources
        cmd = 'resource --groups'
        resource_groups = pcs('group list', cmd)

        # find the group that has the resource in it
        for group in resource_groups.lines.each do
            return group[0, /:/ =~ group] if group.include? @resource[:name]
        end
        # return empty string if a group wasn't found
        ''
    end

    def group=(value)
        if value.empty?
            cmd = 'resource ungroup ' + group + ' ' + @resource[:name]
            pcs('ungroup', cmd)
        else
            cmd = 'resource group add ' + value + ' ' + @resource[:name]
            pcs('group add', cmd)
        end
    end

    def clone
        cmd = 'resource show ' + @resource[:name] + '-clone > /dev/null 2>&1'
        pcs('show clone', cmd) == false ? false : true
    end

    def clone=(value)
        if not value
            cmd = 'resource unclone ' + @resource[:name]
            pcs('unclone', cmd)
        else
            cmd = 'resource clone ' + @resource[:name]
            pcs('clone', cmd)
        end
    end

    private

    def pcs(name, cmd)
        pcs_out = `/usr/sbin/pcs #{cmd}`
        #puts name
        #puts $?.exitstatus
        if $?.exitstatus != 0 and pcs_out.lines.first and not name.include? 'show'
           raise Puppet::Error, "pcs #{name} failed: #{pcs_out.lines.first.chomp!}" if $?.exitstatus
        end
        # return output for good exit or false for failure.
        $?.exitstatus == 0 ? pcs_out : false
    end
end

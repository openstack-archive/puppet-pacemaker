Puppet::Type.type(:pcmk_constraint).provide(:default) do
    desc 'A base constraint definition for a pacemaker constraint'

    ### overloaded methods
    def create
        cmd = 'constraint ' + @resource[:constraint_type] + ' add ' + @resource[:name] + ' '  + @resource[:resource] + ' ' + @resource[:location] + ' ' + @resource[:score]

        # do pcs create
        pcs('create constraint', cmd)
    end

    def destroy
        #cmd = 'constraint delete ' + id + '-' + @resource[:score]
        cmd = 'constraint delete ' + @resource[:name]
        pcs('constraint delete', cmd)
    end

    def exists?
        cmd = 'constraint show --full'
        pcs_out = pcs('show', cmd)

        # find the constraint
        for line in pcs_out.lines.each do
            #return true if line.include? id
            return true if line.include? @resource[:name]
        end
        # return false if constraint not found
        false
    end

    private

    def id()
        @resource[:constraint_type] + '-' + @resource[:resource] + '-' + @resource[:location]
    end

    def pcs(name, cmd)
        pcs_out = `/usr/sbin/pcs #{cmd}`
        #puts name
        #puts $?.exitstatus
        #puts pcs_out
        if $?.exitstatus != 0 and not name.include? 'show'
            if pcs_out.lines.first 
                raise Puppet::Error, "pcs #{name} failed: #{pcs_out.lines.first.chomp!}" if $?.exitstatus
            else
                raise Puppet::Error, "pcs #{name} failed" if $?.exitstatus
            end
        end
        # return output for good exit or false for failure.
        $?.exitstatus == 0 ? pcs_out : false
    end
end

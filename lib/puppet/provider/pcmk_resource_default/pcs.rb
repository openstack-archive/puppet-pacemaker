require_relative '../pcmk_common'

# Currently the implementation is somewhat naive (will not work great
# with ensure => absent, unless the correct current value is also
# specified). For more proper handling, prefetching should be
# implemented and `value` should be switched from a param to a
# property. This should be possible to do without breaking the
# interface of the resource type.
Puppet::Type.type(:pcmk_resource_default).provide(:pcs) do
  desc 'Manages default values for pacemaker resource options via pcs'

  def create
    name = @resource[:name]
    value = @resource[:value]

    cmd = "resource defaults #{name}='#{value}'"

    pcs('create', name, cmd, @resource[:tries], @resource[:try_sleep],
        @resource[:verify_on_create], @resource[:post_success_sleep])
  end

  def destroy
    name = @resource[:name]

    cmd = "resource defaults #{name}="
    pcs('create', name, cmd, @resource[:tries], @resource[:try_sleep],
        @resource[:verify_on_create], @resource[:post_success_sleep])
  end

  def exists?
    name = @resource[:name]
    value = @resource[:value]

    cmd = "resource defaults | grep '^#{name}: #{value}\$'"
    Puppet.debug("defaults exists #{cmd}")
    status = pcs('show', name, cmd, @resource[:tries], @resource[:try_sleep],
                 @resource[:verify_on_create], @resource[:post_success_sleep])
    return status == false ? false : true
  end
end

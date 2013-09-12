# The baseline for module testing used by Puppet Labs is that each manifest
# should have a corresponding test manifest that declares that class or defined
# type.
#
# Tests are then run by using puppet apply --noop (to check for compilation errors
# and view a log of events) or by fully applying the test in a virtual environment
# (to compare the resulting system state to the desired state).
#
# Learn more about module testing here: http://docs.puppetlabs.com/guides/tests_smoke.html
#
include pacemaker

Installs Pacemaker and corosync and creates a cluster
class {"pacemaker::corosync":
    cluster_name => "cluster_name",
    cluster_members => "192.168.122.3 192.168.122.7",
}

### Disable stonith
class {"pacemaker::stonith":
    disable => true,
}

### Add a stonith device
class {"pacemaker::stonith::ipmilan":
    address => "192.168.122.103",
    user => "admin",
    password => "admin",
}

### Add a floating ip
class {"pacemaker::resource::ip":
    ip_address => "192.168.122.203",
}

### Manage a Linux Standard Build service
class {"pacemaker::resource::lsb":
    name => "httpd",
}


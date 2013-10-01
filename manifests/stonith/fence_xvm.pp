# To use this class ensure that fence_virtd is properly configured and running on the hypervisor

class pacemaker::stonith::fence_xvm(
    $name,
    $password,
    $key_file="/etc/cluster/fence_xvm.key",
    $interval="30s",
    $ensure=present)
  inherits pacemaker::corosync {
    if($ensure == absent) {
        exec { "Removing stonith::fence_xvm ${name}":
        command => "/usr/sbin/pcs stonith delete stonith-fence_xvm-${name }",
        onlyif  => "/usr/sbin/pcs stonith show stonith-fence_xvm-${name} > /dev/null 2>&1",
        require => Exec["Start Cluster $cluster_name"],
        }
    } else {
        file { "$key_file":
            content => "$password",
        }

        exec { "Creating stonith::fence_xvm ${name}":
        command => "/usr/sbin/pcs stonith create stonith-fence_xvm-${name} fence_xvm op monitor interval=${interval}",
        unless  => "/usr/sbin/pcs stonith show stonith-fence_xvm-${name} > /dev/null 2>&1",
        require => [Exec["Start Cluster $cluster_name"],Package["pcs"]]
        }
    }
}

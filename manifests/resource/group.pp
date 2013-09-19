define pacemaker::resource::group($resource_id, $resource_group) {
    if($group != nil) {
        exec { "Adding $resource_id to $resource_group":
            command => "/usr/sbin/pcs resource group add ${resource_group} ${resource_id}",
            onlyif  => "/usr/sbin/pcs resource group show ${resource_group} | grep 'Resource: ${resource_group}' > /dev/null 2>&1",
        }
    }
}


define pacemaker::resource::group($resource_id, $resource_group) {
    if($group != '') {
        exec { "Adding $resource_id to $resource_group":
            command => "/usr/sbin/pcs resource group add ${resource_group} ${resource_id}",
            unless => "/usr/sbin/pcs resource show ${resource_group} | grep -q 'Resource: ${resource_id}' > /dev/null 2>&1",
        }
    }
}

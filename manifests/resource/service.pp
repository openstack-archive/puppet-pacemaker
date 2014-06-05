define pacemaker::resource::service($group='',
                                    $clone=false,
                                    $interval='30s',
                                    $ensure='present',
                                    $options='') {

  include ::pacemaker::params
  $res = "pacemaker::resource::${::pacemaker::params::services_manager}"
  create_resources($res,
    { "$name" => { group    => $group,
                  clone    => $clone,
                  interval => $interval,
                  ensure   => $ensure,
                  options  => $options,
                }
    })
}

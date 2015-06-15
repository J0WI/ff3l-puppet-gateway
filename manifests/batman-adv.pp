define ffnord::batman-adv( $mesh_code
                         , $batman_it = 5000
                         ) {
  include ff3l::resources::batman-adv
  include ff3l::firewall

  file {
    "/etc/network/interfaces.d/${mesh_code}-batman":
    ensure => file,
    content => template('ff3l/etc/network/mesh-batman.erb'),
    require => [Package['batctl'],Package['batman-adv-dkms']];
  }

  file_line {
   "root_bashrc_bat${mesh_code}":
     path => '/root/.bashrc',
     line => "alias batctl-${mesh_code}='batctl -m bat-${mesh_code}'"
  }

  ff3l::monitor::zabbix::check_script {
    "${mesh_code}_gwmode":
      mesh_code => $mesh_code,
      scriptname => "batman-gateway-mode-enabled",
      sudo => true;
    "${mesh_code}_maxmetric":
      mesh_code => $mesh_code,
      scriptname => "batman-maximum-gateway-metric",
      sudo => true;
    "${mesh_code}_gwcount":
      mesh_code => $mesh_code,
      scriptname => "batman-visible-gateway-count",
      sudo => true;
  }

  ff3l::firewall::device { "bat-${mesh_code}":
    chain => "bat"
  } 
}



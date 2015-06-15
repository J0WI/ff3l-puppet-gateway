class ffnord::alfred (
  $master = false
) { 
  vcsrepo { '/opt/alfred':
    ensure => present,
    provider => git,
    revision => "dfb1ea4289387bc38d7fc7c51cfa9b0f3439e66f",
    source => "http://git.open-mesh.org/alfred.git";
  }

  file { '/etc/init.d/alfred':
    ensure => file,
    mode => "0755",
    source => "puppet:///modules/ffnord/etc/init.d/alfred";
  }

  file { '/usr/local/bin/alfred-announce':
    ensure => file,
    mode => "0755",
    source => "puppet:///modules/ff3l/usr/local/bin/alfred-announce";
  }

  package { 
    'build-essential':
      ensure => installed;
    'pkg-config':
      ensure => installed;
    'libgps-dev':
      ensure => installed;
    'python3':
      ensure => installed;
    'ethtool':
      ensure => installed;
  }

  exec { 'alfred':
    command => "/usr/bin/make",
    cwd => "/opt/alfred/",
    require => [Vcsrepo['/opt/alfred'],Package['build-essential'],Package['pkg-config'],Package['libgps-dev']];
  }

  service { 'alfred':
    ensure => running,
    hasrestart => true,
    enable => false,
    require => [Exec['alfred'],File['/etc/init.d/alfred']];
   }

  vcsrepo { '/opt/alfred-announce':
    ensure => present,
    provider => git,
    source => "https://github.com/BenJule/ff3l-gateway-alfred.git",
    revision => "816a6fa659f83da3d60e4ce9c88a1f3d4c1499dd",
    require => [Package['python3'],Package['ethtool']];
  }

  cron {
   'update-alfred-announce':
     command => 'PATH=/opt/alfred/:/bin:/usr/bin:/sbin:/usr/sbin/:$PATH /usr/local/bin/alfred-announce',
     user    => root,
     minute  => '*',
     require => [Vcsrepo['/opt/alfred-announce'], Vcsrepo['/opt/alfred'],File['/usr/local/bin/alfred-announce']];
  }
  
  ff3l::firewall::service { 'alfred':
    protos => ["udp"],
    chains => ["mesh","bat"],
    ports => ['16962'],
  }

  if $master {
    ff3l::resources::ffnord::field { "ALFRED_OPTS": value => '-m'; }
  } else {
    ff3l::resources::ffnord::field { "ALFRED_OPTS": value => ''; }
  }
}

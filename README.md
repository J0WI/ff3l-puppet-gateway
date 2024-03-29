# Freifunk Gateway Module

* Martin Schütte <info@mschuette.name>
* Daniel Ehlers <danielehlers@mindeye.net>

This module tries to automate the configuration of a FF3L Freifunk Gateway.
The idea is to implement the step-by-step guide on https://wiki.freifunk-3laendereck.net/Gateways.

Basically this is a complete rewrite of the puppet scripts provided by the
Freifunk Hamburg Community.

The 'ff3l::mesh' block will setup a bridge, fastd, batman, ntp, dhcpd, dns (bind9),
radvd, bird6 and firewall rules vor IPv4 and IPv6.
There are types for setting up monitoring, icvpn, anonymous vpn and alfred announcements.

## Open Problems

* As usual, you should have configure the fully qualified domain name (fqdn) before running
  this module, you can check this with 'hostname -f'.
* The configured dns server only provide support for the root zone.
  Custom tlds are currently not supported.  
* Bird6 must be reconfigured after a puppet run, otherwise the icvpn protocols are not available
* When touching the network devices on a rerun named should be restarted.

## TODO

* Bird IPv4 Route exchange
* Apply firewall rules automatially, when all rules are defined.

## Usage

Install as a puppet module, then include with node-specific parameters.

### Dependencies

Install Puppet and some required modules with:

```
apt-get install --no-install-recommends puppet git
puppet module install puppetlabs-stdlib
puppet module install puppetlabs-apt
puppet module install puppetlabs-vcsrepo
puppet module install saz-sudo
puppet module install torrancew-account
```

Then add this module (which is not in the puppet forge, so it has to be
downloaded manually):

```
cd /etc/puppet/modules
git clone https://github.com/BenJule/ff3l-puppet-gateway ff3l
```

### Parameters

Now include the module in your manifest and provide all parameters.
Basically there is one type for mesh network, which pulls
in all the magic and classes for the icvpn connection, monitoring and
anonymous vpn uplink.

Please make sure that the content of your fastd key-file looks like this:
```
secret "<********>";
```
The stars are replaced by your privat fastd key


Example puppet code (save e.g. as `/root/gateway.pp`):

```
# Global parameters for this host
class { 'ff3l::params':
  router_id => "10.119.0.1", # The id of this router, probably the ipv4 address
                            # of the mesh device of the providing community
  icvpn_as => "65043",      # The as of the providing community
  wan_devices => ['eth0']   # A array of devices which should be in the wan zone

  wmem_default = 87380,     # Define the default socket send buffer
  wmem_max     = 12582912,  # Define the maximum socket send buffer
  rmem_default = 87380,     # Define the default socket recv buffer
  rmem_max     = 12582912,  # Define the maximum socket recv buffer

  max_backlog  = 5000,      # Define the maximum packages in buffer
}

# You can repeat this mesh block for every community you support
ff3l::mesh { 'mesh_ff3l':
      mesh_name    => "Freifunk Dreiländereck e.V.",
      mesh_code    => "ff3l",
      mesh_as      => 65043,
      mesh_mac     => "88:e6:40:20:17:15",
      vpn_mac      => "88:e6:40:20:17:19",
      mesh_ipv6    => "fdc7:3c9d:b889:a272::0/64,
      mesh_ipv4    => "10.119.0.1/19",
      mesh_mtu     => "1426",
      range_ipv4   => "10.119.0.0/16",
      mesh_peerings => "/root/mesh_peerings.yaml",

      fastd_secret => "/root/fastd_secret.key",
      fastd_port   => 10000,
      fastd_peers_git => 'git://somehost/peers.git',

      dhcp_ranges => [ '10.119.2.1 10.119.3.255'
                     , '10.119.4.1 10.119.5.255'
                     , '10.119.6.1 10.119.7.255'
                     , '10.119.8.2 10.119.9.255'
                     ],
      dns_servers => [ '10.119.0.2'
                     , '10.119.0.3'
                     , '10.119.0.4'
                     , '10.119.0.5'
                     ]
      }

ff3l::named::zone {
  'ff3l': zone_git => 'git://somehost/ff3l-zone.git';
}

ff3l::dhcpd::static {
  'ff3l': static_git => 'git://somehost/ff3l-static.git';
}

class {
  'ff3l::vpn::provider::hideio':
    openvpn_server => "nl-7.hide.io",
    openvpn_port   => 3478,
    openvpn_user   => "wayne",
    openvpn_password => "brucessecretpw",
}

ff3l::icvpn::setup {
  'icvpn':
    icvpn_as => 65043,
    icvpn_ipv4_address => "10.119.0.1",
    icvpn_ipv6_address => "2001:bf7:20",
    icvpn_exclude_peerings     => [gotham],
    tinc_keyfile       => "/root/tinc_rsa_key.priv"
}

class {
  'ff3l::monitor::nrpe':
    allowed_hosts => '10.119.0.1'
}

class { 'ff3l::alfred': master => true }

class { 'ff3l::etckeeper': }
```

#### Mesh Type
```
ff3l :: mesh { '<mesh_code>':
  mesh_name,        # Name of your community, e.g.: Freifunk Dreiländereck e.V.
  mesh_code,        # Code of your community, e.g.: ff3l
  mesh_as,          # AS of your community
  mesh_mac,         # mac address mesh device: 88:e6:40:20:17:20
  vpn_mac,          # mac address vpn device, ideally != mesh_mac and unique
  mesh_ipv6,        # ipv6 address of mesh device in cidr notation, e.g. 10.119.0.1/19
  mesh_mtu,         # mtu used, default only suitable for fastd via ipv4
  range_ipv4,       # ipv4 range allocated to community, this might be different to
                    # the one used in the mesh in cidr notation, e.g. 10.119.0.1/19
  mesh_ipv4,        # ipv4 address of mesh device in cidr notation, e.g. fdc7:3c9d:b889:a272::0/64
  mesh_peerings,    # path to the local peerings description yaml file

  fastd_secret,     # fastd secret
  fastd_port,       # fastd port
  fastd_peers_git,  # fastd peers repository

  dhcp_ranges = [], # dhcp pool
  dns_servers = [], # other dns servers in your network
}
```

#### Named Zone Type

This type enables you to receive a zone file from a git repository, include
it into the named configuration and setup a cron job for pulling changes in.
By default the cronjob will pull every 30min. 

The provided configuration should not rely on relative path but use
the absolute path prefixed with '/etc/bind/zones/${name}/'.

```
ff3l::named::zone {
  '<name>':
     zone_git; # zone file repo
}
```

#### DHCPd static type

This type enables you to receive a file with static dhcp assignments from a git repository, include
it into the dhcp configuration and setup a cron job for pulling changes in.
By default the cronjob will pull every 30min.

The provided configuration should not rely on relative path but use
the absolute path prefixed with '/etc/dhcp/statics/${name}/'.
The name should be the same as the community the static assignments belong to.
There has to be a file named static.conf in the repo.

```
ff3l::dhcpd::static {
  '<name>':
     static_git; # dhcp static file repo
}
```

#### ICVPN Type
```
ff3l :: icvpn::setup {
  icvpn_as,            # AS of the community peering
  icvpn_ipv4_address,  # transfer network IPv4 address
  icvpn_ipv6_address,  # transfer network IPv6 address
  icvpn_peerings = [], # Lists of icvpn names

  tinc_keyfile,        # Private Key for tinc
}
```

#### IPv4 Uplink via GRE Tunnel
This is a module for an IPv4 Uplink via GRE tunnel and BGP.
This module and the VPN module are mutually exclusive.
Define the ff3l::uplink::ip class once and ff3l::uplink::tunnel
for each tunnel you want to use. See http://wiki.freifunk.net/Freifunk_Hamburg/IPv4Uplink
for a more detailed description.

```
class {
  'ff3l::uplink::ip':
    nat_network,        # network of IPv4 addresses usable for NAT
    tunnel_network,     # network of tunnel IPs to exclude from NAT
}
ff3l::uplink::tunnel {
    '<name>':
      local_public_ip,  # local public IPv4 of this gateway
      remote_public_ip, # remote public IPv4 of the tunnel endpoint
      local_ipv4,       # tunnel IPv4 on our side
      remote_ip,        # tunnel IPv4 on the remote side
      remote_as,        # ASN of the BGP server announcing a default route for you
}
```

#### Peering description
Be aware that currently the own system mesh address will not be filtered.

```
gw1:
  ipv4: "10.119.0.2"
  ipv6: "fdc7:3c9d:b889:a272::2"
gw2:
  ipv4: "10.119.0.3"
  ipv6: "fdc7:3c9d:b889:a272::3"
gw3:
  ipv4: "10.119.0.4"
  ipv6: "2001:bf7:20::5"
gw4:
  ipv4: "10.119.0.5"
  ipv6: "2001:bf7:20::4"
```

### Run Puppet

To apply the puppet manifest (e.g. saved as `gateway.pp`) run:

```
puppet apply --verbose /root/gateway.pp
build-firewall
```

The verbose flag is optional and shows all changes.
To be even more catious you can also add the `--noop` flag to only show changes
but not apply them.

## Maintenance Mode

To allow administrative operations on a gateway without harming user connections
you should bring the gateway into maintenance mode:

```
maintenance on
```

This will deactivate the gateway feature of batman in the next run of check-gateway.
And after DHCP-Lease-Time there should be no user device with a default route to
the gateway. 

To deactivate maintenance mode and reactivate the batman-adv gateway feature:

```
maintenance off
```

## FASTD Query

For debugging purposes we utilize the status socket of fastd using a little
helper script called `fastd-query`, which itself is a wrapper around ``socat``
and ``jq``. An alias ``fastd-query-${mesh_code}`` is created for every
mesh network. For example you can retrieve the status for some node, where
the node name is equivalent to the peers filename:

```
# fastd-query-ff3l peers name gw0 
```

# respondd Status for Servers

> A gluon compatible status script for respondd in python.


## Dependencies

* lsb_release
* ethtool
* python3 (>= 3.3)
* python3-netifaces
* batman-adv


## Setup

### Debian-Dependencies
```sh
apt-get install python3-netifaces ethtool lsb-release
```

### config.json
Start parameter for ext-respondd.  
Copy `config.json.example` to `config.json` and change it to match your server configuration.

* `"addr"` (`str` / _default:_ `ff05::2:1001`)
  - address to listen to
* `"port"` (`str` / _default:_ `1001`)
  - port to listen to
* `"batman"` (`str` / _default:_ `bat0`)
  - batman-adv interface
* `"bridge"` (`str` / _default:_ `br-client`)
  - client bridge
* `"mesh-wlan"` (`str[]`)
  - ad hoc batman-mesh
* `"mesh-vpn"` (`str[]`)
  - fastd, GRE, L2TP batman-Mesh
* `"fastd_socket"` (`str`)
  - needed for uplink-flag
* `"rate_limit"` (`int` / _default:_ `30`)
  - limit incoming requests per minutes
* `"rate_limit_burst"` (`int` / _default:_ `10`)
  - allow burst requests

### alias.json
Aliases to overwrite the returned server data.  
Copy `alias.json.example` to `alias.json` and input e.g. owner information.

The JSON content matches one block of the nodes.json, which is outputted by e.g. the [HopGlass-Server](https://github.com/hopglass/hopglass-server).

### ext-respondd.service
Register ext-respondd as a systemd service

```sh
cp ext-respondd.service.example /lib/systemd/system/ext-respondd.service
# modify the path inside of the ext-respondd.service if necessary
systemctl daemon-reload
systemctl enable ext-respondd
systemctl start ext-respondd
```

## Related projects

Collecting data from respondd:
* [yanic](https://github.com/FreifunkBremen/yanic) written in Go
* [HopGlass Server](https://github.com/hopglass/hopglass-server) written in Node.js

Respondd for servers:
* [ffho-respondd](https://github.com/FreifunkHochstift/ffho-respondd) from Freifunk Hochstift (fork of ext-respondd)
* [mesh-announce](https://github.com/ffnord/mesh-announce) from Freifunk Nord
* [py-respondd](https://github.com/descilla/py-respondd)

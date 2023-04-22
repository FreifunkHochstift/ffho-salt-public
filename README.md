# Freifunk Hochstift infrastructure - SaltStack configuration

This repository contains the Salt environment (states + modules) used to configure the infrastructure of the
[Freifunk Hochstift](https://ffho.net) community network.

It uses the [NetBox Abstraction and Caching Layer (NACL)](https://github.com/BarbarossaTM/nacl) as its interface to communicate with NetBox, which holds all node specific configuration.
This includes the node name, role(s), interfaces, IP addresses, tags, config contexts, etc.

## Principles

This whole code base follows the principles of [Holistic (network) automation](https://blog.sdn.clinic/2022/01/this-is-the-way-holistic-approach-on-network-automation/), which means that as much configuration bits are derived from properties of nodes or its relationship(s) to other nodes.
This includes but is not limited to, OSPF adjacencies, internal BGP sessions, B.A.T.M.A.N. adv. configuration, Nftables rules, etc.

Most of these bits live inside the Python modules which are included in this repository (see the `_modules/` directory), which contains modules for authentication, netfilter, and networking related configuration.
The `ffho_net` modules currently is the heart of our SDN logic, with more recent pieces (e.g. iBGP mesh calculation) living inside NACL.
Eventually most logic should move over to NACL or another daemon which takes over the SDN role, so that Salt is only used to apply configuration based on a generic device configuration.

## Further Reading

Our CTO, @BarbarossaTM, has started a [blog series](https://blog.sdn.clinic/2017/09/building-your-own-software-defined-network-with-linux-and-open-source-tools/) about our infrastructure, its architecture and evolution and also [blogs about NetBox related things](https://blog.sdn.clinic/category/automation/netbox/), which may or may not be related to this code base - it mostly is though :-)

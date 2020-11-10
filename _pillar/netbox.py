# -*- coding: utf-8 -*-
'''
A module that adds data to the Pillar structure from a NetBox API.

.. versionadded:: 2019.2.0

Configuring the NetBox ext_pillar
---------------------------------

.. code-block:: yaml

  ext_pillar:
    - netbox:
        api_url: http://netbox_url.com/api/
        api_token: 123abc

Create a token in your NetBox instance at
http://netbox_url.com/user/api-tokens/

The following options are optional, and determine whether or not
the module will attempt to configure the ``proxy`` pillar data for
use with the napalm proxy-minion:

.. code-block:: yaml

  proxy_return: True
  proxy_username: admin

By default, this module will query the NetBox API for the platform
associated with the device, and use the 'NAPALM driver' field to
set the napalm proxy-minion driver. (Currently only 'napalm' is supported
for drivertype.)

This module currently only supports the napalm proxy minion and assumes
you will use SSH keys to authenticate to the network device.  If password
authentication is desired, it is recommended to create another ``proxy``
key in pillar_roots (or git_pillar) with just the ``passwd`` key and use
:py:func:`salt.renderers.gpg <salt.renderers.gpg>` to encrypt the value.
If any additional options for the proxy setup are needed they should also be
configured in pillar_roots.

Other available options:

site_details: ``True``
    Whether should retrieve details of the site the device belongs to.

site_prefixes: ``True``
    Whether should retrieve the prefixes of the site the device belongs to.
'''

from __future__ import absolute_import, print_function, unicode_literals
import logging
import six

# Import Salt libs
import salt.utils.http
if six.PY3:
    import ipaddress
else:
    import salt.ext.ipaddress as ipaddress

log = logging.getLogger(__name__)


def ext_pillar(minion_id, pillar, *args, **kwargs):
    '''
    Query NetBox API for minion data
    '''
    if minion_id == '*':
        log.info('There\'s no data to collect from NetBox for the Master')
        return {}
    # Pull settings from kwargs
    api_url = kwargs['api_url'].rstrip('/')
    api_token = kwargs.get('api_token')
    site_details = kwargs.get('site_details', True)
    site_prefixes = kwargs.get('site_prefixes', True)
    proxy_username = kwargs.get('proxy_username', None)
    proxy_return = kwargs.get('proxy_return', True)
    ret = {}

    # Fetch device from API
    headers = {}
    if api_token:
        headers = {
            'Authorization': 'Token {}'.format(api_token)
        }
    device_search_url = '{api_url}/{app}/{endpoint}'.format(api_url=api_url,
                                                     app='dcim',
                                                     endpoint='devices')
    device_search_results = salt.utils.http.query(device_search_url,
                                           params={'name': minion_id},
                                           header_dict=headers,
                                           decode=True)
    search_results = device_search_results
    if len(search_results['dict']['results']) == 0:
        vm_search_url = '{api_url}/{app}/{endpoint}'.format(api_url=api_url,
                                                     app='virtualization',
                                                     endpoint='virtual-machines')
        vm_search_results = salt.utils.http.query(vm_search_url,
                                           params={'name': minion_id},
                                           header_dict=headers,
                                           decode=True)
        search_results = vm_search_results
    # Check status code for API call
    if 'error' in search_results:
        log.error('API query failed for "%s", status code: %d',
                  minion_id, search_results['status'])
        log.error(search_results['error'])
        return ret
    # Assign results from API call to "netbox" key
    if len(search_results['dict']['results']) == 0:
        log.error('No device found for "%s"', minion_id)
        return ret
    if len(search_results['dict']['results']) > 1:
        log.error('More than one device found for "%s"', minion_id)
        return ret
    if 'vcpus' not in search_results['dict']['results'][0]:
        device_url = '{api_url}/{app}/{endpoint}/{id}/'.format(api_url=api_url,
                                                app='dcim',
                                                endpoint='devices',
                                                id=search_results['dict']['results'][0]['id'])
        device_results = salt.utils.http.query(device_url,
                                      header_dict=headers,
                                      decode=True)

    else:
        device_url = '{api_url}/{app}/{endpoint}/{id}/'.format(api_url=api_url,
                                                app='virtualization',
                                                endpoint='virtual-machines',
                                                id=search_results['dict']['results'][0]['id'])
        device_results = salt.utils.http.query(device_url,
                                      header_dict=headers,
                                      decode=True)

    if 'error' in device_results:
        log.error('API query failed for "%s", status code: %d',
                  minion_id, search_results['status'])
        log.error(search_results['error'])
        return ret

    ret['netbox'] = device_results['dict']
    site_id = 0
    site_name = ""
    if not ret['netbox']['site']:
        # eg virtual maschine in multi-site cluster
        site_details = False
        site_prefixes = False
    else:
        site_id = ret['netbox']['site']['id']
        site_name = ret['netbox']['site']['name']
    service_url = '{api_url}/{app}/{endpoint}'.format(api_url=api_url,
                                                      app='ipam',
                                                      endpoint='services')
    service_results = salt.utils.http.query(service_url,
                                           header_dict=headers,
                                           decode=True)
    services = service_results['dict']['results']
    if len(services) >= 1:
       ret['netbox']['services'] = {}
       for service in services:
          ret['netbox']['services'][service['name']] = service

    query_param = 'device_id'
    app = 'dcim'
    if 'vcpus' in ret['netbox']:
        app = 'virtualization'
        query_param = 'virtual_machine_id'
    
    ret['netbox']['interfaces'] = {}
    interface_url = '{api_url}/{app}/{endpoint}/'.format(api_url=api_url,
                                                                app=app,
                                                                endpoint='interfaces')

    interface_results = salt.utils.http.query(interface_url,
                                        params={query_param: search_results['dict']['results'][0]['id'], 'limit': 1000 },
                                        header_dict=headers,
                                        decode=True)
    if 'error' in interface_results:
                log.error('API query failed for "%s", status code: %d',
                                minion_id, interface_results['status'])
                log.error(interface_results['error'])
                return ret
    else:
                for interface in interface_results['dict']['results']:
                    ret['netbox']['interfaces'][interface['name']] = interface
                    ret['netbox']['interfaces'][interface['name']]['ipaddresses'] = []

    if 'vcpus' in ret['netbox']:
      query_param = 'virtual_machine_id'
    ipaddress_url = '{api_url}/{app}/{endpoint}/'.format(api_url=api_url,
                                                                  app='ipam',
                                                                  endpoint='ip-addresses')
    ipaddress_results = salt.utils.http.query(ipaddress_url,
                                           params={query_param: search_results['dict']['results'][0]['id'] },
                                           header_dict=headers,
                                           decode=True)
    if 'error' in ipaddress_results:
        log.error('API query failed for "%s", status code: %d',
                  minion_id, ipaddress_results['status'])
        log.error(ipaddress_results['error'])
        return ret
    ipaddresses = ipaddress_results['dict']['results']
    ## Get all interfaces for device
    interface_ids = []
    for ipaddress in ipaddresses:
        interface_id = ipaddress['assigned_object_id']
        app = 'dcim'
        if 'vcpus' in ret['netbox']:
            app = 'virtualization'
        interface_url = '{api_url}/{app}/{endpoint}/{id}/'.format(api_url=api_url,
                                                                  app=app,
                                                                  endpoint='interfaces',
                                                                  id=interface_id)
        interface_results = salt.utils.http.query(interface_url,
                                           header_dict=headers,
                                           decode=True)
        if 'error' in interface_results:
                log.error('API query failed for "%s", status code: %d',
                                minion_id, interface_results['status'])
                log.error(interface_results['error'])
                return ret
        if interface_results['dict']['name'] not in ret['netbox']['interfaces']:
            ret['netbox']['interfaces'][interface_results['dict']['name']] = interface_results['dict']
        if 'ipaddresses' not in ret['netbox']['interfaces'][interface_results['dict']['name']]:
            ret['netbox']['interfaces'][interface_results['dict']['name']]['ipaddresses'] = []
        ret['netbox']['interfaces'][interface_results['dict']['name']]['ipaddresses'].append(ipaddress)

    if site_details:
        log.debug('Retrieving site details for "%s" - site %s (ID %d)',
                  minion_id, site_name, site_id)
        site_url = '{api_url}/{app}/{endpoint}/{site_id}/'.format(api_url=api_url,
                                                                  app='dcim',
                                                                  endpoint='sites',
                                                                  site_id=site_id)
        site_details_ret = salt.utils.http.query(site_url,
                                                 header_dict=headers,
                                                 decode=True)
        if 'error' in site_details_ret:
            log.error('Unable to retrieve site details for %s (ID %d)',
                      site_name, site_id)
            log.error('Status code: %d, error: %s',
                      site_details_ret['status'],
                      site_details_ret['error'])
        else:
            ret['netbox']['site'] = site_details_ret['dict']
    if site_prefixes:
        log.debug('Retrieving site prefixes for "%s" - site %s (ID %d)',
                  minion_id, site_name, site_id)
        prefixes_url = '{api_url}/{app}/{endpoint}'.format(api_url=api_url,
                                                           app='ipam',
                                                           endpoint='prefixes')
        site_prefixes_ret = salt.utils.http.query(prefixes_url,
                                                  params={'site_id': site_id},
                                                  header_dict=headers,
                                                  decode=True)
        if 'error' in site_prefixes_ret:
            log.error('Unable to retrieve site prefixes for %s (ID %d)',
                      site_name, site_id)
            log.error('Status code: %d, error: %s',
                      site_prefixes_ret['status'],
                      site_prefixes_ret['error'])
        else:
            ret['netbox']['site']['prefixes'] = site_prefixes_ret['dict']['results']
    if proxy_return:
        # Attempt to add "proxy" key, based on platform API call
        try:
            # Fetch device from API
            platform_results = salt.utils.http.query(ret['netbox']['platform']['url'],
                                                     header_dict=headers,
                                                     decode=True)
            # Check status code for API call
            if 'error' in platform_results:
                log.info('API query failed for "%s": %s',
                         minion_id, platform_results['error'])
            # Assign results from API call to "proxy" key if the platform has a
            # napalm_driver defined.
            napalm_driver = platform_results['dict'].get('napalm_driver')
            if napalm_driver:
                ret['proxy'] = {
                    'host': str(ipaddress.IPv4Interface(
                                ret['netbox']['primary_ip4']['address']).ip),
                    'driver': napalm_driver,
                    'proxytype': 'napalm',
                }
                if proxy_username:
                    ret['proxy']['username'] = proxy_username

        except Exception:
            log.debug(
                'Could not create proxy config data for "%s"', minion_id)

    return ret

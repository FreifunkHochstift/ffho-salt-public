#!/usr/bin/python
#
# Annika Wickert <aw@awlnx.space>
#  --  Wed 03 April 2019
#
__virtualname__ = "cfssl_certs"
try:
    import requests

    IMPORT_WORKED = True
except ImportError:
    IMPORT_WORKED = False


def __virtual__():
    if IMPORT_WORKED:
        return "cfssl_certs"
    else:
        return (
            False,
            "The cfssl_certs execution module cannot be loaded: requests unavailable.",
        )


def request_cert(ca_url, certname):
    cert_req = (
        '{ "request": {"CN": "%s","hosts":["%s"],"key": { "algo": "rsa","size": 2048 }, "names": [{"C":"DE","ST":"Bavaria", "L":"Munich","O":"FFMUC"}]}}'
        % (certname, certname)
    )
    print(cert_req)
    headers = {"Content-type": "application/json"}
    r = requests.post(ca_url + "/api/v1/cfssl/newcert", data=cert_req, headers=headers)
    try:
        cert_bundle = r.json()
        return cert_bundle["result"]
    except Exception as e:
        return False

#
# LDAP auth for OpenVPN (Salt managed)
#
auth		sufficient	pam_ldap.so
auth		required	pam_deny.so

account		sufficient	pam_ldap.so
account		required	pam_deny.so

session		required	pam_deny.so

password	required	pam_deny.so

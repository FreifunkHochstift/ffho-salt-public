#
# Linux Kernel
#

linux-kernel:
  pkg.latest:
    - name: linux-image-{{ grains.osarch }}

# On buster we go for the Kernel from backports (current 5.10.x)
# as it includes B.A.T.M.A.N. hop-penalty per interface
{% if grains.oscodename == 'buster' %}
    - fromrepo: buster-backports
{% endif %}

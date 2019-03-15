#
# Jenkins
#
jenkins:
  pkgrepo.managed:
    - comments:
      - "# Jenkins APT repo"
    - human_name: Jenkins repository
    - name: deb https://pkg.jenkins.io/debian binary/ 
    - clean_file: True
    - dist: binary/
    - file: /etc/apt/sources.list.d/pkg_jenkins_io_debian.list
    - key_url: https://pkg.jenkins.io/debian/jenkins.io.key
    - require_in:
      - pkg: jenkins

  pkg.latest:
    - name: jenkins


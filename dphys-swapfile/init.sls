{% if grains.osfullname in 'Raspbian' %}
dphys-swapfile-config:
  file.managed:
    - name: /etc/dphys-swapfile
    - source: salt://dphys-swapfile/dphys-swapfile

dphys-swapfile-service:
  service.running:
    - name: dphys-swapfile
    - enable: true
    - watch:
      - file: dphys-swapfile-config 
{% endif %}

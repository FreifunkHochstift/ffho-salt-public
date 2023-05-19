# Grafana-Piechart-Panel
grafana-piechart:
  cmd.run:
    - name: grafana-cli plugins install grafana-piechart-panel
    - creates: /var/lib/grafana/plugins/grafana-piechart-panel
    - watch_in:
      - service: grafana

grafana-imagerenderer-deps:
  pkg.installed:
    - pkgs:
      - libxdamage1
      - libxext6
      - libxi6
      - libxtst6
      - libnss3
      - libnss3
      - libcups2
      - libxss1
      - libxrandr2
      - libasound2
      - libatk1.0-0
      - libatk-bridge2.0-0
      - libpangocairo-1.0-0
      - libpango-1.0-0
      - libcairo2
      - libatspi2.0-0
      - libgtk3.0-cil
      - libgdk3.0-cil
      - libx11-xcb-dev

grafana-imagerenderer:
  cmd.run:
    - name: grafana-cli plugins install grafana-image-renderer
    - creates: /var/lib/grafana/plugins/grafana-image-renderer
    - watch_in:
      - service: grafana
    - require:
      - pkg: grafana-imagerenderer-deps

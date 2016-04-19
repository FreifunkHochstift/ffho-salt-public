#
# Screen
#

screen:
  pkg.installed:
    - name: screen

/root/.screenrc:
  file.managed:
    - source: salt://screen/screenrc.root

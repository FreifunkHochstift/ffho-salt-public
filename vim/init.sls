#
# Vim magic
#

vim:
  pkg.installed:
    - name: vim

/root/.vimrc:
  file.managed:
    - source: salt://vim/vimrc

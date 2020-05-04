#
# Vim magic
#

vim:
  pkg.installed:
    - name: vim

/etc/vim/vimrc.local:
  file.managed:
    - source: salt://vim/vimrc.local

/root/.vimrc:
  file.managed:
    - source: salt://vim/vimrc

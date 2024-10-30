# bodycount
Reference photo app for gesture drawing in Linux

## Debian and similar distros
Bodycount relies on external packages:
* tk8.6
* xserver-xorg
* gnome-icon-theme
* imagemagick
* avahi-tools
* samba-client
* xdg-utils

This is alpha software. Until the first release, run 'wish' from a terminal inside the
bodycount directory:

#### $ wish gesture.tcl

Written in TCL/TK - because it's fun. Every effort has been made to craft
a contemporary user interface, but TK widgets were created decades ago, so
there are rough edges. On the plus side, Bodycount is themeable!

Upon application startup, choose a folder of reference images and the
Draw button will become available. It looks like a pencil.

Significant time went into implementing network file discovery with Avahi
and Samba. All Samba shares should be listed in the folder browser, so long
as you have DNS-SD running on your file servers. Yes, it's easy to map a
file share to a local folder in Linux with cifs. But that requires some
fiddling. More art! Less fiddling!

TODO: better icons! better themes! custom time limit! OpenGL canvas for
better image handling (... not likely)!

Please report bugs or contribute!

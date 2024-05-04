**Work in progress**

Pointers
--------

### Systemd

https://www.linuxfromscratch.org/lfs/view/stable-systemd/

### Raspberry Pi

https://www.raspberrypi.com/documentation/computers/processors.html
http://www.dettus.net/detLFS/
https://www.linux-magazine.com/Issues/2021/245/detLFS
https://blog.jgosmann.de/posts/2021/02/07/a-guide-to-crosscompiling-applications/


Caveats
-------

In ash/dash, pipes such as A | B do not fail if A fails.
There is no `set -o pipefail` like in Bash.

Code that deals with such failures becomes arcane.
So such failures are not gracefully handled.

Compilation on macOS
--------------------

To work in a case-sensitive filesystem (is this needed?):

    hdiutil create -size 8g -fs 'Case-sensitive APFS' -type SPARSE -volname LFS lfs
    open lfs.sparseimage
    cd /Volumes/LFS

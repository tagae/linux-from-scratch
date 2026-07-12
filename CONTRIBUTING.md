Project structure
-----------------

* `lfs` is the frontend command.
* `lib` contains the LFS command implementations.
* `package` contains definitions for software bundles that can be installed on the LFS system.

Pointers
--------

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

# Boots the image under QEMU exactly as `./lfs qemu` does, logs in as root, and leaves the shell ready
# for input. Source it at the top level of an expect script, from the repo root. It reads the
# environment that qemu-check sets: LFS_PROFILE, IMAGE_COPY (the image to boot), LFS_QEMU_EXTRA (more
# QEMU arguments, read by `lfs qemu`), TIMEOUT (seconds, default 400) and LFS_ROOT_PASSWORD (root's
# password as the image was built with it, root by default).

set timeout [expr {[info exists env(TIMEOUT)] ? $env(TIMEOUT) : 400}]
log_user 1
spawn -noecho ./lfs qemu $env(IMAGE_COPY)
expect {
    "login:" { }
    timeout { puts "FAIL: no login prompt"; exit 1 }
    eof { puts "FAIL: QEMU exited before the login prompt"; exit 1 }
}
set password [expr {[info exists env(LFS_ROOT_PASSWORD)] && $env(LFS_ROOT_PASSWORD) ne "" ? $env(LFS_ROOT_PASSWORD) : "root"}]
send "root\r"
expect {
    "Password:" { send "$password\r" }
    -re {[#$] $} { }
    timeout { puts "FAIL: no password prompt"; exit 1 }
}
# What is typed while the login completes is not lost, but the shell needs a moment before the first
# command.
sleep 4

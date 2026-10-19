# Boots the image under QEMU exactly as `./lfs qemu` does, logs in as root, and leaves the shell ready
# for input. Source it at the top level of an expect script, from the repo root. It reads the
# environment that qemu-check sets: SYSTEM_KEY, IMAGE_COPY (the image to boot), QEMU_EXTRA (more QEMU
# arguments, read by `lfs qemu`) and TIMEOUT (seconds, default 400).

set timeout [expr {[info exists env(TIMEOUT)] ? $env(TIMEOUT) : 400}]
log_user 1
spawn -noecho ./lfs qemu $env(IMAGE_COPY)
expect {
    "login:" { }
    timeout { puts "FAIL: no login prompt"; exit 1 }
    eof { puts "FAIL: QEMU exited before the login prompt"; exit 1 }
}
send "root\r"
expect {
    "Password:" { send "root\r" }
    -re {[#$] $} { }
    timeout { puts "FAIL: no password prompt"; exit 1 }
}
# What is typed while the login completes is not lost, but the shell needs a moment before the first
# command.
sleep 4

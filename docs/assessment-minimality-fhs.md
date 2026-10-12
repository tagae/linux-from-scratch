# Built systems: minimality and FHS 3.0, remaining work

Open items from the minimality and FHS 3.0 assessment of 2026-10-11, for the `virt` (aarch64),
`amd64` (x86-64) and `pi0` (armv6) `systemd-gnu` systems. Completed items were removed on
2026-10-12. The state described below was checked on the current install trees.

Documentation is not part of the product: systems ship none. Everything is judged against what these
systems run: a serial-console systemd appliance with no network, no D-Bus and no PAM, running a
minimal kernel.

| # | What | State today | Options |
|---|---|---|---|
| B4 | Five sysctl warnings at every boot | `kernel/sysrq`, `kernel/core_uses_pid`, and `net/ipv4/conf/default/{rp_filter,promote_secondaries,accept_source_route}` can't be written. They come from systemd's `50-default.conf`, for kernel features these kernels lack (magic SysRq, core dumps, IPv4) | Accept them, or enable `MAGIC_SYSRQ`, `COREDUMP` and `INET` in the kernels (IPv4 means the TCP/IP stack). Masking the file isn't an option: it also holds the `fs.protected_*` settings |
| M3 | `findmnt` and `mkswap` are missing | util-linux is down to 16 programs, but administrators want these two. They have no `--enable` switch, so `all_programs=no` drops them | Leave `all_programs` on and disable every other program one by one (a long list to maintain), or accept the loss |
| F1 | No btrfs tools in the system | The root file system is btrfs, but there is no `btrfs`, `mkfs.btrfs` or `fsck.btrfs` in the system (btrfs-progs is only a build tool). FHS lists `fsck.<type>` among the optional `/sbin` commands | Add btrfs-progs to the system build, by need |

B4 and M3 need a decision on what to accept, and F1 a decision on adding btrfs-progs to the system.

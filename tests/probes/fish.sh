# tests/probes/fish.sh -- proves the optional fish package (fish.sh:
# fish 4.x, Rust, cross-compiled against our glibc with the bundled
# static PCRE2; installed on demand with `./lfs install fish`) actually
# RUNS on a live guest: the binary starts (its glibc link resolves and
# the Rust runtime comes up), its regex builtin works (`string match -r`
# is the bundled PCRE2 engine), and it can launch an external command.
# Stage-1 artifact checks can prove the files landed on disk, never that
# they run.
#
# PROBE_KEY is the plain default key: fish merges into the
# systemd-busybox-virt tree, so this probe rides the standard image once
# `./lfs install fish` + a fresh `./lfs image build` have run. On a tree
# where fish was never installed the image still exists, so this reports
# an honest failure rather than a SKIP -- fitting, since the probe only
# exists because the fish package does.
PROBE_KEY=systemd-busybox-virt
PROBE_TIMEOUT=120

probe_guest() {
    # Joined into one line by printf (same shape as network.sh): each
    # piece single-quoted, so nothing is host-shell-expanded before it
    # reaches the guest.
    printf '%s && %s && %s' \
        'fish --version' \
        '[ "$(fish -c "string match -r f.sh fish")" = fish ]' \
        '[ "$(fish -c "uname")" = Linux ] && echo PROBE_OK_fish'
}

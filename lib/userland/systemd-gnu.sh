# systemd init with a GNU userland

_TODO() {
    # Base layout and merged-usr symlinks.
    require system-files

    # CA trust store.
    require ca-certificates

    (
        if [ -d "$TOOL_DIR/usr/share/bison" ]; then
            export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison
        fi
        if [ -d "$TOOL_DIR/$target/usr/include" ]; then
            headers=$TOOL_DIR/$target/usr/include
        fi
        require glibc
    )

    # Capabilities.
    require libcap

    # Kernel module loading.
    manpages=no require kmod

    # Shell and core utilities (GNU userland).
    require bash
    require coreutils
    require grep
    require sed
    require gawk

    # Login chain: shadow's login/passwd need crypt(3) and readpassphrase(3) (libbsd, which needs libmd).
    require libxcrypt
    require libmd
    require libbsd
    libbsd=yes require shadow

    # Core userspace utilities (agetty, mount, login, …).
    (
        if has_cap loop; then
            fdisks=yes
            widec=yes shared=yes normal=yes ada=no debug=no stripping=no require ncurses
        fi
        bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
        chfn_chsh=no login=no nologin=yes su=no setpriv=no runuser=no
        pylibmount=no static=no liblastlog2=no python=no systemd=no wall=no
        makeinstall_chown=no makeinstall_setuid=no
        losetup=yes fallocate=yes mountpoint=yes mount=yes fdisks=${fdisks:-}
        require util-linux
    )

    # Init system.
    sysroot=$INSTALL_DIR/$SYSTEM_KEY require systemd

    # Opt-in capabilities.
    if has_cap network; then require network-config; fi
    if has_cap 9p; then require 9p-config; fi
    # amnesia-config reverses part of systemd.sh's own install()-time
    # tmp.mount mask (same "must come after" reasoning as network-config
    # above), so it has to run after that masking exists to reverse.
    if has_cap amnesia; then require amnesia-config; fi

    # Kernel image, DTBs and modules. BISON_PKGDATADIR: the kernel's kconfig
    # parser generation (allnoconfig/olddefconfig, in linux.sh's prepare())
    # shells out to bison, whose compiled-in default pkgdatadir is the
    # literal /usr/share/bison — this container's empty real root, not
    # TOOL_DIR-relative (same fixup as glibc above; see there, including why
    # this is guarded the same way for the guest).
    (
        if [ -d "$TOOL_DIR/usr/share/bison" ]; then
            export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison
        fi
        require linux
    )

    # Boot partition files (cmdline.txt + config.txt) — Pi platforms only.
    # Also the GPU/bootloader firmware (bootcode.bin/start.elf/fixup.dat +
    # overlays — package/firmware.sh): real Pi hardware's boot ROM can't
    # start the kernel without these on the FAT partition, but QEMU never
    # reads them (it loads -kernel/-dtb directly), so pulling this in here
    # is regression-neutral for every existing QEMU-only Pi boot.
    if [ -n "${DTB:-}" ]; then
        require boot#cmdline
        require boot#config
        require firmware
    fi
}

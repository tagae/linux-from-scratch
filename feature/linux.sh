# The Linux kernel, chapter 10 of the book, with its modules and the platform's device tree,
# configured from the layers that every system gets (package/linux/) and from the fragments that the
# system's features name. Every platform requires it.

# The kernel is archived under the fragments that configure it, so that systems with the same ones
# share it, whatever their features.
for fragment in $linux_fragments; do
    package_key=$package_key+$fragment
done

( fragments=$linux_fragments; lfs_system_install linux )

# QEMU runs on the host, which cannot see the install tree (a Docker volume), but sees
# WORK_DIR/boot.
rm -rf $WORK_DIR/boot/$SYSTEM_KEY
mkdir -pv $WORK_DIR/boot/$SYSTEM_KEY
(
    cd $system_dir/boot
    cp -v kernel.img ${dev_tree_blob:+${dev_tree_blob##*/}} $WORK_DIR/boot/$SYSTEM_KEY/
)

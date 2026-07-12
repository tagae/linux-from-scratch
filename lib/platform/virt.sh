case "$(uname -m)" in
    arm64|aarch64) # Varies according to OS.
        readonly ARCH=arm64
        readonly target=aarch64-${vendor:-scratch}-linux-gnu
        readonly QEMU=qemu-system-aarch64
        ;;
    *) bail "Unsupported virt architecture" ;;
esac

# -cpu host requires a hardware accelerator to pass the host CPU through;
# without one, QEMU defaults to TCG (software emulation), which rejects
# "host" outright. HVF is macOS's accelerator (Apple Silicon aarch64 host,
# matching this aarch64 guest); anywhere else, fall back to plain TCG with
# "max" (the equivalent stand-in — full feature set, but software-only).
case "$(uname -s)" in
    Darwin) readonly QEMU_ACCEL="-accel hvf -cpu host" ;;
    *)      readonly QEMU_ACCEL="-cpu max" ;;
esac

readonly QEMU_FLAGS="\
    -M virt $QEMU_ACCEL -smp 1 -m 512 \
    -nographic \
    -device virtio-rng \
    -device virtio-serial \
    -chardev stdio,signal=off,mux=on,id=char0 \
    -device virtconsole,chardev=char0,id=console0 \
    -mon chardev=char0,mode=readline"

# Kernel command line fragment specific to this platform (combined with the
# filesystem-related fragment in `lfs`'s qemu case under a single -append).
readonly QEMU_APPEND="console=hvc0 root=/dev/vda1"

readonly QEMU_DISK_IF=virtio

# Single btrfs partition — no FAT boot partition (QEMU loads kernel directly)
readonly IMAGE_LAYOUT=single

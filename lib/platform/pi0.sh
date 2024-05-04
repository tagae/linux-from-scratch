readonly ARCH=arm

readonly target=arm-${vendor:-scratch}-linux-gnueabihf

# https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html
readonly arch=armv6
readonly float=hard
readonly fpu=vfp # equivalently, vfpv2
readonly tune=arm1176jzf-s

readonly kernel=kernel7

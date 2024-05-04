readonly ARCH=arm

readonly target=arm-${vendor:-scratch}-linux-gnueabihf

# https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html
readonly arch=armv6kz
readonly tune=arm1176jzf-s
readonly abi=aapcs-linux
readonly fpu=vfpv2
readonly float=hard

readonly kernel=kernel7

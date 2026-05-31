Linux From Scratch
==================

Define the platform you wish to target:

```shell
export PLATFORM=pi0
```

Jump into an Alpine Linux shell:

```shell
make alpine-sh
```

Build the cross-compilation toolchain:

```shell
./lfs tools
```

Install packages:

```shell
./lfs install -d install system-files linux boot#cmdline
```

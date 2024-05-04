.PHONY: default clean distclean pristine

default:
	./lfs tools pi0

clean:
	git clean -dxf work

distclean: clean
	git clean -dxf tools sysroot

pristine:
	rm -rf source/linux-*
	git clean -dxf

image/%.img:
	./lfs image $*

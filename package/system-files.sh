: ${package_version:=0.0.1}

install() {
    cd $package_install_dir

    mkdir -pv boot dev etc proc root run sys tmp var/log
    chmod -v go= root
    chmod -v ugo=rwx,+t tmp

    ln -fsv /proc/self/mounts etc/mtab

    cp -rv $package_files_dir/* .

    touch var/log/btmp var/log/lastlog var/log/faillog var/log/wtmp
    chgrp -v 13 var/log/lastlog # 13 is utmp, see etc/groups
    chmod -v ug=rw,o=r  var/log/lastlog
    chmod -v u=rw,go= var/log/btmp
}

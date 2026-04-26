#!/bin/bash
set +e
LOG=/sources/build.log
exec > >(tee -a $LOG) 2>&1

echo "=== Build Started: $(date) ==="

# Function to handle errors
handle_error() {
    echo "❌ ERROR in $CURRENT_PKG at line $1"
    echo "Check $LOG for details"
    exit 1
}
trap "" ERR

build_pkg() {
    CURRENT_PKG=$1
    echo ""
    echo "⏳ [$CURRENT_PKG] Starting..."
}

# BZIP2
build_pkg "bzip2"
cd /sources && tar -xf bzip2-1.0.8.tar.gz && cd bzip2-1.0.8
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so && make clean && make
make PREFIX=/usr install
cp -av libbz2.so.* /usr/lib
ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do ln -sfv bzip2 $i; done
rm -fv /usr/lib/libbz2.a
cd /sources && rm -rf bzip2-1.0.8
echo "✅ bzip2 done"

# XZ
build_pkg "xz"
cd /sources && tar -xf xz-5.8.1.tar.xz && cd xz-5.8.1
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/xz-5.8.1
make && make install
cd /sources && rm -rf xz-5.8.1
echo "✅ xz done"

# LZ4
build_pkg "lz4"
cd /sources && tar -xf lz4-1.10.0.tar.gz && cd lz4-1.10.0
make BUILD_STATIC=no PREFIX=/usr
make BUILD_STATIC=no PREFIX=/usr install
cd /sources && rm -rf lz4-1.10.0
echo "✅ lz4 done"

# ZSTD
build_pkg "zstd"
cd /sources && tar -xf zstd-1.5.7.tar.gz && cd zstd-1.5.7
make prefix=/usr
make prefix=/usr install
rm -v /usr/lib/libzstd.a
cd /sources && rm -rf zstd-1.5.7
echo "✅ zstd done"

# FILE
build_pkg "file"
cd /sources && tar -xf file-5.46.tar.gz && cd file-5.46
mkdir build && pushd build
../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
make && popd
./configure --prefix=/usr --enable-static=no
make FILE_COMPILE=$(pwd)/build/src/file
make install
cd /sources && rm -rf file-5.46
echo "✅ file done"

# READLINE
build_pkg "readline"
cd /sources && tar -xf readline-8.3.tar.gz && cd readline-8.3
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
./configure --prefix=/usr --disable-static --with-curses
make SHLIB_LIBS="-lncursesw"
make SHLIB_LIBS="-lncursesw" install
cd /sources && rm -rf readline-8.3
echo "✅ readline done"

# M4
build_pkg "m4"
cd /sources && tar -xf m4-1.4.20.tar.xz && cd m4-1.4.20
./configure --prefix=/usr
make && make install
cd /sources && rm -rf m4-1.4.20
echo "✅ m4 done"

# BC
build_pkg "bc"
cd /sources && tar -xf bc-7.0.3.tar.xz && cd bc-7.0.3
CC=gcc ./configure --prefix=/usr -G -O3 -r
make && make install
cd /sources && rm -rf bc-7.0.3
echo "✅ bc done"

# FLEX
build_pkg "flex"
cd /sources && tar -xf flex-2.6.4.tar.gz && cd flex-2.6.4
./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4 --disable-static
make && make install
ln -sv flex /usr/bin/lex
ln -sv flex.1 /usr/share/man/man1/lex.1
cd /sources && rm -rf flex-2.6.4
echo "✅ flex done"

# TCل
build_pkg "tcl"
cd /sources && tar -xf tcl8.6.16-src.tar.gz && cd tcl8.6.16
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr --mandir=/usr/share/man
make
make install
chmod -v u+w /usr/lib/libtcl8.6.so
make install-private-headers
ln -sfv tclsh8.6 /usr/bin/tclsh
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
cd /sources && rm -rf tcl8.6.16
echo "✅ tcl done"

# EXPECT
build_pkg "expect"
cd /sources && tar -xf expect5.45.4.tar.gz && cd expect5.45.4
patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
./configure --prefix=/usr --with-tcl=/usr/lib --enable-shared --mandir=/usr/share/man --with-tclinclude=/usr/include
make && make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
cd /sources && rm -rf expect5.45.4
echo "✅ expect done"

# ATTR
build_pkg "attr"
cd /sources && tar -xf attr-2.5.2.tar.gz && cd attr-2.5.2
./configure --prefix=/usr --disable-static --sysconfdir=/etc --docdir=/usr/share/doc/attr-2.5.2
make && make install
cd /sources && rm -rf attr-2.5.2
echo "✅ attr done"

# ACL
build_pkg "acl"
cd /sources && tar -xf acl-2.3.2.tar.xz && cd acl-2.3.2
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/acl-2.3.2
make && make install
cd /sources && rm -rf acl-2.3.2
echo "✅ acl done"

# LIBCAP
build_pkg "libcap"
cd /sources && tar -xf libcap-2.76.tar.xz && cd libcap-2.76
sed -i '/install -m.*STA/d' libcap/Makefile
make prefix=/usr lib=lib
make prefix=/usr lib=lib install
cd /sources && rm -rf libcap-2.76
echo "✅ libcap done"

# LIBXCRYPT
build_pkg "libxcrypt"
cd /sources && tar -xf libxcrypt-4.4.38.tar.xz && cd libxcrypt-4.4.38
./configure --prefix=/usr --enable-hashes=strong,glibc --enable-obsolete-api=no --disable-static --disable-failure-tokens
make && make install
cd /sources && rm -rf libxcrypt-4.4.38
echo "✅ libxcrypt done"

# OPENSSL
build_pkg "openssl"
cd /sources && tar -xf openssl-3.5.2.tar.gz && cd openssl-3.5.2
./config --prefix=/usr --openssldir=/etc/ssl --libdir=lib shared zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
cd /sources && rm -rf openssl-3.5.2
echo "✅ openssl done"

# KMOD
build_pkg "kmod"
cd /sources && tar -xf kmod-34.2.tar.xz && cd kmod-34.2
./configure --prefix=/usr --sysconfdir=/etc --with-openssl --with-xz --with-zstd --with-zlib --disable-manpages
make && make install
for target in depmod insmod modinfo modprobe rmmod; do
    ln -sfv ../bin/kmod /usr/sbin/$target
done
cd /sources && rm -rf kmod-34.2
echo "✅ kmod done"

# LIBFFI
build_pkg "libffi"
cd /sources && tar -xf libffi-3.5.2.tar.gz && cd libffi-3.5.2
./configure --prefix=/usr --disable-static --with-gcc-arch=native
make && make install
cd /sources && rm -rf libffi-3.5.2
echo "✅ libffi done"

# PKGCONF
build_pkg "pkgconf"
cd /sources && tar -xf pkgconf-2.5.1.tar.xz && cd pkgconf-2.5.1
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/pkgconf-2.5.1
make && make install
ln -sv pkgconf /usr/bin/pkg-config
cd /sources && rm -rf pkgconf-2.5.1
echo "✅ pkgconf done"

echo ""
echo "=== Phase 1 Complete: $(date) ==="
echo "Continuing with larger packages..."

# NCURSES
build_pkg "ncurses"
cd /sources && tar -xf ncurses-6.5-20250809.tgz && cd ncurses-6.5-20250809
./configure --prefix=/usr --mandir=/usr/share/man --with-shared --without-debug --without-normal --with-cxx-shared --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig --enable-widec
make && make install
for lib in ncurses form panel menu; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc /usr/lib/pkgconfig/${lib}.pc
done
ln -sfv libncursesw.so /usr/lib/libcurses.so
cd /sources && rm -rf ncurses-6.5-20250809
echo "✅ ncurses done"

# READLINE (already done above, skip)

# SED
build_pkg "sed"
cd /sources && tar -xf sed-4.9.tar.xz && cd sed-4.9
./configure --prefix=/usr
make && make install
cd /sources && rm -rf sed-4.9
echo "✅ sed done"

# LESS
build_pkg "less"
cd /sources && tar -xf less-679.tar.gz && cd less-679
./configure --prefix=/usr --sysconfdir=/etc
make && make install
cd /sources && rm -rf less-679
echo "✅ less done"

# GZIP
build_pkg "gzip"
cd /sources && tar -xf gzip-1.14.tar.xz && cd gzip-1.14
./configure --prefix=/usr
make && make install
cd /sources && rm -rf gzip-1.14
echo "✅ gzip done"

# IPROUTE2
build_pkg "iproute2"
cd /sources && tar -xf iproute2-6.16.0.tar.xz && cd iproute2-6.16.0
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
make NETNS_RUN_DIR=/run/netns
make SBINDIR=/usr/sbin install
cd /sources && rm -rf iproute2-6.16.0
echo "✅ iproute2 done"

# KBD
build_pkg "kbd"
cd /sources && tar -xf kbd-2.8.0.tar.xz && cd kbd-2.8.0
patch -Np1 -i ../kbd-2.8.0-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock
make && make install
cd /sources && rm -rf kbd-2.8.0
echo "✅ kbd done"

# LIBPIPELINE
build_pkg "libpipeline"
cd /sources && tar -xf libpipeline-1.5.8.tar.gz && cd libpipeline-1.5.8
./configure --prefix=/usr
make && make install
cd /sources && rm -rf libpipeline-1.5.8
echo "✅ libpipeline done"

# MAKE
build_pkg "make"
cd /sources && tar -xf make-4.4.1.tar.gz && cd make-4.4.1
./configure --prefix=/usr
make && make install
cd /sources && rm -rf make-4.4.1
echo "✅ make done"

# PATCH
build_pkg "patch"
cd /sources && tar -xf patch-2.8.tar.xz && cd patch-2.8
./configure --prefix=/usr
make && make install
cd /sources && rm -rf patch-2.8
echo "✅ patch done"

# TAR
build_pkg "tar"
cd /sources && tar -xf tar-1.35.tar.xz && cd tar-1.35
./configure --prefix=/usr
make && make install
cd /sources && rm -rf tar-1.35
echo "✅ tar done"

# VIM
build_pkg "vim"
cd /sources && tar -xf vim-9.1.1629.tar.gz && cd vim-9.1.1629
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make && make install
ln -sv vim /usr/bin/vi
cd /sources && rm -rf vim-9.1.1629
echo "✅ vim done"

# GROFF
build_pkg "groff"
cd /sources && tar -xf groff-1.23.0.tar.gz && cd groff-1.23.0
PAGE=letter ./configure --prefix=/usr
make && make install
cd /sources && rm -rf groff-1.23.0
echo "✅ groff done"

# GPERF
build_pkg "gperf"
cd /sources && tar -xf gperf-3.3.tar.gz && cd gperf-3.3
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
make && make install
cd /sources && rm -rf gperf-3.3
echo "✅ gperf done"

# EXPAT
build_pkg "expat"
cd /sources && tar -xf expat-2.7.1.tar.xz && cd expat-2.7.1
./configure --prefix=/usr --disable-static --docdir=/usr/share/doc/expat-2.7.1
make && make install
cd /sources && rm -rf expat-2.7.1
echo "✅ expat done"

# INETUTILS
build_pkg "inetutils"
cd /sources && tar -xf inetutils-2.6.tar.xz && cd inetutils-2.6
sed -i 's/def HAVE_TERMCAP_H/def HAVE_NCURSES_NCURSES_H/' telnet/telnet.c
./configure --prefix=/usr --bindir=/usr/bin --localstatedir=/var --disable-logger --disable-whois --disable-rcp --disable-rexec --disable-rlogin --disable-rsh --disable-servers
make && make install
cd /sources && rm -rf inetutils-2.6
echo "✅ inetutils done"

# PSMISC
build_pkg "psmisc"
cd /sources && tar -xf psmisc-23.7.tar.xz && cd psmisc-23.7
./configure --prefix=/usr
make && make install
cd /sources && rm -rf psmisc-23.7
echo "✅ psmisc done"

# LIBTOOL
build_pkg "libtool"
cd /sources && tar -xf libtool-2.5.4.tar.xz && cd libtool-2.5.4
./configure --prefix=/usr
make && make install
cd /sources && rm -rf libtool-2.5.4
echo "✅ libtool done"

# GDBM
build_pkg "gdbm"
cd /sources && tar -xf gdbm-1.26.tar.gz && cd gdbm-1.26
./configure --prefix=/usr --disable-static --enable-libgdbm-compat
make && make install
cd /sources && rm -rf gdbm-1.26
echo "✅ gdbm done"

# AUTOCONF
build_pkg "autoconf"
cd /sources && tar -xf autoconf-2.72.tar.xz && cd autoconf-2.72
./configure --prefix=/usr
make && make install
cd /sources && rm -rf autoconf-2.72
echo "✅ autoconf done"

# AUTOMAKE
build_pkg "automake"
cd /sources && tar -xf automake-1.18.1.tar.xz && cd automake-1.18.1
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1
make && make install
cd /sources && rm -rf automake-1.18.1
echo "✅ automake done"

# E2FSPROGS
build_pkg "e2fsprogs"
cd /sources && tar -xf e2fsprogs-1.47.3.tar.gz && cd e2fsprogs-1.47.3
mkdir -v build && cd build
../configure --prefix=/usr --sysconfdir=/etc --enable-elf-shlibs --disable-libblkid --disable-libuuid --disable-uuidd --disable-fsck
make && make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
cd /sources && rm -rf e2fsprogs-1.47.3
echo "✅ e2fsprogs done"

# SYSKLOGD
build_pkg "sysklogd"
cd /sources && tar -xf sysklogd-2.7.2.tar.gz && cd sysklogd-2.7.2
./configure --prefix=/usr --sysconfdir=/etc --runstatedir=/run --without-logger
make && make install
cd /sources && rm -rf sysklogd-2.7.2
echo "✅ sysklogd done"

# SYSVINIT
build_pkg "sysvinit"
cd /sources && tar -xf sysvinit-3.14.tar.xz && cd sysvinit-3.14
patch -Np1 -i ../sysvinit-3.14-consolidated-1.patch
make && make install
cd /sources && rm -rf sysvinit-3.14
echo "✅ sysvinit done"

echo ""
echo "=== ALL PACKAGES COMPLETE: $(date) ==="
echo "Now you need to build the Linux kernel manually!"
zj@zj-VMware-Virtual-Platform:~$ 

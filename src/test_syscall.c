include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>

#define SYS_SPYWITHPI 548

int main() {
    printf("\n");
    printf("==========================================\n");
    printf("   Calling SpyWithPi Syscall #548...\n");
    printf("==========================================\n");
    
    long result = syscall(SYS_SPYWITHPI);
    
    printf("   Syscall returned: %ld\n", result);
    printf("   Check kernel log: dmesg | tail -20\n");
    printf("==========================================\n");
    printf("\n");
    
    return 0;
}

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import "KFDBackend.h"
#import "libkfd.h"

static uint64_t gKFD16 = 0;
static bool gKFD16Active = false;

static NSString *kfd16_machine(void) {
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    if (size == 0 || size > 128) return @"";
    char value[128] = {0};
    if (sysctlbyname("hw.machine", value, &size, NULL, 0) != 0) return @"";
    return [NSString stringWithUTF8String:value] ?: @"";
}

static NSString *kfd16_build(void) {
    size_t size = 0;
    sysctlbyname("kern.osversion", NULL, &size, NULL, 0);
    if (size == 0 || size > 128) return @"";
    char value[128] = {0};
    if (sysctlbyname("kern.osversion", value, &size, NULL, 0) != 0) return @"";
    return [NSString stringWithUTF8String:value] ?: @"";
}

bool kfd16_candidate_for_current_device(void) {
    NSOperatingSystemVersion v = NSProcessInfo.processInfo.operatingSystemVersion;
    NSString *machine = kfd16_machine();
    NSString *build = kfd16_build();

    // These are the only iOS entries included by the public libkfd dynamic_info.h:
    // iPhone14,3 (iPhone 14 Pro Max), iOS 16.5 / 20F66.
    // iPhone13,3 (iPhone 12 Pro), iOS 16.6 / 20G75.
    BOOL supported165 = v.majorVersion == 16 && v.minorVersion == 5 && v.patchVersion == 0 &&
                        [machine isEqualToString:@"iPhone14,3"] && [build isEqualToString:@"20F66"];
    BOOL supported166 = v.majorVersion == 16 && v.minorVersion == 6 && v.patchVersion == 0 &&
                        [machine isEqualToString:@"iPhone13,3"] && [build isEqualToString:@"20G75"];
    return supported165 || supported166;
}

int kfd16_open_for_current_device(void) {
    if (gKFD16Active) return 0;
    if (!kfd16_candidate_for_current_device()) {
        NSLog(@"[KFD16] unsupported device/build; refusing to call kopen");
        return -2;
    }

    // landa is the KFD method documented for iOS 16.x and is fixed in iOS 17.0.
    // The public dynamic_info.h includes the two exact combinations above.
    gKFD16 = kopen(2048, puaf_landa, kread_sem_open, kwrite_sem_open);
    if (gKFD16 == 0) {
        NSLog(@"[KFD16] kopen returned an invalid handle");
        return -1;
    }
    gKFD16Active = true;
    NSLog(@"[KFD16] kernel read/write active");
    return 0;
}

void kfd16_close(void) {
    if (!gKFD16Active) return;
    kclose(gKFD16);
    gKFD16 = 0;
    gKFD16Active = false;
}

bool kfd16_is_active(void) {
    return gKFD16Active;
}

bool kfd16_read(uint64_t address, void *buffer, uint64_t size) {
    if (!gKFD16Active || !buffer || size == 0) return false;
    kread(gKFD16, address, buffer, size);
    return true;
}

bool kfd16_write(uint64_t address, const void *buffer, uint64_t size) {
    if (!gKFD16Active || !buffer || size == 0) return false;
    kwrite(gKFD16, (void *)buffer, address, size);
    return true;
}

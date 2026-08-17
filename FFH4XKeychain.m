#import "FFH4XKeychain.h"

#include <Security/Security.h>

static NSString * const r7x_KeychainService = @"com.ffh4x.r4ge.secure";
static NSString * const r7x_DeviceAccount = @"ffh4x.device-id";
static NSString * const r7x_LicenseAccount = @"ffh4x.license-key";

static NSMutableDictionary *r7x_BaseQuery(NSString *account) {
    return [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: r7x_KeychainService,
        (__bridge id)kSecAttrAccount: account
    } mutableCopy];
}

static NSData *r7x_KeychainRead(NSString *account) {
    NSMutableDictionary *query = r7x_BaseQuery(account);
    query[(__bridge id)kSecReturnData] = @YES;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;

    NSData *data = [(__bridge NSData *)result copy];
    CFRelease(result);
    return data;
}

static BOOL r7x_KeychainWrite(NSData *data, NSString *account) {
    if (!data || !account) return NO;

    NSMutableDictionary *query = r7x_BaseQuery(account);
    query[(__bridge id)kSecValueData] = data;
    query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly;

    SecItemDelete((__bridge CFDictionaryRef)r7x_BaseQuery(account));
    return SecItemAdd((__bridge CFDictionaryRef)query, NULL) == errSecSuccess;
}

NSString *r7x_KeychainDeviceIdentifier(void) {
    NSData *saved = r7x_KeychainRead(r7x_DeviceAccount);
    NSString *value = saved.length > 0 ? [[NSString alloc] initWithData:saved encoding:NSUTF8StringEncoding] : nil;
    if (value.length > 0) return value;

    NSString *generated = [[NSUUID UUID].UUIDString lowercaseString];
    if (!r7x_KeychainWrite([generated dataUsingEncoding:NSUTF8StringEncoding], r7x_DeviceAccount)) return nil;
    return generated;
}

BOOL r7x_KeychainSaveLicenseKey(NSString *key) {
    NSString *normalized = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (normalized.length == 0) return NO;
    return r7x_KeychainWrite([normalized dataUsingEncoding:NSUTF8StringEncoding], r7x_LicenseAccount);
}

NSString *r7x_KeychainSavedLicenseKey(void) {
    NSData *saved = r7x_KeychainRead(r7x_LicenseAccount);
    NSString *value = saved.length > 0 ? [[NSString alloc] initWithData:saved encoding:NSUTF8StringEncoding] : nil;
    return value.length > 0 ? value : nil;
}

void r7x_KeychainDeleteLicenseKey(void) {
    SecItemDelete((__bridge CFDictionaryRef)r7x_BaseQuery(r7x_LicenseAccount));
}

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * _Nullable r7x_KeychainDeviceIdentifier(void);
FOUNDATION_EXPORT BOOL r7x_KeychainSaveLicenseKey(NSString *key);
FOUNDATION_EXPORT NSString * _Nullable r7x_KeychainSavedLicenseKey(void);
FOUNDATION_EXPORT void r7x_KeychainDeleteLicenseKey(void);

NS_ASSUME_NONNULL_END

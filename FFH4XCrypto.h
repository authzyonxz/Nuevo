#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSData * _Nullable r7x_SHA256(NSData * _Nullable data);
FOUNDATION_EXPORT NSData * _Nullable r7x_HKDF_SHA256(NSData * _Nullable ikm,
                                                       NSData * _Nullable salt,
                                                       NSData * _Nullable info,
                                                       NSUInteger outputLength);
FOUNDATION_EXPORT NSData * _Nullable r7x_RandomData(NSUInteger length);
FOUNDATION_EXPORT NSString *r7x_Base64URLString(NSData * _Nullable data);
FOUNDATION_EXPORT NSData * _Nullable r7x_DataFromBase64URL(NSString * _Nullable value);

FOUNDATION_EXPORT BOOL r7x_AES256GCMSeal(NSData * _Nullable key,
                                         NSData * _Nullable nonce,
                                         NSData * _Nullable aad,
                                         NSData * _Nullable plaintext,
                                         NSData * _Nullable __strong * _Nonnull ciphertext,
                                         NSData * _Nullable __strong * _Nonnull tag);

FOUNDATION_EXPORT NSData * _Nullable r7x_AES256GCMOpen(NSData * _Nullable key,
                                                         NSData * _Nullable nonce,
                                                         NSData * _Nullable aad,
                                                         NSData * _Nullable ciphertext,
                                                         NSData * _Nullable tag);

NS_ASSUME_NONNULL_END

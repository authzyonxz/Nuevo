#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FFH4XSecureClientCompletion)(NSDictionary * _Nullable info,
                                             NSString * _Nullable errorCode,
                                             NSString * _Nullable errorMessage);

@interface r7x_SecureClient : NSObject

- (nullable instancetype)initWithKey:(NSString *)key
                              product:(NSString *)product
                               errorCode:(NSString * _Nullable * _Nullable)errorCode
                            errorMessage:(NSString * _Nullable * _Nullable)errorMessage;

- (void)validateKeyWithCompletion:(FFH4XSecureClientCompletion)completion;
- (void)checkSessionWithCompletion:(FFH4XSecureClientCompletion)completion;
- (void)clearSession;

@end

NS_ASSUME_NONNULL_END

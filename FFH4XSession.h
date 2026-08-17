#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const FFH4XSessionDidAuthorizeNotification;
FOUNDATION_EXPORT NSString * const FFH4XSessionDidInvalidateNotification;

typedef void (^FFH4XSessionCompletion)(BOOL success,
                                        NSDictionary * _Nullable licenseInfo,
                                        NSString * _Nullable errorCode,
                                        NSString * _Nullable errorMessage);

@interface FFH4XSession : NSObject

+ (instancetype)sharedSession;

@property (nonatomic, readonly, getter=isAuthorized) BOOL authorized;
@property (nonatomic, readonly) NSString *product;
@property (nonatomic, readonly, nullable) NSDictionary *licenseInfo;

- (void)authenticateKey:(NSString *)key
                   save:(BOOL)save
             completion:(FFH4XSessionCompletion)completion;

- (void)restoreSavedKeyWithCompletion:(FFH4XSessionCompletion)completion;

- (void)checkSessionWithCompletion:(FFH4XSessionCompletion _Nullable)completion;

- (void)clearSession;

@end

NS_ASSUME_NONNULL_END

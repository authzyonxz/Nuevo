#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^RageLoginCompletion)(NSDictionary *licenseInfo);

@interface RageLoginView : UIView

+ (instancetype)presentInWindow:(UIWindow *)window completion:(RageLoginCompletion)completion;

@end

NS_ASSUME_NONNULL_END

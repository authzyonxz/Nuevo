#import "RageLicenseState.h"

NSString * const r7x_Notify_92 = @"r7x_Notify_92";

static NSDictionary *sRageLicenseInfo;
static NSString *sRageLicenseKey;
static NSString *sRageSessionToken;
static NSDate *sRageLastServerCheck;
static NSTimer *sRageHeartbeatTimer;
static BOOL sRageLicenseValid = NO;
static BOOL sRageCheckingSession = NO;
static BOOL sRageInvalidationSent = NO;
static const NSTimeInterval kRageServerCheckGrace = 25.0;
static const NSTimeInterval kRageHeartbeatInterval = 15.0;
static NSString * const kRageSessionCheckURL = @"https://ffh4xcorporation.online/api/session/check";

static NSDate *RageDateFromString(NSString *value) {
    if (value.length == 0 || [value isEqualToString:@"—"]) return nil;
    NSDate *date = [[NSISO8601DateFormatter new] dateFromString:value];
    if (date) return date;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX";
    return [formatter dateFromString:value];
}

static void RageSessionCheckFinished(BOOL valid, NSDictionary *json) {
    dispatch_async(dispatch_get_main_queue(), ^{
        sRageCheckingSession = NO;
        if (valid) {
            sRageLastServerCheck = [NSDate date];
            if (json.count > 0) {
                NSMutableDictionary *updated = [sRageLicenseInfo mutableCopy] ?: [NSMutableDictionary dictionary];
                [updated addEntriesFromDictionary:json];
                updated[@"valid"] = @YES;
                sRageLicenseInfo = [updated copy];
            }
            return;
        }
        r7x_Invalidate_8x();
    });
}

static void RagePerformSessionCheck(void) {
    if (!sRageLicenseValid || sRageSessionToken.length == 0 || sRageCheckingSession) return;
    sRageCheckingSession = YES;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kRageSessionCheckURL]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 12.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", sRageSessionToken] forHTTPHeaderField:@"Authorization"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{ @"action": @"check" } options:0 error:nil];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = nil;
        if (data) {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([object isKindOfClass:NSDictionary.class]) json = object;
        }
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        BOOL valid = !error && statusCode >= 200 && statusCode < 300 && [json[@"valid"] respondsToSelector:@selector(boolValue)] && [json[@"valid"] boolValue];
        RageSessionCheckFinished(valid, json ?: @{});
    }];
    [task resume];
}

void r7x_Store_4c(NSDictionary *info) {
    sRageLicenseInfo = [info copy];
    sRageLicenseValid = [info[@"valid"] respondsToSelector:@selector(boolValue)] && [info[@"valid"] boolValue];
    NSString *token = [info[@"sessionToken"] isKindOfClass:NSString.class] ? info[@"sessionToken"] : nil;
    sRageSessionToken = [token copy];
    sRageLastServerCheck = sRageLicenseValid && sRageSessionToken.length > 0 ? [NSDate date] : nil;
    sRageInvalidationSent = NO;
    if (!sRageLicenseValid || sRageSessionToken.length == 0) {
        sRageLicenseValid = NO;
    }
}

void r7x_StoreKey_7p(NSString *key) {
    sRageLicenseKey = [key copy];
}

void r7x_Start_3m(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [sRageHeartbeatTimer invalidate];
        sRageHeartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:kRageHeartbeatInterval repeats:YES block:^(__unused NSTimer *timer) {
            RagePerformSessionCheck();
        }];
        RagePerformSessionCheck();
    });
}

void r7x_Stop_3m(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [sRageHeartbeatTimer invalidate];
        sRageHeartbeatTimer = nil;
    });
}

void r7x_Invalidate_8x(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL shouldNotify = !sRageInvalidationSent && (sRageLicenseValid || sRageSessionToken.length > 0);
        sRageLicenseValid = NO;
        sRageSessionToken = nil;
        sRageLastServerCheck = nil;
        sRageLicenseInfo = nil;
        sRageInvalidationSent = YES;
        [sRageHeartbeatTimer invalidate];
        sRageHeartbeatTimer = nil;
        if (shouldNotify) {
            [[NSNotificationCenter defaultCenter] postNotificationName:r7x_Notify_92 object:nil];
        }
    });
}

BOOL r7x_IsValid_2v(void) {
    return sRageLicenseValid;
}

BOOL r7x_Gate_7q(void) {
    if (!sRageLicenseValid || sRageSessionToken.length == 0) return NO;
    NSDate *expiry = RageDateFromString([sRageLicenseInfo[@"sessionExpiresAt"] isKindOfClass:NSString.class] ? sRageLicenseInfo[@"sessionExpiresAt"] : nil);
    if (expiry && [expiry timeIntervalSinceNow] <= 0) {
        r7x_Invalidate_8x();
        return NO;
    }
    if (!sRageLastServerCheck || [[NSDate date] timeIntervalSinceDate:sRageLastServerCheck] > kRageServerCheckGrace) {
        RagePerformSessionCheck();
        return NO;
    }
    return YES;
}

NSString *r7x_Field_9d(NSString *field) {
    id value = sRageLicenseInfo[field];
    if ([value isKindOfClass:NSString.class] && [((NSString *)value) length] > 0) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return @"—";
}

NSString *r7x_Mask_3h(void) {
    if (sRageLicenseKey.length == 0) return @"—";
    if (sRageLicenseKey.length <= 4) return @"••••";
    NSString *suffix = [sRageLicenseKey substringFromIndex:sRageLicenseKey.length - 4];
    return [NSString stringWithFormat:@"••••••••••••%@", suffix];
}

NSString *r7x_Time_5j(void) {
    NSDate *expiry = RageDateFromString(r7x_Field_9d(@"expiresAt"));
    if (!expiry) return @"—";
    NSTimeInterval seconds = [expiry timeIntervalSinceNow];
    if (seconds <= 0) return @"Expirada";
    NSInteger days = (NSInteger)(seconds / 86400.0);
    NSInteger hours = (NSInteger)((seconds - days * 86400.0) / 3600.0);
    NSInteger minutes = (NSInteger)((seconds - days * 86400.0 - hours * 3600.0) / 60.0);
    if (days > 0) return [NSString stringWithFormat:@"%ldd %ldh restantes", (long)days, (long)hours];
    if (hours > 0) return [NSString stringWithFormat:@"%ldh %ldmin restantes", (long)hours, (long)minutes];
    return [NSString stringWithFormat:@"%ldmin restantes", (long)MAX(minutes, 1)];
}

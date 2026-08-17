#import "FFH4XSession.h"
#import "FFH4XKeychain.h"
#import "FFH4XSecureClient.h"

NSString * const FFH4XSessionDidAuthorizeNotification = @"FFH4XSessionDidAuthorizeNotification";
NSString * const FFH4XSessionDidInvalidateNotification = @"FFH4XSessionDidInvalidateNotification";

@interface FFH4XSession ()
@property (nonatomic, strong, nullable) r7x_SecureClient *client;
@property (nonatomic, strong, nullable) NSTimer *heartbeatTimer;
@property (nonatomic, readwrite, getter=isAuthorized) BOOL authorized;
@property (nonatomic, readwrite) NSString *product;
@property (nonatomic, readwrite, nullable) NSDictionary *licenseInfo;
@end

@implementation FFH4XSession

+ (instancetype)sharedSession {
    static FFH4XSession *sharedSession;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSession = [FFH4XSession new];
    });
    return sharedSession;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _product = @"ruanwq";
        _authorized = NO;
    }
    return self;
}

- (void)dealloc {
    [self.heartbeatTimer invalidate];
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)authenticateKey:(NSString *)key
                   save:(BOOL)save
             completion:(FFH4XSessionCompletion)completion {
    [self r7xInvalidateWithoutNotification];

    NSString *normalized = [[key ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if (normalized.length == 0) {
        [self r7xFinish:completion success:NO info:nil code:@"E_INVALID_KEY" message:@"Informe uma KEY."];
        return;
    }
    if (save && !r7x_KeychainSaveLicenseKey(normalized)) {
        [self r7xFinish:completion success:NO info:nil code:@"E_KEYCHAIN" message:@"Não foi possível acessar o Keychain."];
        return;
    }

    NSString *errorCode = nil;
    NSString *errorMessage = nil;
    r7x_SecureClient *client = [[r7x_SecureClient alloc] initWithKey:normalized
                                                                  product:self.product
                                                                errorCode:&errorCode
                                                             errorMessage:&errorMessage];
    if (!client) {
        [self r7xFinish:completion success:NO info:nil code:errorCode ?: @"E_AUTH" message:errorMessage ?: @"Falha de autenticação."];
        return;
    }

    self.client = client;
    [client validateKeyWithCompletion:^(NSDictionary * _Nullable info,
                                        NSString * _Nullable code,
                                        NSString * _Nullable message) {
        BOOL success = [info[@"valid"] boolValue];
        if (!success) {
            [self r7xInvalidateWithoutNotification];
            [self r7xFinish:completion success:NO info:nil code:code ?: @"E_INVALID_KEY" message:message ?: @"A KEY não foi aceita."];
            return;
        }

        self.authorized = YES;
        self.licenseInfo = [info copy];
        [self r7xStartHeartbeat];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:FFH4XSessionDidAuthorizeNotification object:self];
            if (completion) completion(YES, self.licenseInfo, nil, nil);
        });
    }];
}

- (void)restoreSavedKeyWithCompletion:(FFH4XSessionCompletion)completion {
    NSString *saved = r7x_KeychainSavedLicenseKey();
    if (saved.length == 0) {
        [self r7xFinish:completion success:NO info:nil code:@"E_NO_SAVED_KEY" message:@"Nenhuma KEY salva neste dispositivo."];
        return;
    }
    [self authenticateKey:saved save:YES completion:completion];
}

- (void)checkSessionWithCompletion:(FFH4XSessionCompletion)completion {
    r7x_SecureClient *client = self.client;
    if (!client || !self.authorized) {
        [self r7xFinish:completion success:NO info:nil code:@"E_NO_SESSION" message:@"Sessão não autorizada."];
        return;
    }

    [client checkSessionWithCompletion:^(NSDictionary * _Nullable info,
                                         NSString * _Nullable code,
                                         NSString * _Nullable message) {
        id validValue = info[@"valid"];
        if (![validValue isKindOfClass:[NSNumber class]]) {
            // Falha transitória de rede/cripto/resposta: não encerra a sessão.
            [self r7xFinish:completion success:NO info:nil code:code ?: @"E_SESSION_CHECK" message:message ?: @"Não foi possível verificar a sessão agora."];
            return;
        }
        if (![validValue boolValue]) {
            // Somente o servidor confirmando valid=false invalida a sessão.
            [self r7xInvalidateAndNotify];
            [self r7xFinish:completion success:NO info:nil code:code ?: @"E_INVALID_SESSION" message:message ?: @"A sessão expirou."];
            return;
        }
        if (info.count > 0) self.licenseInfo = [info copy];
        [self r7xFinish:completion success:YES info:self.licenseInfo code:nil message:nil];
    }];
}

- (void)clearSession {
    [self r7xInvalidateAndNotify];
}

#pragma mark - Private session state

- (void)r7xStartHeartbeat {
    [self.heartbeatTimer invalidate];
    self.heartbeatTimer = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:300.0
                                                                target:self
                                                              selector:@selector(r7xHeartbeatTick:)
                                                              userInfo:nil
                                                               repeats:YES];
    });
}

- (void)r7xHeartbeatTick:(NSTimer *)timer {
    if (!self.authorized || !self.client) {
        [timer invalidate];
        return;
    }
    [self checkSessionWithCompletion:nil];
}

- (void)r7xInvalidateWithoutNotification {
    [self.heartbeatTimer invalidate];
    self.heartbeatTimer = nil;
    [self.client clearSession];
    self.client = nil;
    self.authorized = NO;
    self.licenseInfo = nil;
}

- (void)r7xInvalidateAndNotify {
    [self r7xInvalidateWithoutNotification];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:FFH4XSessionDidInvalidateNotification object:self];
    });
}

- (void)r7xFinish:(FFH4XSessionCompletion)completion
          success:(BOOL)success
             info:(NSDictionary *)info
             code:(NSString *)code
          message:(NSString *)message {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(success, info, code, message);
    });
}

@end

#import "FFH4XSecureClient.h"
#import "FFH4XCrypto.h"
#import "FFH4XKeychain.h"

#include <mbedtls/platform_util.h>
#include <math.h>

static NSString * const r7x_BaseURLString = @"https://ffh4xcorporation.online";
static NSString * const r7x_Algorithm = @"A256GCM";
static NSString * const r7x_Protocol = @"ffh4x-secure-v1";
static NSString * const r7x_GenericNetworkError = @"Não foi possível conectar ao servidor.";
static NSString * const r7x_GenericCryptoError = @"Falha de autenticação segura.";

@interface r7x_SecureClient ()
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *product;
@property (nonatomic, copy) NSString *keyId;
@property (nonatomic, copy) NSString *deviceId;
@property (nonatomic, copy, nullable) NSString *sessionId;
@property (nonatomic, copy, nullable) NSString *clientNonceB64;
@property (nonatomic, copy, nullable) NSString *serverNonceB64;
@property (nonatomic, strong, nullable) NSData *clientNonce;
@property (nonatomic, strong, nullable) NSData *sessionKey;
@end

static void r7x_Finish(FFH4XSecureClientCompletion completion,
                       NSDictionary * _Nullable info,
                       NSString * _Nullable code,
                       NSString * _Nullable message);
static NSData *r7x_JoinData(NSData *left, NSData *right);
static NSString *r7x_AAD(NSString *direction, NSString *path, NSDictionary *context);
static NSDictionary * _Nullable r7x_SealObject(NSDictionary *object, NSData *key, NSData *aad);
static NSDictionary * _Nullable r7x_OpenObject(NSDictionary *payload, NSData *key, NSData *aad);
static void r7x_POST(NSString *path,
                     NSDictionary *envelope,
                     void (^completion)(NSDictionary * _Nullable response, NSInteger statusCode));

@implementation r7x_SecureClient

- (instancetype)initWithKey:(NSString *)key
                      product:(NSString *)product
                    errorCode:(NSString **)errorCode
                 errorMessage:(NSString **)errorMessage {
    NSString *normalized = [[key ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if (normalized.length == 0) {
        if (errorCode) *errorCode = @"E_INVALID_KEY";
        if (errorMessage) *errorMessage = @"KEY inválida.";
        return nil;
    }
    if (![product isKindOfClass:[NSString class]] || product.length == 0) {
        if (errorCode) *errorCode = @"E_PRODUCT";
        if (errorMessage) *errorMessage = @"Produto inválido.";
        return nil;
    }

    self = [super init];
    if (!self) return nil;
    _key = [normalized copy];
    _product = [product copy];
    NSData *keyHash = r7x_SHA256([normalized dataUsingEncoding:NSUTF8StringEncoding]);
    _keyId = keyHash ? r7x_Base64URLString(keyHash) : @"";
    _deviceId = [r7x_KeychainDeviceIdentifier() copy];
    if (_keyId.length == 0 || _deviceId.length == 0) {
        if (errorCode) *errorCode = @"E_KEYCHAIN";
        if (errorMessage) *errorMessage = @"Não foi possível acessar o Keychain.";
        return nil;
    }
    return self;
}

- (void)validateKeyWithCompletion:(FFH4XSecureClientCompletion)completion {
    NSData *clientNonce = r7x_RandomData(16);
    NSString *clientNonceB64 = r7x_Base64URLString(clientNonce);
    NSString *requestId = [[[NSUUID UUID] UUIDString] lowercaseString];
    long long timestamp = (long long)floor([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSData *bootstrapKey = r7x_HKDF_SHA256([self.key dataUsingEncoding:NSUTF8StringEncoding],
                                             clientNonce,
                                             [@"ffh4x-secure-v1/bootstrap" dataUsingEncoding:NSUTF8StringEncoding],
                                             32);
    NSDictionary *context = @{
        @"keyId": self.keyId,
        @"clientNonceB64": clientNonceB64 ?: @"",
        @"timestamp": @(timestamp),
        @"requestId": requestId,
        @"sessionId": @""
    };
    NSString *aadString = r7x_AAD(@"request", @"/api/secure/validate-key", context);
    NSDictionary *requestBody = @{
        @"keyId": self.keyId,
        @"deviceId": self.deviceId,
        @"product": self.product
    };
    NSDictionary *payload = r7x_SealObject(requestBody, bootstrapKey, [aadString dataUsingEncoding:NSUTF8StringEncoding]);
    if (!clientNonce || !bootstrapKey || !payload) {
        r7x_Finish(completion, nil, @"E_CRYPTO", r7x_GenericCryptoError);
        return;
    }

    NSDictionary *envelope = @{
        @"v": @1,
        @"alg": r7x_Algorithm,
        @"keyId": self.keyId,
        @"clientNonce": clientNonceB64,
        @"timestamp": @(timestamp),
        @"requestId": requestId,
        @"sessionId": [NSNull null],
        @"serverNonce": [NSNull null],
        @"payload": payload
    };

    r7x_POST(@"/api/secure/validate-key", envelope, ^(NSDictionary * _Nullable response, NSInteger statusCode) {
        if (!response) {
            r7x_Finish(completion, nil, @"E_NETWORK", r7x_GenericNetworkError);
            return;
        }
        NSDictionary *responsePayload = [response[@"payload"] isKindOfClass:[NSDictionary class]] ? response[@"payload"] : nil;
        NSString *serverNonceB64 = [response[@"serverNonce"] isKindOfClass:[NSString class]] ? response[@"serverNonce"] : nil;
        NSString *sessionId = [response[@"sessionId"] isKindOfClass:[NSString class]] ? response[@"sessionId"] : nil;
        NSData *serverNonce = serverNonceB64 ? r7x_DataFromBase64URL(serverNonceB64) : nil;

        if (!responsePayload || !serverNonce || serverNonce.length == 0 || sessionId.length == 0) {
            NSDictionary *failure = responsePayload ? r7x_OpenObject(responsePayload, bootstrapKey, [r7x_AAD(@"response", @"/api/secure/validate-key", context) dataUsingEncoding:NSUTF8StringEncoding]) : nil;
            NSString *reason = [failure[@"reason"] isKindOfClass:[NSString class]] ? failure[@"reason"] : @"E_INVALID_KEY";
            r7x_Finish(completion, nil, reason, @"A KEY não foi aceita.");
            return;
        }

        NSData *sessionKey = r7x_HKDF_SHA256([self.key dataUsingEncoding:NSUTF8StringEncoding],
                                               r7x_JoinData(clientNonce, serverNonce),
                                               [@"ffh4x-secure-v1/session" dataUsingEncoding:NSUTF8StringEncoding],
                                               32);
        NSDictionary *responseContext = @{
            @"keyId": self.keyId,
            @"clientNonceB64": clientNonceB64,
            @"timestamp": @(timestamp),
            @"requestId": requestId,
            @"sessionId": sessionId
        };
        NSDictionary *validation = sessionKey ? r7x_OpenObject(responsePayload,
                                                                 sessionKey,
                                                                 [r7x_AAD(@"response", @"/api/secure/validate-key", responseContext) dataUsingEncoding:NSUTF8StringEncoding]) : nil;
        if (!validation || ![validation[@"valid"] boolValue]) {
            r7x_Finish(completion, nil, @"E_INVALID_KEY", @"A KEY não foi aceita.");
            return;
        }

        self.clientNonce = clientNonce;
        self.clientNonceB64 = clientNonceB64;
        self.serverNonceB64 = serverNonceB64;
        self.sessionId = sessionId;
        self.sessionKey = sessionKey;
        NSMutableDictionary *info = [validation mutableCopy];
        if (!info[@"product"]) info[@"product"] = self.product;
        if (!info[@"productName"]) info[@"productName"] = @"Painel Ruanwq";
        if (!info[@"status"]) info[@"status"] = @"active";
        if (!info[@"requestId"]) info[@"requestId"] = requestId;
        r7x_Finish(completion, info, nil, nil);
    });
}

- (void)checkSessionWithCompletion:(FFH4XSecureClientCompletion)completion {
    if (!self.sessionKey || self.sessionId.length == 0 || self.clientNonceB64.length == 0 || self.serverNonceB64.length == 0) {
        r7x_Finish(completion, nil, @"E_NO_SESSION", @"Sessão não autorizada.");
        return;
    }

    long long timestamp = (long long)floor([[NSDate date] timeIntervalSince1970] * 1000.0);
    NSString *requestId = [[[NSUUID UUID] UUIDString] lowercaseString];
    NSDictionary *context = @{
        @"keyId": self.keyId,
        @"clientNonceB64": self.clientNonceB64,
        @"timestamp": @(timestamp),
        @"requestId": requestId,
        @"sessionId": self.sessionId
    };
    NSDictionary *requestBody = @{@"action": @"check"};
    NSDictionary *payload = r7x_SealObject(requestBody,
                                            self.sessionKey,
                                            [r7x_AAD(@"request", @"/api/secure/session/check", context) dataUsingEncoding:NSUTF8StringEncoding]);
    if (!payload) {
        r7x_Finish(completion, nil, @"E_CRYPTO", r7x_GenericCryptoError);
        return;
    }

    NSDictionary *envelope = @{
        @"v": @1,
        @"alg": r7x_Algorithm,
        @"keyId": self.keyId,
        @"clientNonce": self.clientNonceB64,
        @"timestamp": @(timestamp),
        @"requestId": requestId,
        @"sessionId": self.sessionId,
        @"serverNonce": self.serverNonceB64,
        @"payload": payload
    };

    r7x_POST(@"/api/secure/session/check", envelope, ^(NSDictionary * _Nullable response, NSInteger statusCode) {
        NSDictionary *responsePayload = [response[@"payload"] isKindOfClass:[NSDictionary class]] ? response[@"payload"] : nil;
        NSDictionary *check = responsePayload ? r7x_OpenObject(responsePayload,
                                                               self.sessionKey,
                                                               [r7x_AAD(@"response", @"/api/secure/session/check", context) dataUsingEncoding:NSUTF8StringEncoding]) : nil;
        if (![check[@"valid"] isKindOfClass:[NSNumber class]]) {
            // Rede, criptografia ou resposta incompleta são falhas transitórias.
            // Não limpar a sessão nem remover a tela de login por causa delas.
            r7x_Finish(completion, nil, @"E_SESSION_CHECK", @"Verificação temporariamente indisponível.");
            return;
        }
        if (![check[@"valid"] boolValue]) {
            // Logout somente com confirmação explícita do servidor.
            [self clearSession];
        }
        r7x_Finish(completion, check, nil, nil);
    });
}

- (void)clearSession {
    if (self.sessionKey.length > 0) {
        NSMutableData *mutable = [self.sessionKey mutableCopy];
        mbedtls_platform_zeroize(mutable.mutableBytes, mutable.length);
    }
    self.sessionKey = nil;
    self.clientNonce = nil;
    self.clientNonceB64 = nil;
    self.serverNonceB64 = nil;
    self.sessionId = nil;
    self.keyId = @"";
    self.key = @"";
}

@end

static void r7x_Finish(FFH4XSecureClientCompletion completion,
                       NSDictionary * _Nullable info,
                       NSString * _Nullable code,
                       NSString * _Nullable message) {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(info, code, message);
    });
}

static NSData *r7x_JoinData(NSData *left, NSData *right) {
    NSMutableData *joined = [left mutableCopy];
    [joined appendData:right];
    return joined;
}

static NSString *r7x_AAD(NSString *direction, NSString *path, NSDictionary *context) {
    return [NSString stringWithFormat:@"%@|%@|POST|%@|1|%@|%@|%@|%@|%@",
            r7x_Protocol,
            direction,
            path,
            context[@"keyId"] ?: @"",
            context[@"clientNonceB64"] ?: @"",
            context[@"timestamp"] ?: @0,
            context[@"requestId"] ?: @"",
            context[@"sessionId"] ?: @""];
}

static NSDictionary * _Nullable r7x_SealObject(NSDictionary *object, NSData *key, NSData *aad) {
    NSError *error = nil;
    NSData *plaintext = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    NSData *nonce = r7x_RandomData(12);
    NSData *ciphertext = nil;
    NSData *tag = nil;
    if (!plaintext || !nonce || !r7x_AES256GCMSeal(key, nonce, aad, plaintext, &ciphertext, &tag)) return nil;
    return @{
        @"nonce": r7x_Base64URLString(nonce),
        @"ciphertext": r7x_Base64URLString(ciphertext),
        @"tag": r7x_Base64URLString(tag)
    };
}

static NSDictionary * _Nullable r7x_OpenObject(NSDictionary *payload, NSData *key, NSData *aad) {
    NSString *nonceB64 = [payload[@"nonce"] isKindOfClass:[NSString class]] ? payload[@"nonce"] : nil;
    NSString *ciphertextB64 = [payload[@"ciphertext"] isKindOfClass:[NSString class]] ? payload[@"ciphertext"] : nil;
    NSString *tagB64 = [payload[@"tag"] isKindOfClass:[NSString class]] ? payload[@"tag"] : nil;
    NSData *nonce = nonceB64 ? r7x_DataFromBase64URL(nonceB64) : nil;
    NSData *ciphertext = ciphertextB64 ? r7x_DataFromBase64URL(ciphertextB64) : nil;
    NSData *tag = tagB64 ? r7x_DataFromBase64URL(tagB64) : nil;
    NSData *plaintext = (nonce && ciphertext && tag) ? r7x_AES256GCMOpen(key, nonce, aad, ciphertext, tag) : nil;
    if (!plaintext) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:plaintext options:NSJSONReadingMutableContainers error:NULL];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

static void r7x_POST(NSString *path,
                     NSDictionary *envelope,
                     void (^completion)(NSDictionary * _Nullable response, NSInteger statusCode)) {
    NSURL *url = [NSURL URLWithString:path relativeToURL:[NSURL URLWithString:r7x_BaseURLString]];
    if (!url) {
        r7x_Finish(^(NSDictionary *info, NSString *code, NSString *message) {
            completion(nil, 0);
        }, nil, @"E_URL", @"URL base inválida.");
        return;
    }

    NSError *serializationError = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:envelope options:0 error:&serializationError];
    if (!body) {
        r7x_Finish(^(NSDictionary *info, NSString *code, NSString *message) {
            completion(nil, 0);
        }, nil, @"E_JSON", @"Falha de comunicação.");
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    request.HTTPBody = body;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, statusCode);
            });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([json isKindOfClass:[NSDictionary class]] ? json : nil, statusCode);
        });
    }];
    [task resume];
}

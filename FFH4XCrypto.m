#import "FFH4XCrypto.h"

#include <Security/Security.h>
#include <mbedtls/gcm.h>
#include <mbedtls/hkdf.h>
#include <mbedtls/md.h>
#include <mbedtls/platform_util.h>
#include <mbedtls/sha256.h>

NSData *r7x_SHA256(NSData *data) {
    if (!data) return nil;

    unsigned char digest[32] = {0};
    mbedtls_sha256_context context;
    mbedtls_sha256_init(&context);

    int rc = mbedtls_sha256_starts_ret(&context, 0);
    if (rc == 0) rc = mbedtls_sha256_update_ret(&context, data.bytes, data.length);
    if (rc == 0) rc = mbedtls_sha256_finish_ret(&context, digest);
    mbedtls_sha256_free(&context);

    if (rc != 0) {
        mbedtls_platform_zeroize(digest, sizeof(digest));
        return nil;
    }

    NSData *result = [NSData dataWithBytes:digest length:sizeof(digest)];
    mbedtls_platform_zeroize(digest, sizeof(digest));
    return result;
}

NSData *r7x_HKDF_SHA256(NSData *ikm, NSData *salt, NSData *info, NSUInteger outputLength) {
    if (!ikm || !salt || !info || outputLength == 0 || outputLength > (255U * 32U)) return nil;

    NSMutableData *output = [NSMutableData dataWithLength:outputLength];
    const mbedtls_md_info_t *md = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (!md) return nil;

    int rc = mbedtls_hkdf(md,
                          salt.bytes, salt.length,
                          ikm.bytes, ikm.length,
                          info.bytes, info.length,
                          output.mutableBytes, output.length);
    return rc == 0 ? [output copy] : nil;
}

NSData *r7x_RandomData(NSUInteger length) {
    if (length == 0) return [NSData data];
    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (SecRandomCopyBytes(kSecRandomDefault, length, data.mutableBytes) != errSecSuccess) return nil;
    return [data copy];
}

NSString *r7x_Base64URLString(NSData *data) {
    if (!data) return @"";
    NSString *base64 = [data base64EncodedStringWithOptions:0];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    base64 = [base64 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    return [base64 stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];
}

NSData *r7x_DataFromBase64URL(NSString *value) {
    if (![value isKindOfClass:[NSString class]] || value.length == 0) return nil;
    NSMutableString *base64 = [value mutableCopy];
    [base64 replaceOccurrencesOfString:@"-" withString:@"+" options:0 range:NSMakeRange(0, base64.length)];
    [base64 replaceOccurrencesOfString:@"_" withString:@"/" options:0 range:NSMakeRange(0, base64.length)];
    NSUInteger remainder = base64.length % 4;
    if (remainder != 0) [base64 appendString:[@"====" substringToIndex:4 - remainder]];
    return [[NSData alloc] initWithBase64EncodedString:base64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

BOOL r7x_AES256GCMSeal(NSData * _Nullable key,
                       NSData * _Nullable nonce,
                       NSData * _Nullable aad,
                       NSData * _Nullable plaintext,
                       NSData * _Nullable __strong * _Nonnull ciphertext,
                       NSData * _Nullable __strong * _Nonnull tag) {
    if (!key || key.length != 32 || !nonce || nonce.length != 12 || !aad || !plaintext || !ciphertext || !tag) return NO;

    NSMutableData *encrypted = [NSMutableData dataWithLength:plaintext.length];
    NSMutableData *authenticationTag = [NSMutableData dataWithLength:16];
    mbedtls_gcm_context context;
    mbedtls_gcm_init(&context);

    int rc = mbedtls_gcm_setkey(&context, MBEDTLS_CIPHER_ID_AES, key.bytes, 256);
    if (rc == 0) {
        rc = mbedtls_gcm_crypt_and_tag(&context,
                                       MBEDTLS_GCM_ENCRYPT,
                                       plaintext.length,
                                       nonce.bytes,
                                       nonce.length,
                                       aad.bytes,
                                       aad.length,
                                       plaintext.bytes,
                                       encrypted.mutableBytes,
                                       authenticationTag.length,
                                       authenticationTag.mutableBytes);
    }
    mbedtls_gcm_free(&context);

    if (rc != 0) return NO;
    *ciphertext = [encrypted copy];
    *tag = [authenticationTag copy];
    return YES;
}

NSData *r7x_AES256GCMOpen(NSData *key,
                          NSData *nonce,
                          NSData *aad,
                          NSData *ciphertext,
                          NSData *tag) {
    if (!key || key.length != 32 || !nonce || nonce.length != 12 || !aad || !ciphertext || !tag || tag.length != 16) return nil;

    NSMutableData *plaintext = [NSMutableData dataWithLength:ciphertext.length];
    mbedtls_gcm_context context;
    mbedtls_gcm_init(&context);

    int rc = mbedtls_gcm_setkey(&context, MBEDTLS_CIPHER_ID_AES, key.bytes, 256);
    if (rc == 0) {
        rc = mbedtls_gcm_auth_decrypt(&context,
                                      ciphertext.length,
                                      nonce.bytes,
                                      nonce.length,
                                      aad.bytes,
                                      aad.length,
                                      tag.bytes,
                                      tag.length,
                                      ciphertext.bytes,
                                      plaintext.mutableBytes);
    }
    mbedtls_gcm_free(&context);

    if (rc != 0) {
        if (plaintext.length > 0) mbedtls_platform_zeroize(plaintext.mutableBytes, plaintext.length);
        return nil;
    }
    return [plaintext copy];
}

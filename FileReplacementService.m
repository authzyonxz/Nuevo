#import "FileReplacementService.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <unistd.h>

static void FRSSetError(NSString * _Nullable *outError, NSString *message) {
    if (outError) *outError = message;
}

NSString *FRSFileSHA256(NSString *path) {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return nil;

    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    @try {
        while (YES) {
            NSData *chunk = [handle readDataOfLength:1024 * 1024];
            if (chunk.length == 0) break;
            CC_SHA256_Update(&context, chunk.bytes, (CC_LONG)chunk.length);
        }
    } @catch (__unused NSException *exception) {
        [handle closeFile];
        return nil;
    }
    [handle closeFile];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }
    return result;
}

static BOOL FRSIsSymlink(NSString *path) {
    struct stat st;
    return lstat(path.fileSystemRepresentation, &st) == 0 && S_ISLNK(st.st_mode);
}

BOOL FRSValidateRegularFile(NSString *path,
                            unsigned long long expectedSize,
                            NSString *expectedSHA256,
                            NSString **errorMessage) {
    if (path.length == 0) {
        FRSSetError(errorMessage, @"Caminho vazio.");
        return NO;
    }
    if (FRSIsSymlink(path)) {
        FRSSetError(errorMessage, [NSString stringWithFormat:@"Links simbólicos não são aceitos: %@", path]);
        return NO;
    }

    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) {
        FRSSetError(errorMessage, [NSString stringWithFormat:@"Arquivo não encontrado: %@", path]);
        return NO;
    }
    if (isDirectory) {
        FRSSetError(errorMessage, [NSString stringWithFormat:@"O caminho é uma pasta: %@", path]);
        return NO;
    }

    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    unsigned long long size = [attributes.fileSize unsignedLongLongValue];
    if (expectedSize > 0 && size != expectedSize) {
        FRSSetError(errorMessage, [NSString stringWithFormat:@"Tamanho inesperado: %llu bytes; esperado %llu.", size, expectedSize]);
        return NO;
    }

    if (expectedSHA256.length > 0) {
        NSString *actualHash = FRSFileSHA256(path);
        if (![actualHash.lowercaseString isEqualToString:expectedSHA256.lowercaseString]) {
            FRSSetError(errorMessage, [NSString stringWithFormat:@"SHA-256 inesperado: %@.", actualHash ?: @"indisponível"]);
            return NO;
        }
    }
    return YES;
}

BOOL FRSReplaceFile(NSString *sourcePath,
                    NSString *destinationPath,
                    NSString *expectedSHA256,
                    NSString **errorMessage) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *validationError = nil;

    if (!FRSValidateRegularFile(sourcePath, 0, expectedSHA256, &validationError)) {
        FRSSetError(errorMessage, [NSString stringWithFormat:@"Origem inválida: %@", validationError]);
        return NO;
    }
    if (!FRSValidateRegularFile(destinationPath, 0, nil, &validationError)) {
        FRSSetError(errorMessage, [NSString stringWithFormat:@"Destino inválido: %@", validationError]);
        return NO;
    }
    if ([sourcePath.stringByStandardizingPath isEqualToString:destinationPath.stringByStandardizingPath]) {
        FRSSetError(errorMessage, @"Origem e destino são o mesmo arquivo.");
        return NO;
    }

    NSString *directory = destinationPath.stringByDeletingLastPathComponent;
    NSString *temporaryPath = [directory stringByAppendingPathComponent:
        [NSString stringWithFormat:@".3105-staging-%@", NSUUID.UUID.UUIDString]];
    NSError *error = nil;
    NSDictionary *destinationAttributes = [fm attributesOfItemAtPath:destinationPath error:&error];
    if (!destinationAttributes || ![fm copyItemAtPath:sourcePath toPath:temporaryPath error:&error]) {
        FRSSetError(errorMessage, [NSString stringWithFormat:@"Não foi possível criar staging: %@", error.localizedDescription ?: @"erro desconhecido"]);
        return NO;
    }

    if (![fm setAttributes:destinationAttributes ofItemAtPath:temporaryPath error:&error]) {
        [fm removeItemAtPath:temporaryPath error:nil];
        FRSSetError(errorMessage, [NSString stringWithFormat:@"Não foi possível preservar atributos: %@", error.localizedDescription ?: @"erro desconhecido"]);
        return NO;
    }

    BOOL replaced = [fm replaceItemAtURL:[NSURL fileURLWithPath:destinationPath]
                          withItemAtURL:[NSURL fileURLWithPath:temporaryPath]
                         backupItemName:nil
                                options:0
                       resultingItemURL:nil
                                 error:&error];
    if (!replaced) {
        [fm removeItemAtPath:temporaryPath error:nil];
        FRSSetError(errorMessage, [NSString stringWithFormat:@"Substituição falhou: %@", error.localizedDescription ?: @"erro desconhecido"]);
        return NO;
    }

    if (expectedSHA256.length > 0) {
        NSString *resultHash = FRSFileSHA256(destinationPath);
        if (![resultHash.lowercaseString isEqualToString:expectedSHA256.lowercaseString]) {
            FRSSetError(errorMessage, [NSString stringWithFormat:@"Hash final inesperado: %@", resultHash ?: @"indisponível"]);
            return NO;
        }
    }
    return YES;
}

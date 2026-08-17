#import "PatchTransaction.h"
#import "FileReplacementService.h"
#import <sys/stat.h>

@implementation FPRule

+ (instancetype)ruleWithBundleID:(NSString *)bundleID
                    relativePath:(NSString *)relativePath
                       sourcePath:(NSString *)sourcePath
                    expectedSize:(unsigned long long)expectedSize
                   expectedSHA256:(NSString *)expectedSHA256 {
    FPRule *rule = [FPRule new];
    rule.bundleID = bundleID;
    rule.relativePath = relativePath;
    rule.sourcePath = sourcePath;
    rule.expectedSize = expectedSize;
    rule.expectedSHA256 = expectedSHA256;
    return rule;
}

- (id)copyWithZone:(NSZone *)zone {
    FPRule *copy = [[[self class] allocWithZone:zone] init];
    copy.bundleID = self.bundleID;
    copy.relativePath = self.relativePath;
    copy.sourcePath = self.sourcePath;
    copy.expectedSize = self.expectedSize;
    copy.expectedSHA256 = self.expectedSHA256;
    return copy;
}
@end

@interface FPPatchTransaction ()
@property(nonatomic, copy, readwrite) NSString *transactionID;
@property(nonatomic, copy, readwrite) NSString *journalPath;
@property(nonatomic, copy) NSString *backupRoot;
@property(nonatomic, copy) FPContainerResolver resolver;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *records;
@end

@implementation FPPatchTransaction

- (instancetype)initWithBackupRoot:(NSString *)backupRoot
                   containerResolver:(FPContainerResolver)resolver {
    self = [super init];
    if (!self) return nil;
    _backupRoot = [backupRoot copy];
    _resolver = [resolver copy];
    _transactionID = NSUUID.UUID.UUIDString;
    _records = [NSMutableArray array];
    _journalPath = [_backupRoot stringByAppendingPathComponent:
        [NSString stringWithFormat:@"%@.plist", _transactionID]];
    return self;
}

static BOOL FPIsSafeBundleID(NSString *bundleID) {
    if (bundleID.length == 0 || bundleID.length > 200) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
    return [bundleID rangeOfCharacterFromSet:[allowed invertedSet]].location == NSNotFound &&
           [bundleID containsString:@"."] &&
           ![bundleID hasPrefix:@"."] && ![bundleID hasSuffix:@"."];
}

static NSString *FPCanonicalRelativePath(NSString *relativePath) {
    if (relativePath.length == 0 || [relativePath hasPrefix:@"/"] ||
        [relativePath containsString:@"\\"] || [relativePath containsString:@"\0"]) return nil;
    NSArray<NSString *> *components = [relativePath componentsSeparatedByString:@"/"];
    NSMutableArray<NSString *> *safe = [NSMutableArray array];
    for (NSString *component in components) {
        if (component.length == 0 || [component isEqualToString:@"."] || [component isEqualToString:@".."] ||
            [component containsString:@":"]) return nil;
        [safe addObject:component];
    }
    return [safe componentsJoinedByString:@"/"];
}

static BOOL FPIsSymlink(NSString *path) {
    struct stat st;
    return lstat(path.fileSystemRepresentation, &st) == 0 && S_ISLNK(st.st_mode);
}

static BOOL FPWriteJournal(NSString *path, NSArray<NSDictionary *> *records, NSString **errorMessage) {
    NSDictionary *journal = @{ @"version": @1, @"records": records ?: @[] };
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:journal
                                                                format:NSPropertyListBinaryFormat_v1_0
                                                               options:0
                                                                 error:&error];
    if (!data || ![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        if (errorMessage) *errorMessage = [NSString stringWithFormat:@"Journal falhou: %@", error.localizedDescription ?: @"erro desconhecido"];
        return NO;
    }
    return YES;
}

- (BOOL)applyRules:(NSArray<FPRule *> *)rules error:(NSString **)errorMessage {
    if (rules.count == 0) {
        if (errorMessage) *errorMessage = @"Nenhuma regra de patch foi fornecida.";
        return NO;
    }
    if (!self.resolver) {
        if (errorMessage) *errorMessage = @"Resolvedor de container ausente.";
        return NO;
    }

    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *directoryError = nil;
    if (![fm createDirectoryAtPath:self.backupRoot withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        if (errorMessage) *errorMessage = [NSString stringWithFormat:@"Backup root falhou: %@", directoryError.localizedDescription];
        return NO;
    }

    for (FPRule *rule in rules) {
        NSString *path = FPCanonicalRelativePath(rule.relativePath);
        if (!FPIsSafeBundleID(rule.bundleID) || !path) {
            if (errorMessage) *errorMessage = [NSString stringWithFormat:@"Regra insegura: %@ / %@", rule.bundleID ?: @"", rule.relativePath ?: @""];
            [self rollback:nil];
            return NO;
        }

        NSString *resolveError = nil;
        NSString *container = self.resolver(rule.bundleID, &resolveError);
        if (container.length == 0 || FPIsSymlink(container)) {
            if (errorMessage) *errorMessage = [NSString stringWithFormat:@"Container indisponível para %@: %@", rule.bundleID, resolveError ?: @"caminho inválido"];
            [self rollback:nil];
            return NO;
        }

        NSString *destination = [container stringByAppendingPathComponent:path];
        NSString *canonicalContainer = container.stringByStandardizingPath;
        NSString *canonicalDestination = destination.stringByStandardizingPath;
        NSString *prefix = [canonicalContainer hasSuffix:@"/"] ? canonicalContainer : [canonicalContainer stringByAppendingString:@"/"];
        if (![canonicalDestination hasPrefix:prefix] || FPIsSymlink(destination)) {
            if (errorMessage) *errorMessage = [NSString stringWithFormat:@"Destino fora do container ou symlink: %@", destination];
            [self rollback:nil];
            return NO;
        }

        BOOL existed = [fm fileExistsAtPath:destination];
        NSString *backupPath = nil;
        if (existed) {
            backupPath = [self.backupRoot stringByAppendingPathComponent:
                [NSString stringWithFormat:@"%@-%@.original", self.transactionID, NSUUID.UUID.UUIDString]];
            NSError *copyError = nil;
            if (![fm copyItemAtPath:destination toPath:backupPath error:&copyError]) {
                if (errorMessage) *errorMessage = [NSString stringWithFormat:@"Backup falhou: %@", copyError.localizedDescription ?: @"erro desconhecido"];
                [self rollback:nil];
                return NO;
            }
        }

        NSString *replaceError = nil;
        if (!FRSReplaceFile(rule.sourcePath, destination, rule.expectedSHA256, &replaceError)) {
            if (errorMessage) *errorMessage = [NSString stringWithFormat:@"Substituição falhou em %@: %@", path, replaceError ?: @"erro desconhecido"];
            [self rollback:nil];
            return NO;
        }

        [self.records addObject:@{
            @"destination": destination,
            @"backup": backupPath ?: [NSNull null],
            @"existed": @(existed)
        }];
        NSString *journalError = nil;
        if (!FPWriteJournal(self.journalPath, self.records, &journalError)) {
            if (errorMessage) *errorMessage = journalError;
            [self rollback:nil];
            return NO;
        }
    }
    return YES;
}

- (BOOL)rollback:(NSString **)errorMessage {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL success = YES;
    for (NSDictionary *record in [self.records reverseObjectEnumerator]) {
        NSString *destination = record[@"destination"];
        id backup = record[@"backup"];
        BOOL existed = [record[@"existed"] boolValue];
        NSError *error = nil;
        if (existed && [backup isKindOfClass:[NSString class]]) {
            if ([fm fileExistsAtPath:destination]) [fm removeItemAtPath:destination error:nil];
            if (![fm copyItemAtPath:backup toPath:destination error:&error]) success = NO;
        } else if (!existed && [fm fileExistsAtPath:destination]) {
            if (![fm removeItemAtPath:destination error:&error]) success = NO;
        }
        if (error && errorMessage) *errorMessage = error.localizedDescription;
    }
    [self.records removeAllObjects];
    [fm removeItemAtPath:self.journalPath error:nil];
    return success;
}
@end

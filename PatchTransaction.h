#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FPRule : NSObject <NSCopying>
@property(nonatomic, copy) NSString *bundleID;
@property(nonatomic, copy) NSString *relativePath;
@property(nonatomic, copy) NSString *sourcePath;
@property(nonatomic, copy, nullable) NSString *expectedSHA256;
@property(nonatomic, assign) unsigned long long expectedSize;
+ (instancetype)ruleWithBundleID:(NSString *)bundleID
                    relativePath:(NSString *)relativePath
                       sourcePath:(NSString *)sourcePath
                    expectedSize:(unsigned long long)expectedSize
                   expectedSHA256:(nullable NSString *)expectedSHA256;
@end

/// Retorna o caminho do Data Container para um bundle ID.
typedef NSString * _Nullable (^FPContainerResolver)(NSString *bundleID, NSString **errorMessage);

@interface FPPatchTransaction : NSObject
@property(nonatomic, copy, readonly) NSString *transactionID;
@property(nonatomic, copy, readonly) NSString *journalPath;

- (instancetype)initWithBackupRoot:(NSString *)backupRoot
                   containerResolver:(FPContainerResolver)resolver;

/// Aplica todas as regras. Em qualquer falha, desfaz as regras já aplicadas.
- (BOOL)applyRules:(NSArray<FPRule *> *)rules error:(NSString **)errorMessage;

/// Restaura os arquivos originais registrados no journal.
- (BOOL)rollback:(NSString **)errorMessage;
@end

NS_ASSUME_NONNULL_END

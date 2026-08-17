#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Substitui um arquivo usando staging temporário, preservando atributos básicos.
/// Não aceita diretórios, links simbólicos ou o mesmo arquivo como origem/destino.
FOUNDATION_EXPORT BOOL FRSReplaceFile(NSString *sourcePath,
                                       NSString *destinationPath,
                                       NSString * _Nullable expectedSHA256,
                                       NSString * _Nullable * _Nullable errorMessage);

FOUNDATION_EXPORT NSString * _Nullable FRSFileSHA256(NSString *path);
FOUNDATION_EXPORT BOOL FRSValidateRegularFile(NSString *path,
                                               unsigned long long expectedSize,
                                               NSString * _Nullable expectedSHA256,
                                               NSString * _Nullable * _Nullable errorMessage);

NS_ASSUME_NONNULL_END

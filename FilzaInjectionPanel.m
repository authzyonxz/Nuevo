#import "FFH4XKeychain.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>
#import "FFH4XSession.h"
#import "TweakAccess.h"

#pragma mark - Configuração

static NSString * const kTargetBundleID = @"com.dts.freefireth";
static NSString * const kTargetRelativePath =
    @"Documents/ContentCache/compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D";
static NSString * const kAssetName =
    @"assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D";
static NSString * const kNeckResourceDirectory = @"HSNeck.bundle";
static NSString * const kAltoResourceDirectory = @"HSAlto.bundle";
static NSString * const kOriginalResourceDirectory = @"HSOriginal.bundle";
static const unsigned long long kExpectedAssetSize = 46096;
static NSString * const kExpectedAssetSHA256 =
    @"ac8a6db1096a03a2b67a2bff3b9a024553d4f3eb039ee18ba735c6989f41f3df";
static NSString * const kExpectedAltoAssetSHA256 =
    @"7917eb9c3e49d79ff6cbb9d0647573820fd4162759d78d01e63a90d5d4fcffad";
static NSString * const kExpectedOriginalAssetSHA256 =
    @"05d235840319edb6978630d3eeadfe8459cbe4e7349f5963c2cf883d46574929";

static UIView *gPanel;
static UIView *gLoginPanel;
static UILabel *gLoginStatusLabel;
static UITextField *gLoginKeyField;
static UISwitch *gSaveKeySwitch;
static UIButton *gLoginButton;
static UILabel *gLicenseProductValue;
static UILabel *gLicenseStatusValue;
static UILabel *gLicenseExpiryValue;
static UILabel *gLicenseSessionValue;
static UIView *gHomeView;
static UIView *gAccountView;
static UILabel *gStatusLabel;
static UISwitch *gNeckSwitch;
static UISwitch *gAltoSwitch;
static UISwitch *gOriginalSwitch;
static UIButton *gHomeTabButton;
static UIButton *gAccountTabButton;
static id gActionTarget;
static BOOL gOperationRunning = NO;
static NSObject *gOperationLock;
static NSMutableArray<NSString *> *gDiagnosticLines;
static NSString * const kDiagnosticLogNotification = @"FFH4XDiagnosticLogNotification";
static UIColor *PremiumMutedColor(void);
static void SubmitLogin(void);

static NSObject *OperationLock(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ gOperationLock = [NSObject new]; });
    return gOperationLock;
}

static BOOL BeginOperation(void) {
    @synchronized (OperationLock()) {
        if (gOperationRunning) return NO;
        gOperationRunning = YES;
        return YES;
    }
}

static void EndOperation(void) {
    @synchronized (OperationLock()) {
        gOperationRunning = NO;
    }
}

static void AppendDiagnosticLog(NSString *message) {
    NSString *line = message.length > 0 ? message : @"(sem mensagem)";
    NSLog(@"[HS DIAGNOSTIC] %@", line);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!gDiagnosticLines) gDiagnosticLines = [NSMutableArray array];
        NSString *stamp = [NSDateFormatter localizedStringFromDate:NSDate.date
                                                           dateStyle:NSDateFormatterNoStyle
                                                           timeStyle:NSDateFormatterMediumStyle];
        [gDiagnosticLines addObject:[NSString stringWithFormat:@"%@ — %@", stamp, line]];
        while (gDiagnosticLines.count > 8) [gDiagnosticLines removeObjectAtIndex:0];
        if (gStatusLabel) {
            gStatusLabel.text = [gDiagnosticLines componentsJoinedByString:@"\n"];
            gStatusLabel.textColor = PremiumMutedColor();
        }
    });
}

@interface MinimalPanelActionTarget : NSObject
@end

#pragma mark - Utilidades de interface

static UIWindow *CurrentKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState == UISceneActivationStateUnattached) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) return window;
            }
        }
    }

    for (UIWindow *window in UIApplication.sharedApplication.windows) {
        if (window.isKeyWindow) return window;
    }
    return UIApplication.sharedApplication.windows.firstObject;
}

static UIViewController *TopViewController(UIViewController *controller) {
    if (!controller) return nil;
    if (controller.presentedViewController) {
        return TopViewController(controller.presentedViewController);
    }
    if ([controller isKindOfClass:[UINavigationController class]]) {
        return TopViewController(((UINavigationController *)controller).visibleViewController);
    }
    if ([controller isKindOfClass:[UITabBarController class]]) {
        return TopViewController(((UITabBarController *)controller).selectedViewController);
    }
    return controller;
}

static void DismissUnderlyingKeyboard(UIWindow *window) {
    if (!window) return;
    [window endEditing:YES];
    [UIApplication.sharedApplication sendAction:@selector(resignFirstResponder)
                                             to:nil
                                           from:nil
                                       forEvent:nil];
}

static void SetStatus(NSString *status) {
    AppendDiagnosticLog(status ?: @"");
}

static void ShowResultAlert(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *safeMessage = message ?: @"Erro desconhecido.";
        NSString *safeTitle = title ?: @"Status";
        gStatusLabel.text = [NSString stringWithFormat:@"%@\n%@", safeTitle, safeMessage];
        gStatusLabel.textColor = [safeTitle.lowercaseString isEqualToString:@"sucesso"]
            ? [UIColor colorWithRed:0.10 green:0.55 blue:0.30 alpha:1.0]
            : [UIColor colorWithRed:0.78 green:0.18 blue:0.20 alpha:1.0];
        gStatusLabel.backgroundColor = [UIColor colorWithWhite:0.96 alpha:1.0];
        gStatusLabel.layer.cornerRadius = 10.0;
        gStatusLabel.clipsToBounds = YES;
    });
}

#pragma mark - Localização do asset substituto

static NSString *FindReplacementResource(NSString *resourceDirectory,
                                                 NSString *assetName) {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    NSString *relativeAssetPath = [resourceDirectory stringByAppendingPathComponent:assetName];

    NSBundle *classBundle = [NSBundle bundleForClass:[MinimalPanelActionTarget class]];
    NSBundle *mainBundle = NSBundle.mainBundle;
    NSArray<NSString *> *bundleRoots = @[
        classBundle.resourcePath ?: @"",
        mainBundle.resourcePath ?: @""];

    for (NSString *root in bundleRoots) {
        if (root.length > 0) {
            [candidates addObject:[root stringByAppendingPathComponent:relativeAssetPath]];
        }
    }

    if (classBundle.bundlePath) {
        NSString *classDirectory = [classBundle.bundlePath stringByDeletingLastPathComponent];
        [candidates addObject:[classDirectory stringByAppendingPathComponent:relativeAssetPath]];
    }

    // Os dois arquivos mantêm exatamente o mesmo nome; os bundles internos os diferenciam.
    [candidates addObject:[[@"/var/jb/Library/Application Support/FilzaApplySandboxExt"
                             stringByAppendingPathComponent:resourceDirectory]
                             stringByAppendingPathComponent:assetName]];
    [candidates addObject:[[@"/Library/Application Support/FilzaApplySandboxExt"
                             stringByAppendingPathComponent:resourceDirectory]
                             stringByAppendingPathComponent:assetName]];

    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *candidate in candidates) {
        BOOL directory = NO;
        if ([fm fileExistsAtPath:candidate isDirectory:&directory] && !directory) {
            NSLog(@"[HS NECK] Asset %@/%@ encontrado em %@", resourceDirectory, assetName, candidate);
            return candidate;
        }
    }
    return nil;
}

#pragma mark - Localização do Data Container

static NSString *DataContainerFromLaunchServices(NSString *bundleID) {
    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    SEL selector = NSSelectorFromString(@"applicationProxyForIdentifier:");
    if (!proxyClass || ![proxyClass respondsToSelector:selector]) return nil;

    id proxy = ((id (*)(id, SEL, id))objc_msgSend)(proxyClass, selector, bundleID);
    SEL dataSelector = NSSelectorFromString(@"dataContainerURL");
    if (!proxy || ![proxy respondsToSelector:dataSelector]) return nil;

    NSURL *url = ((NSURL *(*)(id, SEL))objc_msgSend)(proxy, dataSelector);
    return [url isKindOfClass:[NSURL class]] ? url.path : nil;
}

static BOOL ContainerHasTargetArea(NSString *container) {
    if (container.length == 0) return NO;
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    NSString *documents = [container stringByAppendingPathComponent:@"Documents"];
    NSString *target = [container stringByAppendingPathComponent:kTargetRelativePath];
    BOOL hasDocuments = [fm fileExistsAtPath:documents isDirectory:&isDirectory] && isDirectory;
    BOOL hasTarget = [fm fileExistsAtPath:target isDirectory:&isDirectory] && !isDirectory;
    return hasDocuments || hasTarget;
}

static NSString *DataContainerFromMetadata(NSString *bundleID) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray<NSString *> *roots = @[
        @"/var/mobile/Containers/Data/Application",
        @"/var/containers/Data/Application",
        @"/private/var/mobile/Containers/Data/Application",
        @"/private/var/containers/Data/Application"
    ];

    for (NSString *root in roots) {
        NSArray<NSString *> *uuids = [fm contentsOfDirectoryAtPath:root error:nil];
        if (uuids.count == 0) continue;
        for (NSString *uuid in uuids) {
            NSString *container = [root stringByAppendingPathComponent:uuid];
            NSString *metadataPath = [container stringByAppendingPathComponent:
                                      @".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *metadata = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
            NSString *identifier = [metadata[@"MCMMetadataIdentifier"] isKindOfClass:[NSString class]]
                ? metadata[@"MCMMetadataIdentifier"] : nil;
            if ([identifier isEqualToString:bundleID] && ContainerHasTargetArea(container)) {
                NSLog(@"[HS NECK] Container encontrado por metadata em %@", container);
                return container;
            }
        }
    }
    return nil;
}

static NSString *DataContainerFromDisplayName(NSString *displayName) {
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultSelector = NSSelectorFromString(@"defaultWorkspace");
    SEL allSelector = NSSelectorFromString(@"allApplications");
    if (!workspaceClass || ![workspaceClass respondsToSelector:defaultSelector]) return nil;

    id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultSelector);
    if (!workspace || ![workspace respondsToSelector:allSelector]) return nil;
    NSArray *applications = ((id (*)(id, SEL))objc_msgSend)(workspace, allSelector);
    for (id proxy in applications) {
        NSString *name = nil;
        SEL nameSelector = NSSelectorFromString(@"localizedName");
        if ([proxy respondsToSelector:nameSelector]) name = ((id (*)(id, SEL))objc_msgSend)(proxy, nameSelector);
        if (![name isKindOfClass:[NSString class]] ||
            [name rangeOfString:displayName options:NSCaseInsensitiveSearch].location == NSNotFound) continue;

        NSURL *url = nil;
        SEL dataSelector = NSSelectorFromString(@"dataContainerURL");
        if ([proxy respondsToSelector:dataSelector]) url = ((NSURL *(*)(id, SEL))objc_msgSend)(proxy, dataSelector);
        NSString *container = [url isKindOfClass:[NSURL class]] ? url.path : nil;
        if (ContainerHasTargetArea(container)) {
            NSLog(@"[HS NECK] Container encontrado pelo nome %@ (%@): %@", name, displayName, container);
            return container;
        }
        NSLog(@"[HS NECK] Aplicativo %@ encontrado, mas sem pasta avatar utilizável.", name);
    }
    return nil;
}

static NSString *FindTargetContainer(void) {
    // 1) Identificador técnico do aplicativo.
    NSLog(@"[HS NECK] Procurando bundle ID: %@", kTargetBundleID);
    NSString *launchServicesContainer = DataContainerFromLaunchServices(kTargetBundleID);
    if (ContainerHasTargetArea(launchServicesContainer)) {
        NSLog(@"[HS NECK] Container encontrado pelo bundle ID: %@", launchServicesContainer);
        return launchServicesContainer;
    }
    NSString *metadataContainer = DataContainerFromMetadata(kTargetBundleID);
    if (metadataContainer.length > 0) return metadataContainer;

    // 2) Nome visível do aplicativo, usado quando o bundle ID varia.
    NSLog(@"[HS NECK] Bundle ID não utilizável; procurando aplicativo: Free Fire");
    NSString *displayNameContainer = DataContainerFromDisplayName(@"Free Fire");
    if (displayNameContainer.length > 0) return displayNameContainer;

    NSLog(@"[HS NECK] Nenhum container utilizável encontrado por %@ ou Free Fire", kTargetBundleID);
    return nil;
}

// Localiza o arquivo somente pelo nome exato dentro do container. O tamanho e
// o SHA-256 são obrigatórios para evitar escolher uma cópia incorreta. O
// caminho interno pode variar entre versões do jogo/iOS.
static NSString *FindExistingTargetFile(NSString *container, NSString *expectedHash) {
    if (container.length == 0 || expectedHash.length == 0) return nil;

    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *avatarPath = [container stringByAppendingPathComponent:
        @"Documents/ContentCache/compulsory/ios/gameassetbundles/avatar"];
    BOOL avatarIsDirectory = NO;
    if (![fm fileExistsAtPath:avatarPath isDirectory:&avatarIsDirectory] || !avatarIsDirectory) {
        NSLog(@"[HS NECK] Pasta avatar não encontrada ou inacessível: %@", avatarPath);
        return nil;
    }
    NSLog(@"[HS NECK] Procurando o asset diretamente em: %@", avatarPath);

    NSURL *documentsURL = [NSURL fileURLWithPath:avatarPath isDirectory:YES];
    NSDirectoryEnumerator<NSURL *> *enumerator =
        [fm enumeratorAtURL:documentsURL
 includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLFileSizeKey]
                    options:NSDirectoryEnumerationSkipsHiddenFiles
               errorHandler:^BOOL(NSURL *url, NSError *error) {
        NSLog(@"[HS NECK] Falha ao percorrer %@: %@", url.path, error.localizedDescription);
        return YES;
    }];

    NSMutableArray<NSString *> *matches = [NSMutableArray array];
    NSUInteger visited = 0;
    for (NSURL *url in enumerator) {
        if (++visited > 100000) {
            NSLog(@"[HS NECK] Busca limitada após 100000 itens.");
            break;
        }
        if (![url.lastPathComponent isEqualToString:kAssetName]) continue;

        NSNumber *fileSize = nil;
        [url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:nil];
        if (fileSize.unsignedLongLongValue != kExpectedAssetSize) {
            NSLog(@"[HS NECK] Nome correto, mas tamanho incorreto em %@: %@ bytes", url.path, fileSize ?: @"desconhecido");
            continue;
        }

        NSString *hash = SHA256File(url.path);
        if (![hash.lowercaseString isEqualToString:expectedHash.lowercaseString]) {
            NSLog(@"[HS NECK] Nome/tamanho corretos, mas hash incorreto em %@: %@", url.path, hash ?: @"indisponível");
            continue;
        }
        [matches addObject:url.path];
    }

    if (matches.count == 1) {
        NSLog(@"[HS NECK] Alvo confirmado por nome+tamanho+SHA256: %@", matches.firstObject);
        return matches.firstObject;
    }
    if (matches.count > 1) {
        NSLog(@"[HS NECK] Mais de um alvo confirmado (%lu); operação cancelada por segurança.", (unsigned long)matches.count);
    } else {
        NSLog(@"[HS NECK] Nenhum arquivo confirmado por nome+tamanho+SHA256 em %@", avatarPath);
    }
    return nil;
}

static NSString *DescribeAvatarDirectory(NSString *container) {
    NSString *avatarPath = [container stringByAppendingPathComponent:
        @"Documents/ContentCache/compulsory/ios/gameassetbundles/avatar"];
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:avatarPath isDirectory:&isDirectory] || !isDirectory) {
        return [NSString stringWithFormat:@"Pasta avatar não encontrada ou inacessível:\n%@", avatarPath];
    }

    NSError *error = nil;
    NSArray<NSString *> *items = [fm contentsOfDirectoryAtPath:avatarPath error:&error];
    if (!items) {
        return [NSString stringWithFormat:@"Não foi possível listar a pasta avatar:\n%@\n\n%@",
                avatarPath, error.localizedDescription ?: @"erro desconhecido"];
    }

    NSMutableArray<NSString *> *relevant = [NSMutableArray array];
    for (NSString *item in items) {
        if ([item rangeOfString:@"assetindexer" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [item rangeOfString:@"H5ak" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [relevant addObject:item];
        }
        if (relevant.count >= 20) break;
    }

    NSString *names = relevant.count > 0
        ? [relevant componentsJoinedByString:@"\n"]
        : @"Nenhum nome contendo assetindexer/H5ak foi encontrado.";
    return [NSString stringWithFormat:@"Pasta conferida:\n%@\n\nItens relevantes:\n%@",
            avatarPath, names];
}

#pragma mark - Validação e substituição

static NSString *SHA256File(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (!data) return nil;

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *result = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }
    return result;
}

static NSString *UniqueSiblingPath(NSString *directory, NSString *prefix) {
    NSString *name = [NSString stringWithFormat:@".%@-%@", prefix, NSUUID.UUID.UUIDString];
    return [directory stringByAppendingPathComponent:name];
}

static BOOL ReplaceTargetDirectly(NSString *sourcePath,
                                  NSString *destinationPath,
                                  NSString *expectedHash,
                                  NSString **errorOut) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;

    if (sourcePath.length == 0) {
        if (errorOut) *errorOut = @"Asset substituto não encontrado.";
        return NO;
    }

    BOOL sourceDirectory = NO;
    if (![fm fileExistsAtPath:sourcePath isDirectory:&sourceDirectory] || sourceDirectory) {
        if (errorOut) *errorOut = [NSString stringWithFormat:@"Asset inválido: %@", sourcePath];
        return NO;
    }

    BOOL destinationDirectory = NO;
    if (![fm fileExistsAtPath:destinationPath isDirectory:&destinationDirectory] || destinationDirectory) {
        if (errorOut) *errorOut = [NSString stringWithFormat:@"Arquivo original não encontrado: %@", destinationPath];
        return NO;
    }

    NSDictionary *sourceAttributes = [fm attributesOfItemAtPath:sourcePath error:&error];
    unsigned long long sourceSize = sourceAttributes.fileSize;
    NSString *sourceHash = SHA256File(sourcePath);
    if (sourceSize != kExpectedAssetSize ||
        ![sourceHash.lowercaseString isEqualToString:expectedHash.lowercaseString]) {
        if (errorOut) {
            *errorOut = [NSString stringWithFormat:
                         @"Asset incorreto. Tamanho=%llu SHA256=%@",
                         sourceSize, sourceHash ?: @"indisponível"];
        }
        return NO;
    }

    // Usa somente um temporário de trabalho. Nenhum backup do original é criado.
    NSString *directory = [destinationPath stringByDeletingLastPathComponent];
    NSString *temporaryPath = UniqueSiblingPath(directory, @"hsneck-temp");
    if (![fm copyItemAtPath:sourcePath toPath:temporaryPath error:&error]) {
        if (errorOut) *errorOut = [NSString stringWithFormat:
                                   @"Não foi possível criar temporário: %@", error.localizedDescription];
        return NO;
    }

    NSDictionary *destinationAttributes = [fm attributesOfItemAtPath:destinationPath error:nil];
    if (destinationAttributes) {
        [fm setAttributes:destinationAttributes ofItemAtPath:temporaryPath error:nil];
    }

    NSURL *destinationURL = [NSURL fileURLWithPath:destinationPath];
    NSURL *temporaryURL = [NSURL fileURLWithPath:temporaryPath];
    BOOL replaced = [fm replaceItemAtURL:destinationURL
                           withItemAtURL:temporaryURL
                          backupItemName:nil
                                 options:0
                        resultingItemURL:nil
                                  error:&error];
    if (!replaced) {
        [fm removeItemAtPath:temporaryPath error:nil];
        if (errorOut) *errorOut = [NSString stringWithFormat:
                                   @"Falha na substituição: %@", error.localizedDescription];
        return NO;
    }

    NSString *resultHash = SHA256File(destinationPath);
    if (![resultHash.lowercaseString isEqualToString:expectedHash.lowercaseString]) {
        if (errorOut) *errorOut = [NSString stringWithFormat:
                                   @"Hash final inválido: %@. Nenhum backup foi criado.",
                                   resultHash ?: @"indisponível"];
        return NO;
    }

    return YES;
}

static void SetFeatureSwitchState(NSString *resourceDirectory, BOOL on) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([resourceDirectory isEqualToString:kNeckResourceDirectory]) {
            [gNeckSwitch setOn:on animated:YES];
        } else if ([resourceDirectory isEqualToString:kAltoResourceDirectory]) {
            [gAltoSwitch setOn:on animated:YES];
        } else if ([resourceDirectory isEqualToString:kOriginalResourceDirectory]) {
            [gOriginalSwitch setOn:on animated:YES];
        }
    });
}

static void SetFeatureButtonsEnabled(BOOL enabled) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gNeckSwitch.enabled = enabled;
        gAltoSwitch.enabled = enabled;
        gOriginalSwitch.enabled = enabled;
    });
}

static BOOL FFH4XOperationAuthorized(void) {
    FFH4XSession *session = [FFH4XSession sharedSession];
    if (!session.isAuthorized) {
        if (gStatusLabel) {
            ShowResultAlert(@"Sessão necessária", @"Valide sua KEY antes de executar esta operação.");
        }
        return NO;
    }
    return YES;
}

static void RunReplacementForAsset(NSString *resourceDirectory,
                                   NSString *expectedHash,
                                   NSString *displayName) {
    AppendDiagnosticLog([NSString stringWithFormat:@"Clique recebido: %@", displayName]);
    AppendDiagnosticLog(@"Destino esperado: Documents/ContentCache/compulsory/ios/gameassetbundles/avatar");
    if (!FFH4XOperationAuthorized()) {
        AppendDiagnosticLog(@"Clique recusado: sessão não autorizada.");
        return;
    }
    if (!BeginOperation()) {
        AppendDiagnosticLog(@"Clique ignorado: já existe uma operação em andamento.");
        return;
    }

#if FFH4X_DIAGNOSTIC_NO_EXPLOIT
    AppendDiagnosticLog(@"DIAGNÓSTICO: clique recebido sem executar exploit/container.");
    EndOperation();
    SetFeatureSwitchState(resourceDirectory, NO);
    SetStatus(@"Diagnóstico concluído: nenhum acesso foi executado.");
    ShowResultAlert(@"Diagnóstico", @"O clique chegou ao callback. Exploit e substituição estão desativados nesta build.");
    SetFeatureButtonsEnabled(YES);
    return;
#endif

    // Desabilita imediatamente para impedir toques repetidos antes do bloco assíncrono.
    gNeckSwitch.enabled = NO;
    gAltoSwitch.enabled = NO;
    gOriginalSwitch.enabled = NO;
    AppendDiagnosticLog([NSString stringWithFormat:@"Iniciando localização de %@...", displayName]);
    dispatch_async(dispatch_get_main_queue(), ^{
        gStatusLabel.text = [NSString stringWithFormat:@"Localizando %@...", displayName];
        SetFeatureButtonsEnabled(NO);
    });

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            NSString *source = FindReplacementResource(resourceDirectory, kAssetName);
            if (!source) {
                AppendDiagnosticLog([NSString stringWithFormat:@"Falha: asset %@ não foi localizado.", displayName]);
                EndOperation();
                SetFeatureSwitchState(resourceDirectory, NO);
                SetStatus([NSString stringWithFormat:@"Asset %@ não encontrado.", displayName]);
                ShowResultAlert(@"Erro", [NSString stringWithFormat:
                    @"O asset de %@ não foi encontrado no pacote final.\n\nNome esperado:\n%@", displayName, kAssetName]);
                SetFeatureButtonsEnabled(YES);
                return;
            }

            AppendDiagnosticLog([NSString stringWithFormat:@"Asset localizado: %@", source]);
            NSString *sandboxError = nil;
            AppendDiagnosticLog(@"Solicitando acesso ao sandbox somente para esta substituição...");
            BOOL sandboxOK = NO;
            @try {
                sandboxOK = FFH4XEnsureSandboxAccess(&sandboxError);
            } @catch (NSException *exception) {
                sandboxError = [NSString stringWithFormat:@"Exceção no acesso: %@ — %@", exception.name, exception.reason ?: @"sem motivo"];
                AppendDiagnosticLog(sandboxError);
            }
            if (!sandboxOK) {
                AppendDiagnosticLog([NSString stringWithFormat:@"Acesso ao sandbox falhou: %@", sandboxError ?: @"erro desconhecido"]);
                EndOperation();
                SetFeatureSwitchState(resourceDirectory, NO);
                SetStatus(@"Acesso ao sandbox indisponível.");
                ShowResultAlert(@"Acesso indisponível", sandboxError ?: @"Não foi possível liberar o acesso ao container.");
                SetFeatureButtonsEnabled(YES);
                return;
            }
            AppendDiagnosticLog(@"Acesso ao sandbox concluído; procurando pasta avatar...");
            NSString *container = FindTargetContainer();
            if (container.length == 0) {
                AppendDiagnosticLog([NSString stringWithFormat:@"Falha: container %@ não encontrado.", kTargetBundleID]);
                EndOperation();
                SetFeatureSwitchState(resourceDirectory, NO);
                SetStatus(@"Data Container não encontrado.");
                ShowResultAlert(@"Erro", [NSString stringWithFormat:
                    @"Não encontrei o Data Container de %@.", kTargetBundleID]);
                SetFeatureButtonsEnabled(YES);
                return;
            }

            AppendDiagnosticLog([NSString stringWithFormat:@"Container selecionado: %@", container]);
            NSString *destination = FindExistingTargetFile(container, expectedHash);
            if (destination.length == 0) {
                AppendDiagnosticLog(@"Falha: arquivo-alvo não encontrado dentro do container.");
                EndOperation();
                SetFeatureSwitchState(resourceDirectory, NO);
                SetStatus(@"Arquivo original não encontrado.");
                NSString *directoryDiagnostic = DescribeAvatarDirectory(container);
                ShowResultAlert(@"Erro", [NSString stringWithFormat:
                    @"%@\n\nContainer usado:\n%@\n\nNome procurado:\n%@\n\n%@",
                    displayName, container, kAssetName, directoryDiagnostic]);
                SetFeatureButtonsEnabled(YES);
                return;
            }

            AppendDiagnosticLog([NSString stringWithFormat:@"Destino localizado: %@", destination]);
            SetStatus([NSString stringWithFormat:@"Aplicando %@...", displayName]);
            NSString *errorMessage = nil;
            BOOL success = NO;
            @try {
                success = ReplaceTargetDirectly(source, destination, expectedHash, &errorMessage);
            } @catch (NSException *exception) {
                errorMessage = [NSString stringWithFormat:@"Exceção %@: %@", exception.name, exception.reason ?: @"sem motivo"];
                AppendDiagnosticLog(errorMessage);
            }
            EndOperation();

            if (!success) {
                AppendDiagnosticLog([NSString stringWithFormat:@"Substituição falhou: %@", errorMessage ?: @"erro desconhecido"]);
                SetFeatureSwitchState(resourceDirectory, NO);
                SetStatus([NSString stringWithFormat:@"Erro em %@.", displayName]);
                ShowResultAlert(@"Erro", errorMessage ?: @"Não foi possível substituir o arquivo.");
                SetFeatureButtonsEnabled(YES);
                return;
            }

            AppendDiagnosticLog([NSString stringWithFormat:@"Substituição concluída: %@", displayName]);
            SetFeatureSwitchState(resourceDirectory, YES);
            SetStatus([NSString stringWithFormat:@"%@ ativado.", displayName]);
            ShowResultAlert(@"Sucesso", [NSString stringWithFormat:@"%@ ativado com sucesso.", displayName]);
            SetFeatureButtonsEnabled(YES);
        }
    });
}

#pragma mark - Interface em tela cheia

static UIColor *PremiumBackgroundColor(void) {
    return [UIColor colorWithWhite:1.0 alpha:1.0];
}

static UIColor *PremiumSurfaceColor(void) {
    return [UIColor colorWithWhite:1.0 alpha:1.0];
}

static UIColor *PremiumElevatedColor(void) {
    return [UIColor colorWithRed:0.955 green:0.965 blue:0.980 alpha:1.0];
}

static UIColor *PremiumBorderColor(void) {
    return [UIColor colorWithRed:0.875 green:0.890 blue:0.920 alpha:1.0];
}

static UIColor *PremiumAccentColor(void) {
    return [UIColor colorWithRed:0.090 green:0.250 blue:0.650 alpha:1.0];
}

static UIColor *PremiumTealColor(void) {
    return [UIColor colorWithRed:0.100 green:0.620 blue:0.420 alpha:1.0];
}

static UIColor *PremiumTextColor(void) {
    return [UIColor colorWithRed:0.080 green:0.100 blue:0.140 alpha:1.0];
}

static UIColor *PremiumMutedColor(void) {
    return [UIColor colorWithRed:0.400 green:0.450 blue:0.540 alpha:1.0];
}

static UILabel *MakeTextLabel(NSString *text, CGFloat size, UIFontWeight weight, UIColor *color) {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

static UIView *MakeCard(NSString *title, UISwitch **switchOut) {
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = PremiumSurfaceColor();
    card.layer.cornerRadius = 16.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = PremiumBorderColor().CGColor;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = 0.08;
    card.layer.shadowRadius = 10.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 4.0);

    UILabel *titleLabel = MakeTextLabel(title, 17.0, UIFontWeightSemibold, PremiumTextColor());
    [card addSubview:titleLabel];

    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    toggle.onTintColor = PremiumTealColor();
    toggle.tintColor = PremiumBorderColor();
    toggle.thumbTintColor = UIColor.whiteColor;
    [card addSubview:toggle];
    if (switchOut) *switchOut = toggle;

    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintGreaterThanOrEqualToConstant:78.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18.0],
        [titleLabel.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-14.0],
        [toggle.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18.0],
        [toggle.centerYAnchor constraintEqualToAnchor:card.centerYAnchor]
    ]];
    return card;
}

static UIView *MakeInfoCard(NSString *title, NSString *value) {
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = PremiumSurfaceColor();
    card.layer.cornerRadius = 16.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = PremiumBorderColor().CGColor;

    UILabel *titleLabel = MakeTextLabel(title, 11.0, UIFontWeightMedium, PremiumMutedColor());
    UILabel *valueLabel = MakeTextLabel(value, 15.0, UIFontWeightSemibold, PremiumTextColor());
    [card addSubview:titleLabel];
    [card addSubview:valueLabel];
    [NSLayoutConstraint activateConstraints:@[
        [card.heightAnchor constraintGreaterThanOrEqualToConstant:66.0],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:12.0],
        [titleLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:14.0],
        [titleLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-14.0],
        [valueLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5.0],
        [valueLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:titleLabel.trailingAnchor],
        [valueLabel.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-12.0]
    ]];
    return card;
}

static UIView *MakeInfoCardWithValue(NSString *title, NSString *value, UILabel **valueOut) {
    UIView *card = MakeInfoCard(title, value);
    if (valueOut) {
        NSArray<UILabel *> *labels = [card.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *object, NSDictionary *bindings) {
            return [object isKindOfClass:[UILabel class]];
        }]];
        UILabel *candidate = labels.lastObject;
        *valueOut = candidate;
    }
    return card;
}

static void UpdateLicenseInfoCards(void) {
    NSDictionary *info = [FFH4XSession sharedSession].licenseInfo;
    if (!info) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        gLicenseProductValue.text = info[@"productName"] ?: info[@"product"] ?: @"ruanwq";
        gLicenseStatusValue.text = info[@"status"] ?: @"active";
        gLicenseExpiryValue.text = info[@"expiresAt"] ?: @"Não informado";
        gLicenseSessionValue.text = info[@"sessionExpiresAt"] ?: @"Sessão ativa";
    });
}

static NSString *DeviceName(void) {
    UIDevice *device = UIDevice.currentDevice;
    return device.name.length > 0 ? device.name : device.model;
}

static NSString *JailbreakStatus(void) {
    NSArray<NSString *> *markers = @[
        @"/var/jb",
        @"/Library/MobileSubstrate/DynamicLibraries",
        @"/usr/lib/libhooker.dylib",
        @"/var/jb/usr/lib/TweakInject"
    ];
    for (NSString *path in markers) {
        if ([NSFileManager.defaultManager fileExistsAtPath:path]) return @"Sim";
    }
    return @"Não identificado";
}

static NSString *BatteryStatus(void) {
    UIDevice *device = UIDevice.currentDevice;
    device.batteryMonitoringEnabled = YES;
    if (device.batteryLevel < 0.0) return @"Indisponível";
    return [NSString stringWithFormat:@"%.0f%%", device.batteryLevel * 100.0];
}

static void SelectTab(BOOL home) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gHomeView.hidden = !home;
        gAccountView.hidden = home;
        gHomeTabButton.backgroundColor = home ? PremiumAccentColor() : PremiumElevatedColor();
        gAccountTabButton.backgroundColor = home ? PremiumElevatedColor() : PremiumAccentColor();
        [gHomeTabButton setTitleColor:home ? PremiumTextColor() : PremiumMutedColor() forState:UIControlStateNormal];
        [gAccountTabButton setTitleColor:home ? PremiumMutedColor() : PremiumTextColor() forState:UIControlStateNormal];
    });
}

@implementation MinimalPanelActionTarget

- (void)showHome:(id)sender {
    SelectTab(YES);
}

- (void)showAccount:(id)sender {
    SelectTab(NO);
}

- (void)showMaxComingSoon:(id)sender {
    ShowResultAlert(@"Erro", @"Free Fire MAX\nEm breve…");
}

- (void)submitLogin:(id)sender {
    SubmitLogin();
}

- (void)toggleNeck:(UISwitch *)sender {
    if (sender.isOn && !FFH4XOperationAuthorized()) {
        [sender setOn:NO animated:YES];
        return;
    }
    if (!sender.isOn) {
        SetStatus(@"HS PESCOÇO desligado.");
        return;
    }
    [gAltoSwitch setOn:NO animated:YES];
    [gOriginalSwitch setOn:NO animated:YES];
    RunReplacementForAsset(kNeckResourceDirectory, kExpectedAssetSHA256, @"HS PESCOÇO");
}

- (void)toggleAlto:(UISwitch *)sender {
    if (sender.isOn && !FFH4XOperationAuthorized()) {
        [sender setOn:NO animated:YES];
        return;
    }
    if (!sender.isOn) {
        SetStatus(@"HS ALTO + PESCOÇO desligado.");
        return;
    }
    [gNeckSwitch setOn:NO animated:YES];
    [gOriginalSwitch setOn:NO animated:YES];
    RunReplacementForAsset(kAltoResourceDirectory, kExpectedAltoAssetSHA256, @"HS ALTO + PESCOÇO");
}

- (void)toggleOriginal:(UISwitch *)sender {
    if (sender.isOn && !FFH4XOperationAuthorized()) {
        [sender setOn:NO animated:YES];
        return;
    }
    if (!sender.isOn) {
        SetStatus(@"ARQUIVO ORIGINAL desligado.");
        return;
    }
    [gNeckSwitch setOn:NO animated:YES];
    [gAltoSwitch setOn:NO animated:YES];
    RunReplacementForAsset(kOriginalResourceDirectory, kExpectedOriginalAssetSHA256, @"ARQUIVO ORIGINAL");
}

@end

static void InstallAuthorizedPanel(void);

static void RemoveLoginPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gLoginPanel removeFromSuperview];
        gLoginPanel = nil;
        gLoginKeyField = nil;
        gLoginStatusLabel = nil;
        gSaveKeySwitch = nil;
        gLoginButton = nil;
    });
}

static void LoginSetStatus(NSString *status, UIColor *color) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gLoginStatusLabel.text = status ?: @"";
        gLoginStatusLabel.textColor = color ?: PremiumMutedColor();
    });
}

static void SubmitLogin(void) {
    NSString *key = [gLoginKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (key.length == 0) {
        LoginSetStatus(@"Informe uma KEY para continuar.", [UIColor colorWithRed:0.78 green:0.18 blue:0.20 alpha:1.0]);
        return;
    }

    gLoginButton.enabled = NO;
    gLoginKeyField.enabled = NO;
    LoginSetStatus(@"Validando KEY com o servidor…", PremiumMutedColor());
    [gLoginKeyField resignFirstResponder];

    BOOL save = gSaveKeySwitch.isOn;
    [[FFH4XSession sharedSession] authenticateKey:key save:save completion:^(BOOL success,
                                                                              NSDictionary * _Nullable licenseInfo,
                                                                              NSString * _Nullable errorCode,
                                                                              NSString * _Nullable errorMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            gLoginButton.enabled = YES;
            gLoginKeyField.enabled = YES;
            if (!success) {
                NSString *message = errorMessage.length > 0 ? errorMessage : @"A KEY não foi aceita.";
                LoginSetStatus([NSString stringWithFormat:@"%@%@", errorCode.length > 0 ? [NSString stringWithFormat:@"[%@] ", errorCode] : @"", message], [UIColor colorWithRed:0.78 green:0.18 blue:0.20 alpha:1.0]);
                return;
            }
            LoginSetStatus(@"KEY autorizada. Abrindo painel…", [UIColor colorWithRed:0.10 green:0.55 blue:0.30 alpha:1.0]);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                RemoveLoginPanel();
                InstallAuthorizedPanel();
            });
        });
    }];
}

static void InstallLoginPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gLoginPanel || gPanel) return;
        UIWindow *window = CurrentKeyWindow();
        if (!window) return;

        DismissUnderlyingKeyboard(window);
        if (!gActionTarget) gActionTarget = [MinimalPanelActionTarget new];
        UIView *panel = [[UIView alloc] initWithFrame:CGRectZero];
        panel.translatesAutoresizingMaskIntoConstraints = NO;
        panel.backgroundColor = PremiumBackgroundColor();
        panel.layer.zPosition = 10000.0;
        gLoginPanel = panel;
        [window addSubview:panel];
        [NSLayoutConstraint activateConstraints:@[
            [panel.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
            [panel.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
            [panel.topAnchor constraintEqualToAnchor:window.topAnchor],
            [panel.bottomAnchor constraintEqualToAnchor:window.bottomAnchor]
        ]];

        UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.backgroundColor = PremiumSurfaceColor();
        card.layer.cornerRadius = 22.0;
        card.layer.borderWidth = 1.0;
        card.layer.borderColor = PremiumBorderColor().CGColor;
        card.layer.shadowColor = UIColor.blackColor.CGColor;
        card.layer.shadowOpacity = 0.12;
        card.layer.shadowRadius = 20.0;
        card.layer.shadowOffset = CGSizeMake(0.0, 8.0);
        [panel addSubview:card];

        UILabel *brand = [[UILabel alloc] initWithFrame:CGRectZero];
        brand.translatesAutoresizingMaskIntoConstraints = NO;
        brand.textAlignment = NSTextAlignmentCenter;
        NSMutableAttributedString *attrTitle = [[NSMutableAttributedString alloc] initWithString:@"PROXY iPA."];
        [attrTitle addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:32.0 weight:UIFontWeightBlack] range:NSMakeRange(0, attrTitle.length)];
        [attrTitle addAttribute:NSForegroundColorAttributeName value:PremiumTextColor() range:NSMakeRange(0, 9)];
        [attrTitle addAttribute:NSForegroundColorAttributeName value:PremiumTealColor() range:NSMakeRange(9, 1)];
        brand.attributedText = attrTitle;
        [card addSubview:brand];
        UILabel *subtitle = MakeTextLabel(@"Acesse o painel com sua KEY", 14.0, UIFontWeightMedium, PremiumMutedColor());
        subtitle.textAlignment = NSTextAlignmentCenter;
        [card addSubview:subtitle];

        UITextField *keyField = [[UITextField alloc] initWithFrame:CGRectZero];
        keyField.translatesAutoresizingMaskIntoConstraints = NO;
        keyField.placeholder = @"Cole ou digite sua KEY";
        keyField.borderStyle = UITextBorderStyleRoundedRect;
        keyField.secureTextEntry = YES;
        keyField.autocorrectionType = UITextAutocorrectionTypeNo;
        keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        keyField.clearButtonMode = UITextFieldViewModeWhileEditing;
        keyField.returnKeyType = UIReturnKeyDone;
        keyField.textContentType = UITextContentTypePassword;
        [keyField addTarget:gActionTarget action:@selector(submitLogin:) forControlEvents:UIControlEventEditingDidEndOnExit];
        [card addSubview:keyField];
        gLoginKeyField = keyField;

        UILabel *saveLabel = MakeTextLabel(@"Salvar KEY neste dispositivo", 14.0, UIFontWeightMedium, PremiumTextColor());
        [card addSubview:saveLabel];
        UISwitch *saveSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        saveSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        saveSwitch.onTintColor = PremiumTealColor();
        saveSwitch.on = YES;
        [card addSubview:saveSwitch];
        gSaveKeySwitch = saveSwitch;

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setTitle:@"CONFIRMAR KEY" forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightBold];
        button.backgroundColor = PremiumAccentColor();
        button.layer.cornerRadius = 14.0;
        [button addTarget:gActionTarget action:@selector(submitLogin:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:button];
        gLoginButton = button;

        UILabel *status = MakeTextLabel(@"", 12.0, UIFontWeightMedium, PremiumMutedColor());
        status.textAlignment = NSTextAlignmentCenter;
        status.numberOfLines = 0;
        [card addSubview:status];
        gLoginStatusLabel = status;

        [NSLayoutConstraint activateConstraints:@[
            [card.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:24.0],
            [card.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-24.0],
            [card.centerYAnchor constraintEqualToAnchor:panel.centerYAnchor],
            [brand.topAnchor constraintEqualToAnchor:card.topAnchor constant:28.0],
            [brand.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20.0],
            [brand.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20.0],
            [subtitle.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:7.0],
            [subtitle.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],
            [subtitle.trailingAnchor constraintEqualToAnchor:brand.trailingAnchor],
            [keyField.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:24.0],
            [keyField.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20.0],
            [keyField.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20.0],
            [keyField.heightAnchor constraintEqualToConstant:48.0],
            [saveLabel.topAnchor constraintEqualToAnchor:keyField.bottomAnchor constant:18.0],
            [saveLabel.leadingAnchor constraintEqualToAnchor:keyField.leadingAnchor],
            [saveLabel.trailingAnchor constraintLessThanOrEqualToAnchor:saveSwitch.leadingAnchor constant:-10.0],
            [saveLabel.centerYAnchor constraintEqualToAnchor:saveSwitch.centerYAnchor],
            [saveSwitch.trailingAnchor constraintEqualToAnchor:keyField.trailingAnchor],
            [saveSwitch.centerYAnchor constraintEqualToAnchor:saveLabel.centerYAnchor],
            [button.topAnchor constraintEqualToAnchor:saveSwitch.bottomAnchor constant:22.0],
            [button.leadingAnchor constraintEqualToAnchor:keyField.leadingAnchor],
            [button.trailingAnchor constraintEqualToAnchor:keyField.trailingAnchor],
            [button.heightAnchor constraintEqualToConstant:50.0],
            [status.topAnchor constraintEqualToAnchor:button.bottomAnchor constant:14.0],
            [status.leadingAnchor constraintEqualToAnchor:keyField.leadingAnchor],
            [status.trailingAnchor constraintEqualToAnchor:keyField.trailingAnchor],
            [status.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-22.0]
        ]];

        // Restauração automática é somente de UI/sessão; não dispara exploit.
        [[FFH4XSession sharedSession] restoreSavedKeyWithCompletion:^(BOOL success,
                                                                        NSDictionary * _Nullable licenseInfo,
                                                                        NSString * _Nullable errorCode,
                                                                        NSString * _Nullable errorMessage) {
            if (success) {
                LoginSetStatus(@"KEY salva autorizada. Abrindo painel…", [UIColor colorWithRed:0.10 green:0.55 blue:0.30 alpha:1.0]);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    RemoveLoginPanel();
                    InstallAuthorizedPanel();
                });
            } else if ([errorCode isEqualToString:@"E_INVALID_KEY"] || [errorCode isEqualToString:@"E_AUTH"]) {
                // Evita repetir uma KEY inválida a cada relançamento.
                r7x_KeychainDeleteLicenseKey();
                LoginSetStatus(@"KEY salva inválida; informe uma nova KEY.", [UIColor systemRedColor]);
                NSLog(@"[FFH4X] saved-key restore rejected: %@", errorMessage ?: errorCode);
            }
        }];
    });
}

static void InstallAuthorizedPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gPanel) return;
        UIWindow *window = CurrentKeyWindow();
        if (!window) return;

        // Remove o foco de campos do Filza antes de mostrar o painel.
        DismissUnderlyingKeyboard(window);

        gActionTarget = [MinimalPanelActionTarget new];
        UIView *panel = [[UIView alloc] initWithFrame:CGRectZero];
        panel.translatesAutoresizingMaskIntoConstraints = NO;
        panel.userInteractionEnabled = YES;
        panel.exclusiveTouch = YES;
        panel.backgroundColor = PremiumBackgroundColor();
        panel.layer.zPosition = 9999.0;
        gPanel = panel;
        [window addSubview:panel];
        [NSLayoutConstraint activateConstraints:@[
            [panel.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
            [panel.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
            [panel.topAnchor constraintEqualToAnchor:window.topAnchor],
            [panel.bottomAnchor constraintEqualToAnchor:window.bottomAnchor]
        ]];

        UIView *header = [[UIView alloc] initWithFrame:CGRectZero];
        header.translatesAutoresizingMaskIntoConstraints = NO;
        [panel addSubview:header];

        UILabel *title = MakeTextLabel(@"PROXY iPA", 25.0, UIFontWeightBold, PremiumTextColor());
        [header addSubview:title];

        [NSLayoutConstraint activateConstraints:@[
            [header.topAnchor constraintEqualToAnchor:panel.safeAreaLayoutGuide.topAnchor constant:18.0],
            [header.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20.0],
            [header.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20.0],
            [title.topAnchor constraintEqualToAnchor:header.topAnchor],
            [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
            [title.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor],
            [title.bottomAnchor constraintEqualToAnchor:header.bottomAnchor]
        ]];

        UIView *bottomBar = [[UIView alloc] initWithFrame:CGRectZero];
        bottomBar.translatesAutoresizingMaskIntoConstraints = NO;
        bottomBar.backgroundColor = PremiumSurfaceColor();
        bottomBar.layer.borderWidth = 1.0;
        bottomBar.layer.borderColor = PremiumBorderColor().CGColor;
        bottomBar.layer.shadowColor = UIColor.blackColor.CGColor;
        bottomBar.layer.shadowOpacity = 0.28;
        bottomBar.layer.shadowRadius = 14.0;
        bottomBar.layer.shadowOffset = CGSizeMake(0.0, -5.0);
        [panel addSubview:bottomBar];

        gHomeTabButton = [UIButton buttonWithType:UIButtonTypeSystem];
        gHomeTabButton.translatesAutoresizingMaskIntoConstraints = NO;
        [gHomeTabButton setTitle:@"HOME" forState:UIControlStateNormal];
        gHomeTabButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        gHomeTabButton.layer.cornerRadius = 11.0;
        [gHomeTabButton addTarget:gActionTarget action:@selector(showHome:) forControlEvents:UIControlEventTouchUpInside];
        [bottomBar addSubview:gHomeTabButton];

        gAccountTabButton = [UIButton buttonWithType:UIButtonTypeSystem];
        gAccountTabButton.translatesAutoresizingMaskIntoConstraints = NO;
        [gAccountTabButton setTitle:@"ACCOUNT" forState:UIControlStateNormal];
        gAccountTabButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        gAccountTabButton.layer.cornerRadius = 11.0;
        [gAccountTabButton addTarget:gActionTarget action:@selector(showAccount:) forControlEvents:UIControlEventTouchUpInside];
        [bottomBar addSubview:gAccountTabButton];

        [NSLayoutConstraint activateConstraints:@[
            [bottomBar.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor],
            [bottomBar.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor],
            [bottomBar.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor],
            [bottomBar.heightAnchor constraintGreaterThanOrEqualToConstant:88.0],
            [gHomeTabButton.leadingAnchor constraintEqualToAnchor:bottomBar.leadingAnchor constant:20.0],
            [gHomeTabButton.topAnchor constraintEqualToAnchor:bottomBar.topAnchor constant:14.0],
            [gHomeTabButton.trailingAnchor constraintEqualToAnchor:bottomBar.centerXAnchor constant:-6.0],
            [gHomeTabButton.heightAnchor constraintEqualToConstant:44.0],
            [gHomeTabButton.bottomAnchor constraintEqualToAnchor:panel.safeAreaLayoutGuide.bottomAnchor constant:-12.0],
            [gAccountTabButton.leadingAnchor constraintEqualToAnchor:bottomBar.centerXAnchor constant:6.0],
            [gAccountTabButton.topAnchor constraintEqualToAnchor:gHomeTabButton.topAnchor],
            [gAccountTabButton.trailingAnchor constraintEqualToAnchor:bottomBar.trailingAnchor constant:-20.0],
            [gAccountTabButton.heightAnchor constraintEqualToConstant:44.0],
            [gAccountTabButton.bottomAnchor constraintEqualToAnchor:gHomeTabButton.bottomAnchor]
        ]];

        UIScrollView *homeScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
        homeScroll.translatesAutoresizingMaskIntoConstraints = NO;
        [panel addSubview:homeScroll];
        gHomeView = homeScroll;

        UIStackView *homeStack = [[UIStackView alloc] initWithFrame:CGRectZero];
        homeStack.translatesAutoresizingMaskIntoConstraints = NO;
        homeStack.axis = UILayoutConstraintAxisVertical;
        homeStack.spacing = 14.0;
        [homeScroll addSubview:homeStack];

        UILabel *gamesTitle = MakeTextLabel(@"JOGO", 11.0, UIFontWeightBold, PremiumMutedColor());
        [homeStack addArrangedSubview:gamesTitle];
        UIStackView *gameRow = [[UIStackView alloc] initWithFrame:CGRectZero];
        gameRow.axis = UILayoutConstraintAxisHorizontal;
        gameRow.spacing = 10.0;
        gameRow.distribution = UIStackViewDistributionFillEqually;
        UIButton *freeFireButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [freeFireButton setTitle:@"Free Fire" forState:UIControlStateNormal];
        freeFireButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        freeFireButton.backgroundColor = PremiumTealColor();
        [freeFireButton setTitleColor:PremiumBackgroundColor() forState:UIControlStateNormal];
        freeFireButton.layer.cornerRadius = 13.0;
        UIButton *freeFireMaxButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [freeFireMaxButton setTitle:@"Free Fire MAX" forState:UIControlStateNormal];
        freeFireMaxButton.titleLabel.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightSemibold];
        freeFireMaxButton.backgroundColor = PremiumElevatedColor();
        [freeFireMaxButton setTitleColor:PremiumMutedColor() forState:UIControlStateNormal];
        freeFireMaxButton.layer.cornerRadius = 13.0;
        freeFireMaxButton.layer.borderWidth = 1.0;
        freeFireMaxButton.layer.borderColor = PremiumBorderColor().CGColor;
        [freeFireMaxButton addTarget:gActionTarget action:@selector(showMaxComingSoon:) forControlEvents:UIControlEventTouchUpInside];
        [gameRow addArrangedSubview:freeFireButton];
        [gameRow addArrangedSubview:freeFireMaxButton];
        [homeStack addArrangedSubview:gameRow];
        [gameRow.heightAnchor constraintEqualToConstant:46.0].active = YES;

        UILabel *featuresTitle = MakeTextLabel(@"RECURSOS", 11.0, UIFontWeightBold, PremiumMutedColor());
        [homeStack addArrangedSubview:featuresTitle];

        UISwitch *neckSwitch = nil;
        UIView *neckCard = MakeCard(@"HS PESCOÇO", &neckSwitch);
        gNeckSwitch = neckSwitch;
        [neckSwitch addTarget:gActionTarget action:@selector(toggleNeck:) forControlEvents:UIControlEventValueChanged];
        [homeStack addArrangedSubview:neckCard];

        UISwitch *altoSwitch = nil;
        UIView *altoCard = MakeCard(@"HS ALTO + PESCOÇO", &altoSwitch);
        gAltoSwitch = altoSwitch;
        [altoSwitch addTarget:gActionTarget action:@selector(toggleAlto:) forControlEvents:UIControlEventValueChanged];
        [homeStack addArrangedSubview:altoCard];

        UISwitch *originalSwitch = nil;
        UIView *originalCard = MakeCard(@"ARQUIVO ORIGINAL", &originalSwitch);
        gOriginalSwitch = originalSwitch;
        [originalSwitch addTarget:gActionTarget action:@selector(toggleOriginal:) forControlEvents:UIControlEventValueChanged];
        [homeStack addArrangedSubview:originalCard];

        NSString *initialDiagnosticText = gDiagnosticLines.count > 0
            ? [gDiagnosticLines componentsJoinedByString:@"\n"]
            : @"Pronto";
        gStatusLabel = MakeTextLabel(initialDiagnosticText, 12.0, UIFontWeightMedium, PremiumMutedColor());
        gStatusLabel.textAlignment = NSTextAlignmentCenter;
        gStatusLabel.layer.cornerRadius = 10.0;
        gStatusLabel.clipsToBounds = YES;
        [homeStack addArrangedSubview:gStatusLabel];

        [NSLayoutConstraint activateConstraints:@[
            [homeScroll.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:18.0],
            [homeScroll.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20.0],
            [homeScroll.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20.0],
            [homeScroll.bottomAnchor constraintEqualToAnchor:bottomBar.topAnchor constant:-14.0],
            [homeStack.topAnchor constraintEqualToAnchor:homeScroll.contentLayoutGuide.topAnchor],
            [homeStack.leadingAnchor constraintEqualToAnchor:homeScroll.contentLayoutGuide.leadingAnchor],
            [homeStack.trailingAnchor constraintEqualToAnchor:homeScroll.contentLayoutGuide.trailingAnchor],
            [homeStack.bottomAnchor constraintEqualToAnchor:homeScroll.contentLayoutGuide.bottomAnchor],
            [homeStack.widthAnchor constraintEqualToAnchor:homeScroll.frameLayoutGuide.widthAnchor]
        ]];

        UIView *account = [[UIView alloc] initWithFrame:CGRectZero];
        account.translatesAutoresizingMaskIntoConstraints = NO;
        account.hidden = YES;
        [panel addSubview:account];
        gAccountView = account;
        UIScrollView *accountScroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
        accountScroll.translatesAutoresizingMaskIntoConstraints = NO;
        [account addSubview:accountScroll];
        UIStackView *accountStack = [[UIStackView alloc] initWithFrame:CGRectZero];
        accountStack.translatesAutoresizingMaskIntoConstraints = NO;
        accountStack.axis = UILayoutConstraintAxisVertical;
        accountStack.spacing = 10.0;
        [accountScroll addSubview:accountStack];
        [accountStack addArrangedSubview:MakeInfoCardWithValue(@"Produto", @"ruanwq", &gLicenseProductValue)];
        [accountStack addArrangedSubview:MakeInfoCardWithValue(@"Status", @"Não autorizado", &gLicenseStatusValue)];
        [accountStack addArrangedSubview:MakeInfoCardWithValue(@"Expiração da KEY", @"Não informado", &gLicenseExpiryValue)];
        [accountStack addArrangedSubview:MakeInfoCardWithValue(@"Expiração da sessão", @"Aguardando", &gLicenseSessionValue)];
        [accountStack addArrangedSubview:MakeInfoCard(@"Dispositivo", DeviceName())];
        [accountStack addArrangedSubview:MakeInfoCard(@"Versão", UIDevice.currentDevice.systemVersion)];
        [accountStack addArrangedSubview:MakeInfoCard(@"Jailbreak", JailbreakStatus())];
        [accountStack addArrangedSubview:MakeInfoCard(@"Bateria", BatteryStatus())];
        [NSLayoutConstraint activateConstraints:@[
            [account.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:18.0],
            [account.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20.0],
            [account.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20.0],
            [account.bottomAnchor constraintEqualToAnchor:bottomBar.topAnchor constant:-14.0],
            [accountScroll.topAnchor constraintEqualToAnchor:account.topAnchor],
            [accountScroll.leadingAnchor constraintEqualToAnchor:account.leadingAnchor],
            [accountScroll.trailingAnchor constraintEqualToAnchor:account.trailingAnchor],
            [accountScroll.bottomAnchor constraintEqualToAnchor:account.bottomAnchor],
            [accountStack.topAnchor constraintEqualToAnchor:accountScroll.contentLayoutGuide.topAnchor],
            [accountStack.leadingAnchor constraintEqualToAnchor:accountScroll.contentLayoutGuide.leadingAnchor],
            [accountStack.trailingAnchor constraintEqualToAnchor:accountScroll.contentLayoutGuide.trailingAnchor],
            [accountStack.bottomAnchor constraintEqualToAnchor:accountScroll.contentLayoutGuide.bottomAnchor],
            [accountStack.widthAnchor constraintEqualToAnchor:accountScroll.frameLayoutGuide.widthAnchor]
        ]];

        SelectTab(YES);
        UpdateLicenseInfoCards();
    });
}

static void LockAuthorizedPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [gPanel removeFromSuperview];
        gPanel = nil;
        gHomeView = nil;
        gAccountView = nil;
        gStatusLabel = nil;
        gNeckSwitch = nil;
        gAltoSwitch = nil;
        gOriginalSwitch = nil;
        InstallLoginPanel();
    });
}

__attribute__((constructor)) static void MinimalPanelInit(void) {
    [[NSNotificationCenter defaultCenter]
        addObserverForName:kDiagnosticLogNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
        AppendDiagnosticLog([note.object isKindOfClass:[NSString class]] ? note.object : @"log recebido");
    }];
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
        InstallLoginPanel();
    }];
    [[NSNotificationCenter defaultCenter]
        addObserverForName:FFH4XSessionDidInvalidateNotification
                  object:nil
                   queue:[NSOperationQueue mainQueue]
              usingBlock:^(NSNotification *note) {
        LockAuthorizedPanel();
    }];
}

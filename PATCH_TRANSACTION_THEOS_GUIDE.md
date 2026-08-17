# PatchTransaction e FileReplacementService no Theos

## Arquivos adicionados

A adaptação está nos arquivos `FileReplacementService.h/.m` e `PatchTransaction.h/.m`. O `Makefile` já inclui os dois `.m` no tweak.

`FileReplacementService` faz a substituição de um único arquivo. Ele rejeita diretórios e links simbólicos, valida o SHA-256 opcional da origem, cria um staging no mesmo diretório do destino, preserva permissões/proteção, usa `replaceItemAtURL:` e valida o hash final.

`FPPatchTransaction` coordena várias regras. Cada regra possui bundle ID, caminho relativo, arquivo de origem, tamanho esperado e SHA-256 esperado. O resolvedor de container é fornecido pelo seu código atual, permitindo continuar usando `FFH4XEnsureSandboxAccess` e as rotinas de container já existentes.

## Exemplo de integração

```objc
#import "PatchTransaction.h"

NSString *backupRoot = [NSTemporaryDirectory() stringByAppendingPathComponent:@"3105-backups"];

FPPatchTransaction *transaction = [[FPPatchTransaction alloc]
    initWithBackupRoot:backupRoot
    containerResolver:^NSString *(NSString *bundleID, NSString **errorMessage) {
        // Substitua por sua função real de resolução.
        NSString *container = ResolveContainerForBundleID(bundleID, errorMessage);
        return container;
    }];

NSString *source = [[NSBundle bundleForClass:self.class]
    pathForResource:@"assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
             ofType:nil
        inDirectory:@"HSNeck.bundle"];

FPRule *rule = [FPRule ruleWithBundleID:@"com.dts.freefireth"
                          relativePath:@"Documents/ContentCache/compulsory/ios/gameassetbundles/avatar/assetindexer.H5ak1JM1Eck~2FxRcJrEp~2FMzeuqmY~3D"
                             sourcePath:source
                          expectedSize:46096
                         expectedSHA256:@"ac8a6db1096a03a2b67a2bff3b9a024553d4f3eb039ee18ba735c6989f41f3df"];

NSString *error = nil;
if (![transaction applyRules:@[rule] error:&error]) {
    NSLog(@"[3105] patch falhou: %@", error);
}
```

## Regras de segurança importantes

O `relativePath` deve sempre ser relativo ao Data Container, sem `/` inicial, sem `..`, sem `.` isolado, sem `\\` e sem symlinks. A implementação valida que o destino final permanece dentro do container resolvido. Não passe um UUID de container como bundle ID.

A transação faz backup antes da escrita e registra um journal em plist. Se uma regra posterior falhar, as regras anteriores são restauradas automaticamente. Para uma ação explícita de restauração, mantenha o objeto da transação ou carregue o journal conforme a política do seu app.

O serviço não executa exploit e não resolve o container sozinho. Ele deve ser chamado somente depois de o seu fluxo confirmar que o acesso ao sandbox está disponível. Isso evita iniciar operações de baixo nível ao abrir a tela de login.

## Observação sobre o nome `Free Fire`

O bundle ID é a identidade técnica correta. O nome exibido `Free Fire` pode ser usado apenas como fallback para descobrir o bundle ID; as regras devem continuar registrando o bundle ID resolvido e não o nome visível.

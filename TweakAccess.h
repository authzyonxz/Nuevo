#ifndef TWEAK_ACCESS_H
#define TWEAK_ACCESS_H

#import <Foundation/Foundation.h>

// Solicita acesso ampliado somente durante uma operação iniciada pelo usuário.
// Retorna NO sem encerrar o processo do Filza.
BOOL FFH4XEnsureSandboxAccess(NSString **errorMessage);

#endif

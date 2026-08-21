#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import "../Include/GameOffsets.h"

// Esta versão é configurada como uma Dylib que roda DENTRO do jogo
// para garantir que as funções de memória funcionem nativamente.

__attribute__((constructor)) static void initialize_mod() {
    NSLog(@"[FF-MAX-MOD] Dylib injetada e rodando no processo: %@", [[NSProcessInfo processInfo] processName]);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[FF-MAX-MOD] Inicializando patches de memória via offsets...");
        // Exemplo de ativação automática ao injetar
        // Aqui você pode adicionar a lógica de menu flutuante ImGui
    });
}

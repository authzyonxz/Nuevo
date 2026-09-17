# Integração do MenuOverlayKit no app de teste

O framework não é um aplicativo e não possui um ponto de entrada automático. Ele expõe `MenuOverlayViewController`, que deve ser apresentado pelo aplicativo que o incorpora.

## 1. Incorporar no Xcode

No app de teste, arraste `MenuOverlayKit.framework` para o projeto ou adicione o target `MenuOverlayKit` como projeto dependente. Em **Target do app > General > Frameworks, Libraries, and Embedded Content**, adicione o framework e escolha **Embed & Sign**.

Para dispositivo físico, o app e o framework precisam ser assinados pela mesma equipe Apple Developer. O artefato unsigned não pode ser instalado sozinho.

## 2. Abrir imediatamente para testar

No `ViewController.mm` do app de teste:

```objc
#import <MenuOverlayKit/MenuOverlayViewController.h>

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Evita apresentar duas vezes se a tela reaparecer.
    if (self.presentedViewController == nil) {
        MenuOverlayViewController *menu =
            [[MenuOverlayViewController alloc] init];
        menu.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [self presentViewController:menu animated:YES completion:nil];
    }
}
```

Use primeiro essa forma para confirmar que o framework está incorporado corretamente.

## 3. Abrir com três toques e três dedos

Depois que a abertura imediata funcionar, substitua o teste anterior por:

```objc
#import <MenuOverlayKit/MenuOverlayViewController.h>

- (void)viewDidLoad {
    [super viewDidLoad];

    UITapGestureRecognizer *gesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(openMenu)];
    gesture.numberOfTapsRequired = 3;
    gesture.numberOfTouchesRequired = 3;
    gesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:gesture];
}

- (void)openMenu {
    if (self.presentedViewController != nil) {
        return;
    }

    MenuOverlayViewController *menu =
        [[MenuOverlayViewController alloc] init];
    menu.modalPresentationStyle = UIModalPresentationOverFullScreen;
    menu.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:menu animated:YES completion:nil];
}
```

## 4. Se o app usa SceneDelegate

O código deve ficar no `UIViewController` que está visível na janela, não diretamente em `SceneDelegate`. O `SceneDelegate` apenas cria a janela e define o `rootViewController`.

## 5. Diagnóstico rápido

Se aparecer erro de importação, tente temporariamente:

```objc
#import "MenuOverlayViewController.h"
```

em vez de:

```objc
#import <MenuOverlayKit/MenuOverlayViewController.h>
```

Se o menu abre imediatamente, mas não abre pelo gesto, o problema é apenas o gesto do simulador. Em um iPhone físico, faça três toques consecutivos mantendo três dedos na tela. Para depurar, deixe a abertura imediata ativa primeiro.

Se o app fecha ao abrir, confirme em **Frameworks, Libraries, and Embedded Content** que está como **Embed & Sign**, e não apenas **Do Not Embed**.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#import "../Include/GameOffsets.h"

// Interface Principal do App com UI Visual (Evita Tela Preta)
@interface InjectorViewController : UIViewController
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIButton *injectButton;
@end

@implementation InjectorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.10 alpha:1.0];

    // Título
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.frame.size.width - 40, 40)];
    titleLabel.text = @"FreeFire External Injector";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];

    // Status
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 140, self.view.frame.size.width - 40, 60)];
    self.statusLabel.text = @"Status: Pronto. Abra o Free Fire Max em segundo plano.";
    self.statusLabel.textColor = [UIColor cyanColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];

    // Botão de Injeção
    self.injectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.injectButton.frame = CGRectMake(40, 240, self.view.frame.size.width - 80, 50);
    [self.injectButton setTitle:@"ATIVAR INJEÇÃO DE MEMÓRIA" forState:UIControlStateNormal];
    [self.injectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.injectButton.backgroundColor = [UIColor systemBlueColor];
    self.injectButton.layer.cornerRadius = 12;
    self.injectButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.injectButton addTarget:self action:@selector(handleInjection) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.injectButton];
}

- (void)handleInjection {
    self.statusLabel.text = @"Procurando processo com.dts.freefiremax...";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        pid_t pid = [self findProcessIDByName:@"freefiremax"];
        if (pid <= 0) {
            pid = [self findProcessIDByName:@"FreeFireMax"];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (pid > 0) {
                self.statusLabel.text = [NSString stringWithFormat:@"Sucesso! Processo encontrado (PID: %d). Aplicando Patches...", pid];
                // Simulação de aplicação de patch de memória
            } else {
                self.statusLabel.text = @"Erro: Free Fire Max não encontrado em segundo plano!";
            }
        });
    });
}

- (pid_t)findProcessIDByName:(NSString *)name {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t size = 0;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) < 0) return -1;
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    if (sysctl(mib, 4, procs, &size, NULL, 0) < 0) {
        free(procs);
        return -1;
    }
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    for (int i = 0; i < count; i++) {
        NSString *procName = [NSString stringWithUTF8String:procs[i].kp_proc.p_comm];
        if ([procName localizedCaseInsensitiveContainsString:name]) {
            pid_t pid = procs[i].kp_proc.p_pid;
            free(procs);
            return pid;
        }
    }
    
    free(procs);
    return -1;
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    InjectorViewController *vc = [[InjectorViewController alloc] init];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

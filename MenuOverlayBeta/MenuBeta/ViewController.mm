#import "ViewController.h"

@interface BetaOverlayMenuController : UIViewController
@end

@implementation BetaOverlayMenuController {
    UIView *_panel;
    UISegmentedControl *_tabs;
    UIStackView *_controls;
    UILabel *_status;
}

- (UIColor *)panelColor { return [UIColor colorWithWhite:0.055 alpha:0.98]; }
- (UIColor *)cardColor { return [UIColor colorWithWhite:0.10 alpha:1.0]; }
- (UIColor *)accentColor { return [UIColor colorWithRed:0.10 green:0.52 blue:0.95 alpha:1.0]; }

- (UILabel *)label:(NSString *)text size:(CGFloat)size color:(UIColor *)color weight:(UIFontWeight)weight {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.textColor = color;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.numberOfLines = 1;
    return label;
}

- (UIButton *)iconButton:(NSString *)symbol action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [button setTintColor:[UIColor colorWithWhite:0.85 alpha:1.0]];
    button.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1.0];
    button.layer.cornerRadius = 16;
    [button.widthAnchor constraintEqualToConstant:32].active = YES;
    [button.heightAnchor constraintEqualToConstant:32].active = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)switchRow:(NSString *)title subtitle:(NSString *)subtitle {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [self cardColor];
    row.layer.cornerRadius = 11;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *name = [self label:title size:15 color:UIColor.whiteColor weight:UIFontWeightSemibold];
    UILabel *detail = [self label:subtitle size:11 color:[UIColor colorWithWhite:0.52 alpha:1.0] weight:UIFontWeightRegular];
    UIStackView *texts = [[UIStackView alloc] initWithArrangedSubviews:@[name, detail]];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 3;
    texts.translatesAutoresizingMaskIntoConstraints = NO;
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = NO;
    toggle.onTintColor = [self accentColor];
    toggle.translatesAutoresizingMaskIntoConstraints = NO;
    [toggle addTarget:self action:@selector(controlChanged:) forControlEvents:UIControlEventValueChanged];
    [row addSubview:texts];
    [row addSubview:toggle];
    [NSLayoutConstraint activateConstraints:@[
        [texts.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:13],
        [texts.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [toggle.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [toggle.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [texts.trailingAnchor constraintLessThanOrEqualToAnchor:toggle.leadingAnchor constant:-8],
        [row.heightAnchor constraintEqualToConstant:57]
    ]];
    return row;
}

- (UIView *)sliderRow {
    UIView *row = [[UIView alloc] init];
    row.backgroundColor = [self cardColor];
    row.layer.cornerRadius = 11;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *title = [self label:@"Intensidade visual" size:14 color:UIColor.whiteColor weight:UIFontWeightSemibold];
    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = 0;
    slider.maximumValue = 100;
    slider.value = 35;
    slider.minimumTrackTintColor = [self accentColor];
    slider.maximumTrackTintColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    UILabel *value = [self label:@"35" size:12 color:UIColor.whiteColor weight:UIFontWeightBold];
    value.textAlignment = NSTextAlignmentCenter;
    value.backgroundColor = [self accentColor];
    value.layer.cornerRadius = 10;
    value.layer.masksToBounds = YES;
    value.translatesAutoresizingMaskIntoConstraints = NO;
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:title]; [row addSubview:slider]; [row addSubview:value];
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:row.topAnchor constant:10],
        [title.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:13],
        [value.topAnchor constraintEqualToAnchor:row.topAnchor constant:8],
        [value.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],
        [value.widthAnchor constraintEqualToConstant:48],
        [value.heightAnchor constraintEqualToConstant:22],
        [slider.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:10],
        [slider.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-10],
        [slider.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-5],
        [row.heightAnchor constraintEqualToConstant:72]
    ]];
    return row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.72];
    self.modalPresentationCapturesStatusBarAppearance = YES;

    _panel = [[UIView alloc] init];
    _panel.backgroundColor = [self panelColor];
    _panel.layer.cornerRadius = 18;
    _panel.layer.borderWidth = 1;
    _panel.layer.borderColor = [UIColor colorWithWhite:0.22 alpha:1.0].CGColor;
    _panel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_panel];
    [NSLayoutConstraint activateConstraints:@[
        [_panel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:62],
        [_panel.widthAnchor constraintLessThanOrEqualToConstant:345],
        [_panel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_panel.topAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:28],
        [_panel.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-28],
        [_panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-20]
    ]];

    UIStackView *root = [[UIStackView alloc] init];
    root.axis = UILayoutConstraintAxisVertical;
    root.spacing = 10;
    root.layoutMargins = UIEdgeInsetsMake(12, 12, 12, 12);
    root.layoutMarginsRelativeArrangement = YES;
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [_panel addSubview:root];
    [NSLayoutConstraint activateConstraints:@[
        [root.topAnchor constraintEqualToAnchor:_panel.topAnchor], [root.leadingAnchor constraintEqualToAnchor:_panel.leadingAnchor],
        [root.trailingAnchor constraintEqualToAnchor:_panel.trailingAnchor], [root.bottomAnchor constraintEqualToAnchor:_panel.bottomAnchor]
    ]];

    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[[self iconButton:@"arrow.down" action:@selector(downloadTapped:)]]];
    header.axis = UILayoutConstraintAxisHorizontal;
    header.alignment = UIStackViewAlignmentCenter;
    UILabel *brand = [self label:@"BETA MENU" size:16 color:UIColor.whiteColor weight:UIFontWeightBold];
    brand.textAlignment = NSTextAlignmentCenter;
    [header insertArrangedSubview:brand atIndex:1];
    UIButton *close = [self iconButton:@"xmark" action:@selector(closeTapped:)];
    [header addArrangedSubview:close];
    [header setCustomSpacing:8 afterView:header.arrangedSubviews.firstObject];
    [header setCustomSpacing:8 afterView:brand];
    [root addArrangedSubview:header];

    _tabs = [[UISegmentedControl alloc] initWithItems:@[@"Visual", @"Controles", @"Misc"]];
    _tabs.selectedSegmentIndex = 0;
    _tabs.selectedSegmentTintColor = [self accentColor];
    [_tabs setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.6 alpha:1.0]} forState:UIControlStateNormal];
    [_tabs setTitleTextAttributes:@{NSForegroundColorAttributeName: UIColor.whiteColor} forState:UIControlStateSelected];
    [_tabs addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
    [root addArrangedSubview:_tabs];

    _controls = [[UIStackView alloc] init];
    _controls.axis = UILayoutConstraintAxisVertical;
    _controls.spacing = 8;
    [root addArrangedSubview:_controls];
    [self showVisualControls];
    _status = [self label:@"Pronto — modo demonstração" size:11 color:[UIColor colorWithWhite:0.52 alpha:1.0] weight:UIFontWeightRegular];
    _status.textAlignment = NSTextAlignmentCenter;
    [root addArrangedSubview:_status];
}

- (void)clearControls { for (UIView *view in _controls.arrangedSubviews) { [_controls removeArrangedSubview:view]; [view removeFromSuperview]; } }
- (void)showVisualControls {
    [self clearControls];
    [_controls addArrangedSubview:[self switchRow:@"Mostrar indicadores" subtitle:@"Exibe elementos de diagnóstico"]];
    [_controls addArrangedSubview:[self switchRow:@"Realçar área ativa" subtitle:@"Destaque visual do painel"]];
    [_controls addArrangedSubview:[self sliderRow]];
}
- (void)showControlControls {
    [self clearControls];
    [_controls addArrangedSubview:[self switchRow:@"Toque de teste" subtitle:@"Ativa feedback visual"]];
    [_controls addArrangedSubview:[self switchRow:@"Modo compacto" subtitle:@"Reduz o tamanho do painel"]];
    [_controls addArrangedSubview:[self sliderRow]];
}
- (void)showMiscControls {
    [self clearControls];
    [_controls addArrangedSubview:[self switchRow:@"Animações" subtitle:@"Transições do menu"]];
    [_controls addArrangedSubview:[self switchRow:@"Logs de demonstração" subtitle:@"Mostra eventos no status"]];
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:@"Restaurar padrão" forState:UIControlStateNormal];
    [reset setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    reset.backgroundColor = [UIColor colorWithWhite:0.16 alpha:1.0];
    reset.layer.cornerRadius = 10;
    reset.contentEdgeInsets = UIEdgeInsetsMake(12, 12, 12, 12);
    [reset addTarget:self action:@selector(resetTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_controls addArrangedSubview:reset];
}

- (void)tabChanged:(UISegmentedControl *)sender { if (sender.selectedSegmentIndex == 0) [self showVisualControls]; else if (sender.selectedSegmentIndex == 1) [self showControlControls]; else [self showMiscControls]; _status.text = @"Aba alterada — modo demonstração"; }
- (void)controlChanged:(UISwitch *)sender { _status.text = sender.isOn ? @"Opção ativada" : @"Opção desativada"; }
- (void)sliderChanged:(UISlider *)sender { _status.text = [NSString stringWithFormat:@"Intensidade: %.0f", sender.value]; }
- (void)resetTapped:(UIButton *)sender { _status.text = @"Configurações restauradas"; }
- (void)downloadTapped:(UIButton *)sender { _status.text = @"Ação de teste executada"; }
- (void)closeTapped:(UIButton *)sender { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

@implementation ViewController {
    BOOL _menuVisible;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
    hint.text = @"Toque 3 vezes com 3 dedos\npara abrir o menu beta";
    hint.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 2;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:hint];
    [NSLayoutConstraint activateConstraints:@[
        [hint.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor], [hint.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [hint.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24], [hint.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24]
    ]];
    UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMenu:)];
    gesture.numberOfTapsRequired = 3;
    gesture.numberOfTouchesRequired = 3;
    gesture.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:gesture];
}

- (void)toggleMenu:(UITapGestureRecognizer *)sender { if (sender.state == UIGestureRecognizerStateRecognized) { _menuVisible ? [self closeMenu] : [self openMenu]; } }
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_menuVisible && self.presentedViewController == nil) {
        [self openMenu];
    }
}
- (void)openMenu {
    _menuVisible = YES;
    BetaOverlayMenuController *menu = [[BetaOverlayMenuController alloc] init];
    menu.modalPresentationStyle = UIModalPresentationOverFullScreen;
    menu.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:menu animated:YES completion:nil];
}
- (void)closeMenu { _menuVisible = NO; [self dismissViewControllerAnimated:YES completion:nil]; }
@end

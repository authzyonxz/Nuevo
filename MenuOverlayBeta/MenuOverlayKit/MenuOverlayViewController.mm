#import "MenuOverlayViewController.h"

@interface MenuOverlayViewController ()
@property(nonatomic,strong) UIStackView *controls;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UISegmentedControl *tabs;
@end

@implementation MenuOverlayViewController

- (UIColor *)card { return [UIColor colorWithWhite:0.10 alpha:1]; }
- (UIColor *)blue { return [UIColor colorWithRed:0.10 green:0.52 blue:0.95 alpha:1]; }
- (UILabel *)label:(NSString *)text size:(CGFloat)size color:(UIColor *)color weight:(UIFontWeight)weight {
    UILabel *l=[UILabel new]; l.text=text; l.textColor=color; l.font=[UIFont systemFontOfSize:size weight:weight]; return l;
}
- (UIButton *)button:(NSString *)symbol action:(SEL)action {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; [b setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal]; b.tintColor=UIColor.whiteColor; b.backgroundColor=[UIColor colorWithWhite:.16 alpha:1]; b.layer.cornerRadius=16; [b.widthAnchor constraintEqualToConstant:32].active=YES; [b.heightAnchor constraintEqualToConstant:32].active=YES; [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside]; return b;
}
- (UIView *)switchRow:(NSString *)title detail:(NSString *)detail {
    UIView *row=[UIView new]; row.backgroundColor=[self card]; row.layer.cornerRadius=11; row.translatesAutoresizingMaskIntoConstraints=NO;
    UIStackView *texts=[[UIStackView alloc] initWithArrangedSubviews:@[[self label:title size:15 color:UIColor.whiteColor weight:UIFontWeightSemibold],[self label:detail size:11 color:[UIColor colorWithWhite:.55 alpha:1] weight:UIFontWeightRegular]]]; texts.axis=UILayoutConstraintAxisVertical; texts.spacing=3; texts.translatesAutoresizingMaskIntoConstraints=NO;
    UISwitch *sw=[UISwitch new]; sw.onTintColor=[self blue]; sw.translatesAutoresizingMaskIntoConstraints=NO; [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged]; [row addSubview:texts]; [row addSubview:sw];
    [NSLayoutConstraint activateConstraints:@[[texts.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:13],[texts.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],[sw.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-12],[sw.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],[texts.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-8],[row.heightAnchor constraintEqualToConstant:57]]]; return row;
}
- (void)viewDidLoad {
    [super viewDidLoad]; self.view.backgroundColor=[UIColor colorWithWhite:0 alpha:.72];
    UIView *panel=[UIView new]; panel.backgroundColor=[UIColor colorWithWhite:.055 alpha:.98]; panel.layer.cornerRadius=18; panel.layer.borderWidth=1; panel.layer.borderColor=[UIColor colorWithWhite:.22 alpha:1].CGColor; panel.translatesAutoresizingMaskIntoConstraints=NO; [self.view addSubview:panel];
    [NSLayoutConstraint activateConstraints:@[[panel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:42],[panel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],[panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[panel.widthAnchor constraintLessThanOrEqualToConstant:360]]];
    UIStackView *root=[UIStackView new]; root.axis=UILayoutConstraintAxisVertical; root.spacing=10; root.layoutMargins=UIEdgeInsetsMake(12,12,12,12); root.layoutMarginsRelativeArrangement=YES; root.translatesAutoresizingMaskIntoConstraints=NO; [panel addSubview:root]; [NSLayoutConstraint activateConstraints:@[[root.topAnchor constraintEqualToAnchor:panel.topAnchor],[root.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor],[root.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor],[root.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor]]];
    UIStackView *header=[[UIStackView alloc] initWithArrangedSubviews:@[[self button:@"arrow.down" action:@selector(testAction:)],[self label:@"BETA MENU" size:16 color:UIColor.whiteColor weight:UIFontWeightBold],[self button:@"xmark" action:@selector(close)]]]; header.axis=UILayoutConstraintAxisHorizontal; header.alignment=UIStackViewAlignmentCenter; header.distribution=UIStackViewDistributionEqualCentering; [root addArrangedSubview:header];
    self.tabs=[[UISegmentedControl alloc] initWithItems:@[@"Visual",@"Controles",@"Misc"]]; self.tabs.selectedSegmentIndex=0; self.tabs.selectedSegmentTintColor=[self blue]; [self.tabs addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged]; [root addArrangedSubview:self.tabs];
    self.controls=[UIStackView new]; self.controls.axis=UILayoutConstraintAxisVertical; self.controls.spacing=8; [root addArrangedSubview:self.controls]; [self showControls];
    self.status=[self label:@"Pronto — modo demonstração" size:11 color:[UIColor colorWithWhite:.55 alpha:1] weight:UIFontWeightRegular]; self.status.textAlignment=NSTextAlignmentCenter; [root addArrangedSubview:self.status];
}
- (void)clear { for (UIView *v in self.controls.arrangedSubviews) { [self.controls removeArrangedSubview:v]; [v removeFromSuperview]; } }
- (void)showControls { [self clear]; [self.controls addArrangedSubview:[self switchRow:@"Mostrar indicadores" detail:@"Elementos de diagnóstico"]]; [self.controls addArrangedSubview:[self switchRow:@"Realçar área ativa" detail:@"Destaque visual do painel"]]; UISlider *slider=[UISlider new]; slider.value=.35; slider.minimumTrackTintColor=[self blue]; [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged]; [self.controls addArrangedSubview:slider]; }
- (void)tabChanged:(UISegmentedControl *)s { [self showControls]; self.status.text=[NSString stringWithFormat:@"Aba %@ selecionada",[s titleForSegmentAtIndex:s.selectedSegmentIndex]]; }
- (void)switchChanged:(UISwitch *)s { self.status.text=s.isOn?@"Opção ativada":@"Opção desativada"; }
- (void)sliderChanged:(UISlider *)s { self.status.text=[NSString stringWithFormat:@"Intensidade: %.0f%%",s.value*100]; }
- (void)testAction:(id)sender { self.status.text=@"Ação de teste executada"; }
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

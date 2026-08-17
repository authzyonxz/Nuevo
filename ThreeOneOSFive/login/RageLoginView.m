#import "RageLoginView.h"
#import "RageLicenseState.h"
#import <Security/Security.h>
#import <stdlib.h>

static NSString * const kRageAPIURL = @"https://ffh4xcorporation.online/api/validate-key";
static NSString * const kRageProduct = @"ruanwq";
static NSString * const kRageKeychainService = @"com.ffh4x.rage.license";
static NSString * const kRageKeychainAccount = @"saved-key";
static NSString * const kRageDeviceAccount = @"device-id";

static UIColor *RageColor(NSInteger hex, CGFloat alpha) {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:alpha];
}

@interface RageLoginView () <UITextFieldDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UIView *formView;
@property (nonatomic, strong) UIView *successView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *successTitleLabel;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UISwitch *saveSwitch;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIActivityIndicatorView *activity;
@property (nonatomic, copy) RageLoginCompletion completion;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, strong) NSTimer *shutdownTimer;
@property (nonatomic, assign) NSInteger shutdownRemaining;
@end

static NSString *RageKeychainRead(NSString *account) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kRageKeychainService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return nil;
    NSData *data = (__bridge_transfer NSData *)result;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static void RageKeychainSave(NSString *value, NSString *account) {
    if (value.length == 0) return;
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kRageKeychainService,
        (__bridge id)kSecAttrAccount: account
    };
    SecItemDelete((__bridge CFDictionaryRef)query);
    NSDictionary *item = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: kRageKeychainService,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    };
    SecItemAdd((__bridge CFDictionaryRef)item, NULL);
}

static NSString *RageDeviceID(void) {
    NSString *stored = RageKeychainRead(kRageDeviceAccount);
    if (stored.length > 0) return stored;
    NSString *identifier = [UIDevice currentDevice].identifierForVendor.UUIDString.lowercaseString;
    if (identifier.length == 0) identifier = [NSUUID UUID].UUIDString.lowercaseString;
    RageKeychainSave(identifier, kRageDeviceAccount);
    return identifier;
}

static NSString *RageStringValue(NSDictionary *json, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = json[key];
        if ([value isKindOfClass:NSString.class] && [value length] > 0) return value;
        if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    }
    return @"—";
}

@interface RageLoginView (Layout)
- (void)buildInterface;
- (void)layoutInterface;
@end

@implementation RageLoginView

+ (instancetype)presentInWindow:(UIWindow *)window completion:(RageLoginCompletion)completion {
    if (!window) return nil;
    RageLoginView *view = [[self alloc] initWithFrame:window.bounds];
    view.completion = completion;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [window addSubview:view];
    [view buildInterface];
    [view layoutInterface];
    return view;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = RageColor(0x07070B, 0.98);
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChange:) name:UIKeyboardWillChangeFrameNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [self cancelShutdownCountdown];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildInterface {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self addSubview:self.scrollView];

    self.cardView = [[UIView alloc] initWithFrame:CGRectZero];
    self.cardView.backgroundColor = RageColor(0x111118, 1.0);
    self.cardView.layer.cornerRadius = 22.0;
    self.cardView.layer.borderWidth = 1.0;
    self.cardView.layer.borderColor = RageColor(0x5C142D, 1.0).CGColor;
    self.cardView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.cardView.layer.shadowOpacity = 0.4;
    self.cardView.layer.shadowRadius = 20.0;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 10);
    [self.scrollView addSubview:self.cardView];

    self.formView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.cardView addSubview:self.formView];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = @"IPA FF";
    self.titleLabel.textColor = UIColor.whiteColor;
    self.titleLabel.font = [UIFont systemFontOfSize:27 weight:UIFontWeightBlack];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.formView addSubview:self.titleLabel];

    self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.subtitleLabel.text = @"Insira sua KEY para continuar";
    self.subtitleLabel.textColor = RageColor(0xA9A9B6, 1.0);
    self.subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.formView addSubview:self.subtitleLabel];

    UILabel *keyCaption = [[UILabel alloc] initWithFrame:CGRectZero];
    keyCaption.text = @"KEY DE ACESSO";
    keyCaption.textColor = RageColor(0xE43D67, 1.0);
    keyCaption.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    [self.formView addSubview:keyCaption];

    self.keyField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.keyField.backgroundColor = RageColor(0x1B1B25, 1.0);
    self.keyField.layer.cornerRadius = 12.0;
    self.keyField.layer.borderWidth = 1.0;
    self.keyField.layer.borderColor = RageColor(0x383846, 1.0).CGColor;
    self.keyField.textColor = UIColor.whiteColor;
    self.keyField.tintColor = RageColor(0xF13F6B, 1.0);
    self.keyField.font = [UIFont fontWithName:@"Menlo" size:15] ?: [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    self.keyField.placeholder = @"Cole sua KEY aqui";
    self.keyField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"Cole sua KEY aqui" attributes:@{NSForegroundColorAttributeName: RageColor(0x666674, 1.0)}];
    self.keyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    self.keyField.leftViewMode = UITextFieldViewModeAlways;
    self.keyField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 14, 1)];
    self.keyField.rightViewMode = UITextFieldViewModeAlways;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.spellCheckingType = UITextSpellCheckingTypeNo;
    self.keyField.secureTextEntry = YES;
    // textContentType removido para compatibilidade
    self.keyField.returnKeyType = UIReturnKeyDone;
    self.keyField.delegate = self;
    [self.keyField addTarget:self action:@selector(keyFieldChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.formView addSubview:self.keyField];

    self.saveSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.saveSwitch.onTintColor = RageColor(0xE43D67, 1.0);
    self.saveSwitch.on = YES;
    [self.formView addSubview:self.saveSwitch];

    UILabel *saveLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    saveLabel.text = @"Salvar KEY neste dispositivo";
    saveLabel.textColor = RageColor(0xB8B8C5, 1.0);
    saveLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.formView addSubview:saveLabel];

    self.confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.confirmButton.backgroundColor = RageColor(0xE43D67, 1.0);
    self.confirmButton.layer.cornerRadius = 12.0;
    self.confirmButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self.confirmButton setTitle:@"CONFIRMAR KEY" forState:UIControlStateNormal];
    [self.confirmButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.confirmButton addTarget:self action:@selector(confirmKey:) forControlEvents:UIControlEventTouchUpInside];
    [self.formView addSubview:self.confirmButton];

    self.activity = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activity.hidesWhenStopped = YES;
    [self.confirmButton addSubview:self.activity];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.textColor = RageColor(0xFF829D, 1.0);
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [self.formView addSubview:self.statusLabel];

    self.successView = [[UIView alloc] initWithFrame:CGRectZero];
    self.successView.hidden = YES;
    [self.cardView addSubview:self.successView];
    [self buildSuccessInterface];

    NSString *savedKey = RageKeychainRead(kRageKeychainAccount);
    if (savedKey.length > 0) {
        self.keyField.text = savedKey;
        self.statusLabel.text = @"KEY salva encontrada. Confirme para validar.";
    } else {
        [self startShutdownCountdown];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkClipboardForKey];
        });
    }
}

- (void)buildSuccessInterface {
    self.successTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.successTitleLabel.text = @"ACESSO LIBERADO";
    self.successTitleLabel.textColor = RageColor(0x52E39A, 1.0);
    self.successTitleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBlack];
    self.successTitleLabel.textAlignment = NSTextAlignmentCenter;
    [self.successView addSubview:self.successTitleLabel];

    UILabel *check = [[UILabel alloc] initWithFrame:CGRectZero];
    check.text = @"✓";
    check.textColor = RageColor(0x52E39A, 1.0);
    check.font = [UIFont systemFontOfSize:44 weight:UIFontWeightBold];
    check.textAlignment = NSTextAlignmentCenter;
    [self.successView addSubview:check];

    NSArray<NSString *> *captions = @[@"PRODUTO", @"STATUS", @"EXPIRA EM", @"DISPOSITIVO"];
    for (NSUInteger i = 0; i < captions.count; i++) {
        UILabel *caption = [[UILabel alloc] initWithFrame:CGRectZero];
        caption.tag = 200 + i;
        caption.text = captions[i];
        caption.textColor = RageColor(0x858595, 1.0);
        caption.font = [UIFont systemFontOfSize:10 weight:UIFontWeightBold];
        [self.successView addSubview:caption];

        UILabel *value = [[UILabel alloc] initWithFrame:CGRectZero];
        value.tag = 300 + i;
        value.text = @"—";
        value.textColor = UIColor.whiteColor;
        value.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        value.textAlignment = NSTextAlignmentRight;
        value.adjustsFontSizeToFitWidth = YES;
        [self.successView addSubview:value];
    }
}

- (void)layoutInterface {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat cardWidth = MIN(350.0, MAX(280.0, width - 36.0));
    CGFloat cardHeight = 356.0;
    CGFloat cardX = (width - cardWidth) / 2.0;
    CGFloat cardY = MAX(22.0, (height - cardHeight) / 2.0);
    self.cardView.frame = CGRectMake(cardX, cardY, cardWidth, cardHeight);
    self.formView.frame = self.cardView.bounds;
    self.successView.frame = self.cardView.bounds;

    self.titleLabel.frame = CGRectMake(18, 24, cardWidth - 36, 34);
    self.subtitleLabel.frame = CGRectMake(18, 62, cardWidth - 36, 22);

    UILabel *caption = [self.formView.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *obj, NSDictionary *_) { return [obj isKindOfClass:UILabel.class] && [((UILabel *)obj).text isEqualToString:@"KEY DE ACESSO"]; }]].firstObject;
    caption.frame = CGRectMake(22, 106, cardWidth - 44, 18);
    self.keyField.frame = CGRectMake(20, 128, cardWidth - 40, 46);
    self.saveSwitch.frame = CGRectMake(cardWidth - 68, 190, 48, 30);

    UILabel *saveLabel = [self.formView.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *obj, NSDictionary *_) { return [obj isKindOfClass:UILabel.class] && [((UILabel *)obj).text isEqualToString:@"Salvar KEY neste dispositivo"]; }]].firstObject;
    saveLabel.frame = CGRectMake(22, 194, cardWidth - 100, 22);
    self.confirmButton.frame = CGRectMake(20, 238, cardWidth - 40, 48);
    self.activity.center = CGPointMake(CGRectGetWidth(self.confirmButton.bounds) - 25, CGRectGetMidY(self.confirmButton.bounds));
    self.statusLabel.frame = CGRectMake(22, 296, cardWidth - 44, 36);

    self.successTitleLabel.frame = CGRectMake(20, 28, cardWidth - 40, 34);
    UILabel *check = [self.successView.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *obj, NSDictionary *_) { return [obj isKindOfClass:UILabel.class] && [((UILabel *)obj).text isEqualToString:@"✓"]; }]].firstObject;
    check.frame = CGRectMake(20, 62, cardWidth - 40, 54);
    for (NSUInteger i = 0; i < 4; i++) {
        UILabel *label = [self.successView viewWithTag:200 + i];
        UILabel *value = [self.successView viewWithTag:300 + i];
        CGFloat y = 135 + (i * 42);
        label.frame = CGRectMake(22, y, 110, 18);
        value.frame = CGRectMake(125, y, cardWidth - 147, 18);
    }

    self.scrollView.contentSize = CGSizeMake(width, MAX(height, cardY + cardHeight + 24));
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layoutInterface];
}

- (void)confirmKey:(id)sender {
    if (self.isLoading) return;
    [self cancelShutdownCountdown];
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (key.length < 4) {
        self.statusLabel.text = @"Insira uma KEY válida.";
        self.keyField.layer.borderColor = RageColor(0xFF4D70, 1.0).CGColor;
        [self.keyField becomeFirstResponder];
        return;
    }

    self.isLoading = YES;
    self.statusLabel.text = @"Validando sua KEY...";
    self.keyField.layer.borderColor = RageColor(0x383846, 1.0).CGColor;
    self.confirmButton.enabled = NO;
    self.confirmButton.alpha = 0.72;
    [self.activity startAnimating];
    [self.keyField resignFirstResponder];

    NSDictionary *body = @{ @"key": key, @"deviceId": RageDeviceID(), @"product": kRageProduct };
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSURL *url = [NSURL URLWithString:kRageAPIURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 20.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    request.HTTPBody = bodyData;

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.isLoading = NO;
            self.confirmButton.enabled = YES;
            self.confirmButton.alpha = 1.0;
            [self.activity stopAnimating];

            NSDictionary *json = nil;
            if (data) {
                id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([object isKindOfClass:NSDictionary.class]) json = object;
            }
            BOOL valid = [json[@"valid"] respondsToSelector:@selector(boolValue)] && [json[@"valid"] boolValue];
            NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
            if (error || !json || statusCode < 200 || statusCode >= 300 || !valid) {
                NSString *message = RageStringValue(json ?: @{}, @[@"error", @"message", @"reason"]);
                if (message.length == 0 || [message isEqualToString:@"—"]) message = @"Não foi possível validar a KEY.";
                self.statusLabel.text = message;
                self.keyField.layer.borderColor = RageColor(0xFF4D70, 1.0).CGColor;
                return;
            }

            if (self.saveSwitch.isOn) RageKeychainSave(key, kRageKeychainAccount);
            else {
                NSDictionary *query = @{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrService: kRageKeychainService, (__bridge id)kSecAttrAccount: kRageKeychainAccount };
                SecItemDelete((__bridge CFDictionaryRef)query);
            }
            r7x_Store_4c(json);
            r7x_StoreKey_7p(key);
            r7x_Start_3m();
            [self showSuccess:json];
            if (self.completion) self.completion(json);
        });
    }];
    [task resume];
}

- (void)showSuccess:(NSDictionary *)json {
    [self cancelShutdownCountdown];
    self.formView.hidden = YES;
    self.successView.hidden = NO;
    self.cardView.layer.borderColor = RageColor(0x216A4C, 1.0).CGColor;
    self.cardView.frame = CGRectMake(self.cardView.frame.origin.x, self.cardView.frame.origin.y, self.cardView.frame.size.width, 356.0);

    NSArray<NSString *> *values = @[
        RageStringValue(json, @[@"productName", @"product"]),
        RageStringValue(json, @[@"status"]),
        RageStringValue(json, @[@"expiresAt", @"expiry", @"expires"]),
        RageDeviceID()
    ];
    for (NSUInteger i = 0; i < values.count; i++) {
        UILabel *value = [self.successView viewWithTag:300 + i];
        value.text = values[i];
    }
    [self layoutInterface];
}

- (void)checkClipboardForKey {
    if (self.isLoading || !self.successView.hidden || self.keyField.text.length > 0) return;
    UIPasteboard *pasteboard = UIPasteboard.generalPasteboard;
    if (!pasteboard.hasStrings) return;
    NSString *clipboardKey = [pasteboard.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clipboardKey.length < 4) return;
    [self cancelShutdownCountdown];
    self.keyField.text = clipboardKey;
    [self keyFieldChanged:self.keyField];
    [self confirmKey:nil];
}

- (void)keyFieldChanged:(UITextField *)textField {
    if (textField.text.length > 0) {
        [self cancelShutdownCountdown];
        if (!self.isLoading) self.statusLabel.text = @"Confirme sua KEY para continuar.";
    } else if (!self.isLoading && self.successView.hidden) {
        [self startShutdownCountdown];
    }
}

- (void)startShutdownCountdown {
    [self cancelShutdownCountdown];
    self.shutdownRemaining = 10;
    self.shutdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(shutdownCountdownTick:) userInfo:nil repeats:YES];
    self.statusLabel.text = @"Insira sua KEY. Fechando em 10 segundos.";
}

- (void)cancelShutdownCountdown {
    [self.shutdownTimer invalidate];
    self.shutdownTimer = nil;
}

- (void)shutdownCountdownTick:(NSTimer *)timer {
    if (self.isLoading || self.successView.hidden == NO || self.keyField.text.length > 0) {
        [self cancelShutdownCountdown];
        return;
    }
    self.shutdownRemaining -= 1;
    if (self.shutdownRemaining <= 0) {
        [self cancelShutdownCountdown];
        exit(0);
        return;
    }
    self.statusLabel.text = [NSString stringWithFormat:@"Insira sua KEY. Fechando em %ld segundos.", (long)self.shutdownRemaining];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self confirmKey:nil];
    return YES;
}

- (void)keyboardWillChange:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    CGRect endFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrame = [self convertRect:endFrame fromView:nil];
    CGFloat overlap = MAX(0.0, CGRectGetMaxY(self.bounds) - CGRectGetMinY(keyboardFrame));
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = ([info[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16) | UIViewAnimationOptionBeginFromCurrentState;
    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = overlap + 18.0;
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        CGRect fieldRect = [self.scrollView convertRect:self.keyField.frame fromView:self.keyField.superview];
        [self.scrollView scrollRectToVisible:fieldRect animated:NO];
    } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *info = notification.userInfo;
    NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationOptions options = ([info[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16) | UIViewAnimationOptionBeginFromCurrentState;
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        self.scrollView.contentInset = UIEdgeInsetsZero;
        self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
    } completion:nil];
}

@end

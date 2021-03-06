//
//  HybirdWebVC.m
//  HybirdApp
//
//  Created by long on 2017/7/28.
//  Copyright © 2017年 LongLJ. All rights reserved.
//

#import "HybirdWebVC.h"
#import "JSBridgeInteraction.h"
#import "JSBridgeWebConfig.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <Masonry/Masonry.h>
#import "UIBarButtonItem+Auxiliary.h"
#import "HybirdWebView.h"

#define IOS9_OR_LATER ([[[UIDevice currentDevice] systemVersion] integerValue] >= 9)

typedef NS_ENUM(NSInteger ,HybirdBackItemStyle) {
    HybirdBackItemStyleBack,        // 返回按钮为箭头模式
    HybirdBackItemStyleClose,       // 返回按钮为关闭模式
    HybirdBackItemStyleBackAndClose,// 返回按钮为箭头和关闭双模式
    HybirdBackItemStyleNone,        // 不显示返回按钮
};

@interface HybirdWebVC ()<HybirdWebViewDelegate,
                            HybirdWebViewInteractionDelegate>
/// webView的主体
@property (nonatomic, strong) HybirdWebView *hybirdWebView;
/// webView交互的自定义方法主体
@property (nonatomic, strong) JSBridgeInteraction *interactionSubject;
/// 返回按钮模式
@property (nonatomic, assign) HybirdBackItemStyle style;
/// 加载HTML专用属性
@property (nonatomic, strong) NSString *HTMLString;
@property (nonatomic, strong) NSURL *baseURL;
@end

@implementation HybirdWebVC

- (void)dealloc
{
    if (self.hybirdWebView != nil) {
        [self.hybirdWebView clear];
    }

//    [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                    name:WAP_LOGIN_SUCCESS_NOTICE_NAME
//                                                  object:nil];
}

#pragma mark
#pragma mark - 子类自定义方法(必须实现)
- (NSString *)packageBridgeURL:(NSString *)webURLString
{
    return webURLString;
}

- (NSDictionary *)subTitleBarItemAttribute
{
    return nil;
}


#pragma mark
#pragma mark - Get/Set
- (void)setNavigationBarHidden:(BOOL)navigationBarHidden
{
    _navigationBarHidden = navigationBarHidden;
    //隐藏导航栏
    if (navigationBarHidden) {
        if (@available(iOS 11.0, *)) {
            WKWebView *webView = (WKWebView *)self.hybirdWebView.currentWebView;
            webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        }else{
            self.edgesForExtendedLayout = UIRectEdgeNone;
        }
    }
    [self.navigationController setNavigationBarHidden:navigationBarHidden animated:NO];
}

#pragma mark
#pragma mark - ViewLife
- (void)loadView
{
    CGRect mainFrame = [UIScreen mainScreen].bounds;
    UIView *rootView = [[UIView alloc] initWithFrame:mainFrame];
    rootView.backgroundColor = [UIColor whiteColor];
    self.view = rootView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.URLEncodeType = HybirdURLEncodeTypeNone;
    self.isRefresh = YES;
    self.isRefreshCurrentURL = NO;
    self.usingWebKitCore = YES;
    _navigationBarHidden = NO;

    [self layoutCreatWebView];

    //自定义导航栏按钮
    UIBarButtonItem *backItem = [self backBarItem];
    self.style = HybirdBackItemStyleBack;
    self.navigationItem.leftBarButtonItems = @[backItem];
    
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(handleSessionForRefresh)
//                                                 name:WAP_LOGIN_SUCCESS_NOTICE_NAME
//                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.navigationController setToolbarHidden:YES animated:YES];
    [self setNavigationBarHidden:self.navigationBarHidden];
    
    if (self.isRefresh) {
        self.isRefresh = NO;
        if (self.HTMLString != nil) {
            [self.hybirdWebView refreshHTMLString:self.HTMLString baseURL:self.baseURL];
        }else{
            [self refreshEntranceURL];
        }
    }
    if (self.isRefreshCurrentURL) {
        self.isRefreshCurrentURL = NO;
        if (self.HTMLString != nil) {
            [self.hybirdWebView reload];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)layoutCreatWebView
{
    HybirdWebView *webView = [[HybirdWebView alloc] initWithUseUIWebView:!self.usingWebKitCore];
    webView.backgroundColor = [UIColor clearColor];
    webView.delegate = self;
    webView.interactionType = HybirdWebInteractionTypeJavaScript;
    webView.interactionDelegate = self;
    webView.activeCookieURL = [NSURL URLWithString:self.activeCookieURL];
    self.hybirdWebView = webView;
    [self.view addSubview:webView];
    [webView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view);
        make.top.equalTo(self.view);
        make.size.equalTo(self.view);
    }];
}

#pragma mark
#pragma mark - 通知
- (void)handleSessionForRefresh
{
    //重新登录后刷新当前页面
    if (self.hybirdWebView.currentURL != nil) {
        NSString *currentRequestURL = [self.hybirdWebView.currentURL absoluteString];
        [self layoutCreatWebView];
        [self refreshURLRequest:currentRequestURL];
    }else{
        [self refreshEntranceURL];
    }
}



#pragma mark
#pragma mark - 内部接口
//刷新进入Hybird的URL
- (void)refreshEntranceURL
{
    if (self.webURL != nil && ![self.webURL isEqualToString:@""]) {
        [self refreshURLRequest:self.webURL];
    }
}

- (void)refreshURLRequest:(NSString *)webURLString
{
    NSString *refreshURL = [self packageBridgeURL:webURLString];
    [self.hybirdWebView refreshCurrentURLString:[self requestURLEncode:refreshURL]];
}

- (NSString *)requestURLEncode:(NSString *)refreshURL {
    if (self.URLEncodeType == HybirdURLEncodeTypeAdd) {
        if (IOS9_OR_LATER) {
            refreshURL = [refreshURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        }else{
            refreshURL = [refreshURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }else if (self.URLEncodeType == HybirdURLEncodeTypeRemove) {
        if (IOS9_OR_LATER) {
            refreshURL = [refreshURL stringByRemovingPercentEncoding];
        }else{
            refreshURL = [refreshURL stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        }
    }
    return refreshURL;
}

- (UIBarButtonItem *)backBarItem
{
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(0, 0, 24, 44);
    backBtn.imageEdgeInsets = UIEdgeInsetsMake(13.0 , 0.0 , 13.0 , 13);
    [backBtn setImage:[UIImage imageNamed:JSBridgeNavBackBarImage]
             forState:UIControlStateNormal];
    [backBtn addTarget:self
                action:@selector(backClicked:)
      forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:backBtn];

    return backItem;
}

- (UIBarButtonItem *)closeBarItem
{
    UIBarButtonItem *closeItem = [[UIBarButtonItem  alloc] initWithTitle:nil
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(closeClicked:)];
    closeItem.imageInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    [closeItem setImage:[[UIImage imageNamed:JSBridgeNavCloseBarImage]
                      imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
    return closeItem;
}

#pragma mark
#pragma mark - 外部接口
- (UIBarButtonItem *)barItemForTitle:(id)itemTitle auxiliary:(id)auxiliary
{
    UIBarButtonItem *barItem = nil;
    if (itemTitle != nil) {
        if ([itemTitle isKindOfClass:[NSString class]]) {
            barItem = [[UIBarButtonItem alloc] initWithTitle:itemTitle
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(handleSubTitleClciked:)];
            barItem.auxiliaryObject = auxiliary;
            if ([self subTitleBarItemAttribute]) {
                [barItem setTitleTextAttributes:[self subTitleBarItemAttribute]
                                       forState:UIControlStateNormal];
            }
            
        }else if ([itemTitle isKindOfClass:[UIImage class]]){
            barItem = [[UIBarButtonItem alloc] initWithTitle:nil
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(handleSubTitleClciked:)];
            barItem.auxiliaryObject = auxiliary;
            [barItem setImage:[itemTitle imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal]];
        }
    }
    return barItem;
}

- (void)reloadBackBarItemShowBack:(BOOL)showBack
                        showClose:(BOOL)showClose
                   closeAuxiliary:(id)closeAuxiliary
{
    NSInteger style = HybirdBackItemStyleBack;
    if (showBack && !showClose) {
        style = HybirdBackItemStyleBack;
    }else if (showBack && showClose){
        style = HybirdBackItemStyleBackAndClose;
    }else if (!showBack && showClose){
        style = HybirdBackItemStyleClose;
    }else{
        style = HybirdBackItemStyleNone;
    }

    if (self.style != style) {
        self.style = style;
        switch (style) {
            case HybirdBackItemStyleNone:
            {
                self.navigationItem.leftBarButtonItems = nil;
            }
                break;
            case HybirdBackItemStyleClose:
            {
                UIBarButtonItem *closeItem = [self closeBarItem];
                closeItem.auxiliaryObject = closeAuxiliary;
                self.navigationItem.leftBarButtonItems = @[closeItem];
            }
                break;
            case HybirdBackItemStyleBackAndClose:
            {
                UIBarButtonItem *backItem = [self backBarItem];
                UIBarButtonItem *closeItem = [self closeBarItem];
                closeItem.auxiliaryObject = closeAuxiliary;
                self.navigationItem.leftBarButtonItems = @[backItem,closeItem];
            }
                break;
            case HybirdBackItemStyleBack:
            {
                UIBarButtonItem *backItem = [self backBarItem];
                self.navigationItem.leftBarButtonItems = @[backItem];
            }
                break;
            default:
                break;
        }
    }
}


- (void)evaluateWebJavaScript:(NSString *)JSString
{
    [self.hybirdWebView evaluateWebJavaScript:JSString
                                 evaluateType:HybirdWebEvaluateTypeJSContext
                                   completion:nil];
}

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL
{
    if (string != nil) {
        self.HTMLString = string;
        self.baseURL = nil;
        self.webURL = nil;
        self.isUseInteraction = YES;
        if (self.hybirdWebView != nil) {
            [self.hybirdWebView refreshHTMLString:string baseURL:URL];
        }
    }
}

- (NSString *)currentWebURL
{
    if (self.hybirdWebView.currentURL != nil) {
        return  self.hybirdWebView.currentURL.absoluteString;
    }
    return nil;
}

#pragma mark
#pragma mark - 返回Action
- (void)backClicked:(id)sender
{
    if (self.hybirdWebView.isLoading) {
        [self.navigationController popViewControllerAnimated:YES];
    }else{
        [self.hybirdWebView evaluateWebJavaScript:JSBridgeTriggerGoBack
                                     evaluateType:HybirdWebEvaluateTypeJSContext
                                       completion:^(id JSResult) {
                                           if ([JSResult isEqual:[NSNull null]]) {
                                               if([self.hybirdWebView goWebBack] == NO){
                                                   [self.navigationController popViewControllerAnimated:YES];
                                               }
                                           }
                                       }];
    }
}

- (void)closeClicked:(id)sender
{
    if ([self.hybirdWebView isLoading]) {
        [self.navigationController popViewControllerAnimated:YES];
    }else{
        UIBarButtonItem *clickedItem = (UIBarButtonItem *)sender;
        NSString *goCloseEventText;
        if (clickedItem.auxiliaryObject != nil) {
            if ([NSJSONSerialization isValidJSONObject:clickedItem.auxiliaryObject]) {
                NSData *auxiliaryJSONData = [NSJSONSerialization dataWithJSONObject:clickedItem.auxiliaryObject
                                                                            options:NSJSONWritingPrettyPrinted
                                                                              error:nil];
                NSString *auxiliaryJSONString = [[NSString alloc] initWithData:auxiliaryJSONData encoding:NSUTF8StringEncoding];
                auxiliaryJSONString = [auxiliaryJSONString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                goCloseEventText = [NSString stringWithFormat:JSBridgeTriggerCloseEventWithArge,auxiliaryJSONString];
            }
        }else{
            goCloseEventText = [NSString stringWithFormat:JSBridgeTriggerCloseEvent];
        }

        [self.hybirdWebView evaluateWebJavaScript:goCloseEventText
                                     evaluateType:HybirdWebEvaluateTypeTradition
                                       completion:nil];
    }
}


#pragma mark
#pragma mark - 副标题点击Action
- (void)handleSubTitleClciked:(id)sender
{
    UIBarButtonItem *clickedItem = (UIBarButtonItem *)sender;
    NSString *subTitleEventText;
    if (clickedItem.auxiliaryObject != nil) {
        if ([NSJSONSerialization isValidJSONObject:clickedItem.auxiliaryObject]) {
            NSData *auxiliaryJSONData = [NSJSONSerialization dataWithJSONObject:clickedItem.auxiliaryObject
                                                                        options:NSJSONWritingPrettyPrinted
                                                                          error:nil];
            NSString *auxiliaryJSONString = [[NSString alloc] initWithData:auxiliaryJSONData encoding:NSUTF8StringEncoding];
            auxiliaryJSONString = [auxiliaryJSONString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
            subTitleEventText = [NSString stringWithFormat:JSBridgeTriggerSubTitleEventWithArge,auxiliaryJSONString];
        }
    }else{
        subTitleEventText = [NSString stringWithFormat:JSBridgeTriggerSubTitleEvent];
    }

    [self.hybirdWebView evaluateWebJavaScript:subTitleEventText
                                 evaluateType:HybirdWebEvaluateTypeTradition
                                   completion:nil];
}

#pragma mark
#pragma mark - HybirdWebViewDelegate
- (void)hybirdWebView:(HybirdWebView *)webView didFinishLoadingURL:(NSURL *)URL
{
    [self evaluateWebJavaScript:JSBridgeTriggerLoaded];
}

- (void)hybirdWebView:(HybirdWebView *)webView didStartLoadingURL:(NSURL *)URL
{
    if (webView.isUsingUIWebView == NO) {
        if ([[URL.absoluteString lowercaseString] rangeOfString:@"tel"].length > 0) {
            UIWebView *telWebView = [[UIWebView alloc] init];
            [telWebView loadRequest:[NSURLRequest requestWithURL:URL]];
            [self.view addSubview:telWebView];
        }
    }
}

#pragma mark
#pragma mark - HybirdWebViewInteractionDelegate
- (void)hybirdWebViewDidRegisterJSCallAction:(HybirdWebView *)webView
{
    if (self.isUseInteraction) {
        JSContext *hybirdContext = [webView.currentWebView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
        if (hybirdContext != nil) {
            __weak typeof(self) weakSelf = self;
            if (weakSelf.interactionSubject == nil) {
                JSBridgeInteraction *interaction = [[JSBridgeInteraction alloc] init];
                interaction.currentVC = weakSelf;
                weakSelf.interactionSubject = interaction;
            }

            NSMutableArray *interactionList = [[NSMutableArray alloc] initWithCapacity:0];
            [interactionList addObject:JSBridgeInteractionGetData];
            [interactionList addObject:JSBridgeInteractionPutData];
            [interactionList addObject:JSBridgeInteractionGoToNative];
            [interactionList addObject:JSBridgeInteractionDoAction];
            [interactionList addObject:JSBridgeInteractionGoToExtraNative];

            [weakSelf.interactionSubject executeInteractionForSELList:interactionList
                                                          toJSContext:hybirdContext];
        }
    }
}

- (void)hybirdWebView:(HybirdWebView *)webView didReceiveJSMessage:(WKScriptMessage *)message
{
    if (self.isUseInteraction) {
        if (message != nil) {
            JSBridgeInteraction *interaction = [[JSBridgeInteraction alloc] init];
            interaction.currentVC = self;

            NSString *selName;
            NSObject *paramters;
            if ([message.body isKindOfClass:[NSArray class]]) {
                paramters = message.body;
                selName = [[NSString alloc] initWithFormat:@"%@:",message.name];
            }else{
                selName = message.name;
                paramters = nil;
            }
            [interaction executeInteractionForSELName:selName
                                           parameters:paramters];
        }
    }
}

- (NSArray *)hybirdWebViewDidRegisterWKScriptMessageName:(HybirdWebView *)webView
{
    if (self.isUseInteraction) {
        NSMutableArray *interactionList = [[NSMutableArray alloc] initWithCapacity:0];
        [interactionList addObject:JSBridgeInteractionGetData];
        [interactionList addObject:JSBridgeInteractionPutData];
        [interactionList addObject:JSBridgeInteractionGoToNative];
        [interactionList addObject:JSBridgeInteractionDoAction];
        [interactionList addObject:JSBridgeInteractionGoToExtraNative];
        return interactionList;
    }
    return nil;
}

- (BOOL)hybirdWebViewSyncWKWebView:(HybirdWebView *)webView didLoadURL:(NSString *)requestURL
{
    if (self.HTMLString) {
        return NO;
    }
    return NO;
}

- (BOOL)hybirdWebViewSyncDcoumentCookie:(HybirdWebView *)webView didLoadURL:(NSString *)requestURL
{
    if (self.HTMLString) {
        return NO;
    }
    return YES;
}


@end


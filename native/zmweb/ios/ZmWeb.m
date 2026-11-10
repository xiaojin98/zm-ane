// iOS 原生 WKWebView 扩展，对应安卓 H5Activity 的 WebView。
// 能力：注脚本（documentStart）、种 Cookie、执行 JS、把页面跳转和 console.log 回传 AS3。
// 造梦6 / 无双用它登录并开秒怪、捡物、静音。造梦1-5 不走这里。
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "FlashRuntimeExtensions.h"

static FREContext gCtx = nil;

@interface ZmWebHost : NSObject <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *web;
@property (nonatomic, strong) WKWebViewConfiguration *config;
@property (nonatomic, strong) NSMutableArray<WKUserScript *> *scripts;
@end

@implementation ZmWebHost

+ (ZmWebHost *)shared {
    static ZmWebHost *one = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ one = [ZmWebHost new]; });
    return one;
}

- (UIView *)rootView {
    UIWindow *win = nil;
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *w in windows) { if (!w.hidden) { win = w; break; } }
    if (!win && windows.count) win = windows[0];
    return win.rootViewController.view ?: win;
}

- (void)ensureConfig {
    if (self.config) return;
    self.scripts = [NSMutableArray array];
    WKWebViewConfiguration *cfg = [WKWebViewConfiguration new];
    cfg.allowsInlineMediaPlayback = YES;
    if (@available(iOS 10.0, *)) cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    WKUserContentController *ucc = [WKUserContentController new];
    [ucc addScriptMessageHandler:self name:@"zmlog"];
    cfg.userContentController = ucc;
    self.config = cfg;
}

- (void)openAtX:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h {
    [self ensureConfig];
    if (!self.web) {
        self.web = [[WKWebView alloc] initWithFrame:CGRectMake(x, y, w, h) configuration:self.config];
        self.web.navigationDelegate = self;
        self.web.opaque = YES;
        self.web.backgroundColor = [UIColor blackColor];
        self.web.scrollView.bounces = NO;
        if (@available(iOS 11.0, *)) self.web.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    UIView *root = [self rootView];
    if (root && self.web.superview != root) [root addSubview:self.web];
    [self setX:x y:y w:w h:h];
}

- (void)setX:(CGFloat)x y:(CGFloat)y w:(CGFloat)w h:(CGFloat)h {
    if (!self.web) return;
    self.web.frame = CGRectMake(x, y, w, h);
}

- (void)addScript:(NSString *)js {
    [self ensureConfig];
    if (!js.length) return;
    WKUserScript *s = [[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [self.scripts addObject:s];
    [self.config.userContentController addUserScript:s];
}

- (void)setCookie:(NSString *)header {
    if (!header.length) return;
    [self ensureConfig];
    NSArray *parts = [header componentsSeparatedByString:@";"];
    NSArray *domains = @[@".4399.com", @".4399sj.com", @".4399zmxy.com"];
    for (NSString *raw in parts) {
        NSString *one = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSRange eq = [one rangeOfString:@"="];
        if (eq.location == NSNotFound || eq.location == 0) continue;
        NSString *name = [one substringToIndex:eq.location];
        NSString *value = [one substringFromIndex:eq.location + 1];
        NSString *low = name.lowercaseString;
        if ([low isEqualToString:@"path"] || [low isEqualToString:@"domain"] || [low isEqualToString:@"expires"] ||
            [low isEqualToString:@"max-age"] || [low isEqualToString:@"secure"] || [low isEqualToString:@"httponly"] || [low isEqualToString:@"samesite"]) continue;
        for (NSString *dom in domains) {
            NSMutableDictionary *props = [NSMutableDictionary dictionary];
            props[NSHTTPCookieName] = name;
            props[NSHTTPCookieValue] = value;
            props[NSHTTPCookieDomain] = dom;
            props[NSHTTPCookiePath] = @"/";
            NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:props];
            if (!cookie) continue;
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
            if (@available(iOS 11.0, *)) {
                WKHTTPCookieStore *store = self.config.websiteDataStore.httpCookieStore;
                [store setCookie:cookie completionHandler:nil];
            }
        }
    }
}

- (void)load:(NSString *)url {
    if (!self.web || !url.length) return;
    NSURL *u = [NSURL URLWithString:url];
    if (!u) return;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:u];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [self.web loadRequest:req];
}

- (void)eval:(NSString *)js {
    if (!self.web || !js.length) return;
    [self.web evaluateJavaScript:js completionHandler:nil];
}

- (void)close {
    if (self.web) {
        [self.web stopLoading];
        [self.web removeFromSuperview];
        self.web = nil;
    }
    if (self.config) {
        [self.config.userContentController removeScriptMessageHandlerForName:@"zmlog"];
        [self.config.userContentController removeAllUserScripts];
        self.config = nil;
    }
    [self.scripts removeAllObjects];
}

- (void)send:(NSString *)code level:(NSString *)level {
    if (gCtx == nil) return;
    const uint8_t *c = (const uint8_t *)[code UTF8String];
    const uint8_t *l = (const uint8_t *)[(level ?: @"") UTF8String];
    FREDispatchStatusEventAsync(gCtx, c, l);
}

- (void)userContentController:(WKUserContentController *)ucc didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"zmlog"]) {
        [self send:@"console" level:[NSString stringWithFormat:@"%@", message.body]];
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    [self send:@"location" level:webView.URL.absoluteString ?: @""];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self send:@"location" level:webView.URL.absoluteString ?: @""];
}

@end

static NSString *argStr(FREObject o) {
    uint32_t len = 0; const uint8_t *val = NULL;
    if (FREGetObjectAsUTF8(o, &len, &val) != FRE_OK || val == NULL) return @"";
    return [[NSString alloc] initWithBytes:val length:len encoding:NSUTF8StringEncoding] ?: @"";
}

static int32_t argInt(FREObject o) {
    int32_t v = 0;
    if (FREGetObjectAsInt32(o, &v) != FRE_OK) return 0;
    return v;
}

static FREObject zmOpen(FREContext ctx, void *d, uint32_t argc, FREObject argv[]) {
    if (argc >= 4) {
        int32_t x = argInt(argv[0]), y = argInt(argv[1]), w = argInt(argv[2]), h = argInt(argv[3]);
        dispatch_async(dispatch_get_main_queue(), ^{ [[ZmWebHost shared] openAtX:x y:y w:w h:h]; });
    }
    return NULL;
}
static FREObject zmViewport(FREContext ctx, void *d, uint32_t argc, FREObject argv[]) {
    if (argc >= 4) {
        int32_t x = argInt(argv[0]), y = argInt(argv[1]), w = argInt(argv[2]), h = argInt(argv[3]);
        dispatch_async(dispatch_get_main_queue(), ^{ [[ZmWebHost shared] setX:x y:y w:w h:h]; });
    }
    return NULL;
}
static FREObject zmCookie(FREContext ctx, void *d, uint32_t argc, FREObject argv[]) {
    if (argc >= 1) { NSString *s = argStr(argv[0]); dispatch_async(dispatch_get_main_queue(), ^{ [[ZmWebHost shared] setCookie:s]; }); }
    return NULL;
}
static FREObject zmInject(FREContext ctx, void *d, uint32_t argc, FREObject argv[]) {
    if (argc >= 1) { NSString *s = argStr(argv[0]); dispatch_async(dispatch_get_main_queue(), ^{ [[ZmWebHost shared] addScript:s]; }); }
    return NULL;
}
static FREObject zmLoad(FREContext ctx, void *d, uint32_t argc, FREObject argv[]) {
    if (argc >= 1) { NSString *s = argStr(argv[0]); dispatch_async(dispatch_get_main_queue(), ^{ [[ZmWebHost shared] load:s]; }); }
    return NULL;
}
static FREObject zmEval(FREContext ctx, void *d, uint32_t argc, FREObject argv[]) {
    if (argc >= 1) { NSString *s = argStr(argv[0]); dispatch_async(dispatch_get_main_queue(), ^{ [[ZmWebHost shared] eval:s]; }); }
    return NULL;
}
static FREObject zmClose(FREContext ctx, void *d, uint32_t argc, FREObject argv[]) {
    dispatch_async(dispatch_get_main_queue(), ^{ [[ZmWebHost shared] close]; });
    return NULL;
}

static void ContextInitializer(void *extData, const uint8_t *ctxType, FREContext ctx, uint32_t *numFunctions, const FRENamedFunction **functions) {
    gCtx = ctx;
    static FRENamedFunction fns[8];
    fns[0] = (FRENamedFunction){ (const uint8_t *)"open", NULL, zmOpen };
    fns[1] = (FRENamedFunction){ (const uint8_t *)"viewport", NULL, zmViewport };
    fns[2] = (FRENamedFunction){ (const uint8_t *)"cookie", NULL, zmCookie };
    fns[3] = (FRENamedFunction){ (const uint8_t *)"inject", NULL, zmInject };
    fns[4] = (FRENamedFunction){ (const uint8_t *)"load", NULL, zmLoad };
    fns[5] = (FRENamedFunction){ (const uint8_t *)"eval", NULL, zmEval };
    fns[6] = (FRENamedFunction){ (const uint8_t *)"close", NULL, zmClose };
    fns[7] = (FRENamedFunction){ (const uint8_t *)"viewport2", NULL, zmViewport };
    *numFunctions = 8;
    *functions = fns;
}

static void ContextFinalizer(FREContext ctx) {
    gCtx = nil;
}

void ZmWebExtInitializer(void **extDataToSet, FREContextInitializer *ctxInitializerToSet, FREContextFinalizer *ctxFinalizerToSet) {
    *extDataToSet = NULL;
    *ctxInitializerToSet = &ContextInitializer;
    *ctxFinalizerToSet = &ContextFinalizer;
}

void ZmWebExtFinalizer(void *extData) {
}

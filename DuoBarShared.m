#import "DuoBarShared.h"
#import <UIKit/UIKit.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>

#define kAppID CFSTR("com.34306.duobar")

static void DuoPowerChanged(void *ctx) { [[DuoBarShared shared] pushToViews]; }

@interface DuoBarShared () { NSHashTable *_views; NSTimer *_timer; }
@end

static void DuoPrefsChanged(CFNotificationCenterRef c, void *obs, CFStringRef n, const void *o, CFDictionaryRef u) {
    DuoBarShared *s = [DuoBarShared shared];
    [s loadPrefs];
    [s pushToViews];
    [s relayoutHosts];
}

static UIColor *DuoColorFromHex(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]]) return nil;
    NSString *h = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
                   stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (h.length != 6 && h.length != 8) return nil;
    unsigned int rgb = 0; if (![[NSScanner scannerWithString:h] scanHexInt:&rgb]) return nil;
    CGFloat a = 1.0, r, g, b;
    if (h.length == 8) { a = ((rgb >> 24) & 0xFF)/255.0; r = ((rgb >> 16)&0xFF)/255.0; g = ((rgb>>8)&0xFF)/255.0; b=(rgb&0xFF)/255.0; }
    else { r = ((rgb >> 16)&0xFF)/255.0; g = ((rgb>>8)&0xFF)/255.0; b=(rgb&0xFF)/255.0; }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

@implementation DuoBarShared

+ (instancetype)shared {
    static DuoBarShared *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [DuoBarShared new]; });
    return s;
}

- (instancetype)init {
    if ((self = [super init])) {
        _views = [NSHashTable weakObjectsHashTable];
        _battery = 1.0f; _wifi = 3; _cellular = 4;
        _enabled = YES; _cfgShowPercent = YES; _colorMode = 0; _scale = 1.0f;
        _customPosition = NO; _offsetX = 0; _offsetY = 0;
        [self loadPrefs];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, DuoPrefsChanged,
            CFSTR("com.34306.duobar/prefsChanged"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

- (double)num:(CFStringRef)key def:(double)def {
    double r = def;
    CFPropertyListRef v = CFPreferencesCopyAppValue(key, kAppID);
    if (v) {
        CFTypeID t = CFGetTypeID(v);
        if (t == CFNumberGetTypeID()) CFNumberGetValue((CFNumberRef)v, kCFNumberDoubleType, &r);
        else if (t == CFBooleanGetTypeID()) r = CFBooleanGetValue((CFBooleanRef)v) ? 1 : 0;
        CFRelease(v);
    }
    return r;
}

- (void)loadPrefs {
    CFPreferencesAppSynchronize(kAppID);   // flush cache so Settings changes are seen
    _enabled        = [self num:CFSTR("Enabled")     def:1] != 0;
    _cfgShowPercent = [self num:CFSTR("ShowPercent") def:1] != 0;
    _colorMode      = (NSInteger)[self num:CFSTR("ColorMode") def:0];
    _scale          = (CGFloat)[self num:CFSTR("Scale")   def:1.0];
    _customPosition = [self num:CFSTR("CustomPosition") def:0] != 0;
    _offsetX        = (CGFloat)[self num:CFSTR("OffsetX") def:0];
    _offsetY        = (CGFloat)[self num:CFSTR("OffsetY") def:0];
    if (_scale < 0.4f) _scale = 0.4f; if (_scale > 2.2f) _scale = 2.2f;
    CFPropertyListRef cc = CFPreferencesCopyAppValue(CFSTR("CustomColor"), kAppID);
    if (cc) { if (CFGetTypeID(cc) == CFStringGetTypeID()) _customColor = DuoColorFromHex((__bridge NSString *)cc); CFRelease(cc); }
}

- (void)registerView:(DuoBarView *)v { if (v) { [_views addObject:v]; [self pushToViews]; } }

- (void)pullBattery {
    // IOKit power source — safe in SpringBoard (UIDevice batteryMonitoring re-enters
    // SBBacklightController and crashes).
    CFTypeRef blob = IOPSCopyPowerSourcesInfo();
    if (blob) {
        CFArrayRef list = IOPSCopyPowerSourcesList(blob);
        if (list) {
            for (CFIndex i = 0; i < CFArrayGetCount(list); i++) {
                CFDictionaryRef d = IOPSGetPowerSourceDescription(blob, CFArrayGetValueAtIndex(list, i));
                if (!d) continue;
                int cur = 100, mx = 100;
                CFNumberRef c = (CFNumberRef)CFDictionaryGetValue(d, CFSTR(kIOPSCurrentCapacityKey));
                CFNumberRef m = (CFNumberRef)CFDictionaryGetValue(d, CFSTR(kIOPSMaxCapacityKey));
                if (c) CFNumberGetValue(c, kCFNumberIntType, &cur);
                if (m) CFNumberGetValue(m, kCFNumberIntType, &mx);
                if (mx > 0) _battery = (CGFloat)cur / (CGFloat)mx;
                // "plugged in" = charging OR on AC power (full-but-plugged reports IsCharging=false)
                CFBooleanRef chg = (CFBooleanRef)CFDictionaryGetValue(d, CFSTR(kIOPSIsChargingKey));
                CFStringRef pss = (CFStringRef)CFDictionaryGetValue(d, CFSTR(kIOPSPowerSourceStateKey));
                BOOL onAC = (pss && CFEqual(pss, CFSTR(kIOPSACPowerValue)));
                _charging = onAC || (chg && CFBooleanGetValue(chg));
                break;
            }
            CFRelease(list);
        }
        CFRelease(blob);
    }
    _lowPowerMode = [NSProcessInfo processInfo].lowPowerModeEnabled;
}

- (void)pushToViews {
    [self pullBattery];
    for (DuoBarView *v in _views) {
        v.batteryLevel = _battery; v.charging = _charging; v.lowPowerMode = _lowPowerMode;
        v.wifiState = _wifi; v.cellularBars = _cellular; v.airplaneMode = _airplane;
        v.showPercent = _cfgShowPercent;
        [v setNeedsDisplay];
    }
}

- (void)relayoutHosts {
    for (DuoBarView *v in _views) {
        UIView *a = v.superview;
        while (a) {
            NSString *cn = NSStringFromClass([a class]);
            if ([cn hasPrefix:@"STUIStatusBar"]) { [a setNeedsLayout]; break; }
            a = a.superview;
        }
        [v setNeedsDisplay];
    }
}

- (void)startTimer {
    if (_timer) return;
    _timer = [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer *t) { [self pushToViews]; }];
    // instant plug/unplug + level updates via IOKit power-source notifications
    CFRunLoopSourceRef src = IOPSNotificationCreateRunLoopSource(DuoPowerChanged, NULL);
    if (src) { CFRunLoopAddSource(CFRunLoopGetMain(), src, kCFRunLoopDefaultMode); CFRelease(src); }
}

@end

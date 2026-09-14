#import "DuoHeaders.h"
#import "DuoBarShared.h"
#import "DuoBarView.h"
#import <objc/runtime.h>

static const void *kDuoViewKey  = &kDuoViewKey;
static const void *kMineHidden  = &kMineHidden;   // marks a stock view WE hid

@interface STUIStatusBarIndicatorAirplaneModeItem : NSObject
- (id)imageForUpdate:(id)update;
- (NSString *)systemImageNameForUpdate:(id)update;
@end

static BOOL DuoIsKnownGlyph(NSString *cn) {
    if (![cn hasPrefix:@"STUIStatusBar"]) return NO;
    return ([cn containsString:@"Battery"] || [cn containsString:@"Wifi"] ||
            [cn containsString:@"Cellular"] || [cn containsString:@"Signal"] ||
            [cn containsString:@"AirplaneMode"]);
}
static BOOL DuoStatusPrefix(NSString *cn) {
    return ([cn hasPrefix:@"STUIStatusBar"] || [cn hasPrefix:@"_STUIStatusBar"] ||
            [cn hasPrefix:@"_UIStatusBar"] || [cn hasPrefix:@"UIStatusBar"]);
}

// Walk the tree: hide (or restore) the stock glyphs, union the visible cluster,
// capture the battery anchor + the stock adaptive colour, and report whether this
// bar actually had visible stock glyphs (so we only draw on the *active* bar).
static void DuoWalk(UIView *view, UIView *host, UIView *duo, CGFloat rightEdgeX, BOOL enabled,
                    CGRect *cluster, CGRect *battRect, BOOL *anyVisible,
                    UIColor *__strong *sigColor, UIColor *__strong *lblColor) {
    for (UIView *sub in view.subviews) {
        if (sub == duo) continue;
        NSString *cn = NSStringFromClass([sub class]);

        if ([cn containsString:@"SignalView"]) {
            @try { UIColor *c = [sub valueForKey:@"activeColor"]; if (c) *sigColor = c; } @catch (__unused NSException *e) {}
        }
        if ([sub isKindOfClass:[UILabel class]] && [cn containsString:@"String"]) {
            UIColor *c = ((UILabel *)sub).textColor; if (c) *lblColor = c;
        }

        CGRect r = [sub.superview convertRect:sub.frame toView:host];
        BOOL known = DuoIsKnownGlyph(cn);
        BOOL leaf  = (sub.subviews.count == 0);
        BOOL rightRegion = (CGRectGetMidX(r) > rightEdgeX);
        BOOL match = known || (leaf && rightRegion && DuoStatusPrefix(cn) && r.size.width > 1.0f);

        if (match) {
            BOOL mine = (objc_getAssociatedObject(sub, kMineHidden) != nil);
            if (enabled) {
                BOOL wasVisible = (!sub.isHidden && sub.alpha > 0.02f) || mine;
                if (wasVisible) {
                    *anyVisible = YES;
                    *cluster = CGRectIsNull(*cluster) ? r : CGRectUnion(*cluster, r);
                    if ([cn containsString:@"BatteryView"] && r.size.height > 1.0f) {
                        if (CGRectIsNull(*battRect) || r.size.height < battRect->size.height) *battRect = r;
                    }
                }
                sub.hidden = YES;
                objc_setAssociatedObject(sub, kMineHidden, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            } else if (mine) {
                sub.hidden = NO;
                objc_setAssociatedObject(sub, kMineHidden, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        DuoWalk(sub, host, duo, rightEdgeX, enabled, cluster, battRect, anyVisible, sigColor, lblColor);
    }
}

%hook STUIStatusBarIndicatorAirplaneModeItem
- (id)imageForUpdate:(id)update {
    if ([DuoBarShared shared].enabled) { [DuoBarShared shared].airplane = YES; [[DuoBarShared shared] pushToViews]; return nil; }
    return %orig;
}
- (NSString *)systemImageNameForUpdate:(id)update {
    return [DuoBarShared shared].enabled ? nil : %orig;
}
%end

%hook STUIStatusBar

- (void)layoutSubviews {
    %orig;
    @try {
        DuoBarShared *s = [DuoBarShared shared];
        UIView *host = self.foregroundView ?: self;

        // wifi/cellular from the data model; battery from UIDevice (reliable plug state)
        STStatusBarData *d = self.currentData ?: self.currentAggregatedData;
        if (d) {
            STStatusBarDataIntegerEntry *w = d.wifiEntry;
            if (w) s.wifi = w.isEnabled ? w.displayValue : -1;
            STStatusBarDataIntegerEntry *ce = d.cellularEntry;
            if (ce) { s.cellular = ce.isEnabled ? ce.displayValue : -1; if (ce.isEnabled) s.airplane = NO; }
        }

        DuoBarView *duo = objc_getAssociatedObject(self, kDuoViewKey);
        if (!duo) {
            duo = [[DuoBarView alloc] initWithFrame:CGRectZero];
            objc_setAssociatedObject(self, kDuoViewKey, duo, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [s registerView:duo];
            [s startTimer];
        }
        if (duo.superview != host) [host addSubview:duo];

        CGRect cluster = CGRectNull, battRect = CGRectNull;
        BOOL anyVisible = NO;
        UIColor *sigColor = nil, *lblColor = nil;
        CGFloat rightEdgeX = host.bounds.size.width * 0.52f;
        DuoWalk(host, host, duo, rightEdgeX, s.enabled, &cluster, &battRect, &anyVisible, &sigColor, &lblColor);

        // only draw on the active bar (fixes duplicate icons in Control Center)
        BOOL show = s.enabled && anyVisible && self.window != nil;
        duo.hidden = !show;
        if (!show) return;

        // adaptive/override colour
        UIColor *tint;
        switch (s.colorMode) {
            case 1: tint = [UIColor whiteColor]; break;
            case 2: tint = [UIColor blackColor]; break;
            case 3: tint = s.customColor ?: [UIColor whiteColor]; break;
            default: {
                tint = sigColor ?: lblColor;
                if (!tint) { @try { tint = self.foregroundColor; } @catch (__unused NSException *e) {} }
                if (!tint) tint = [UIColor whiteColor];
            }
        }
        duo.tint = tint;

        // size + position (battery-anchored, centred on cluster, user scale + offset)
        CGFloat H = host.bounds.size.height;
        CGFloat anchorH = (!CGRectIsNull(battRect)) ? battRect.size.height
                        : (!CGRectIsNull(cluster) ? cluster.size.height : 13.0f);
        CGFloat base = anchorH * 2.0f;
        if (base < 20.0f) base = 20.0f; if (base > 36.0f) base = 36.0f;
        CGFloat sz = base * (s.scale > 0 ? s.scale : 1.0f);
        if (sz < 12.0f) sz = 12.0f; if (sz > 64.0f) sz = 64.0f;
        CGFloat addX = s.customPosition ? s.offsetX : 0.0f;   // + = right
        CGFloat addY = s.customPosition ? s.offsetY : 0.0f;   // + = up
        CGFloat cy = ((!CGRectIsNull(battRect)) ? CGRectGetMidY(battRect)
                     : (!CGRectIsNull(cluster) ? CGRectGetMidY(cluster) : H/2.0f)) - addY;
        CGFloat cx = ((!CGRectIsNull(cluster) && cluster.size.width > 1.0f) ? CGRectGetMidX(cluster)
                     : (host.bounds.size.width - sz/2.0f - 10.0f)) + addX;
        duo.frame = CGRectMake(roundf(cx - sz/2.0f), roundf(cy - sz/2.0f), roundf(sz), roundf(sz));
        [host bringSubviewToFront:duo];

        [s pushToViews];
    } @catch (__unused NSException *ex) {}
}

- (void)setForegroundColor:(UIColor *)color {
    %orig;
    @try {
        DuoBarShared *s = [DuoBarShared shared];
        if (s.colorMode != 0) return;                 // only adaptive mode follows the bar
        DuoBarView *duo = objc_getAssociatedObject(self, kDuoViewKey);
        if (duo && color) { duo.tint = color; [duo setNeedsDisplay]; }
    } @catch (__unused NSException *ex) {}
}

%end

%ctor { %init; }

#import "DuoBarView.h"

// Geometry ported 1:1 from the Android reference (CATCHINGL/O.status,
// DuoIndicatorView.kt): a 436-unit design space, centre (237,211), radius 163.
// Angles use the same convention as Android/UIKit: 0 = east, positive = clockwise,
// 90 = bottom, 270 = top.

static inline CGFloat DEG(CGFloat d) { return d * (CGFloat)M_PI / 180.0f; }

@implementation DuoBarView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.userInteractionEnabled = NO;
        _batteryLevel = 1.0f;
        _wifiState = 3;
        _cellularBars = 4;
        _showPercent = YES;
        _tint = [UIColor whiteColor];
    }
    return self;
}

- (void)refresh {
    // Battery values are pushed in by DuoBarShared (IOKit); just redraw.
    [self setNeedsDisplay];
}

- (BOOL)tintIsDark {
    UIColor *t = self.tint ?: [UIColor whiteColor];
    CGFloat r=1,g=1,b=1,a=1;
    if (![t getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w=1; if ([t getWhite:&w alpha:&a]) { r=g=b=w; }
    }
    CGFloat lum = 0.299f*r + 0.587f*g + 0.114f*b;
    return lum < 0.5f;
}

- (UIColor *)batteryColorActive:(UIColor *)active {
    // Green ONLY while charging (plugged in). Unplugged -> normal tint, even at 100%.
    if (self.charging)     return [UIColor colorWithRed:52/255.0  green:199/255.0 blue:89/255.0 alpha:1];
    if (self.lowPowerMode) return [UIColor colorWithRed:255/255.0 green:204/255.0 blue:0/255.0  alpha:1];
    NSInteger pct = (NSInteger)lroundf(self.batteryLevel * 100.0f);
    if (pct <= 20)         return [UIColor colorWithRed:255/255.0 green:59/255.0  blue:48/255.0 alpha:1];
    return active;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;

    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    CGFloat s = MIN(w, h) / 436.0f;
    // design-space -> view transform
    #define X(v) (w/2.0f + ((CGFloat)(v) - 237.0f) * s)
    #define Y(v) (h/2.0f + ((CGFloat)(v) - 211.0f) * s)

    BOOL dark = [self tintIsDark];
    UIColor *active   = self.tint ?: (dark ? [UIColor blackColor] : [UIColor whiteColor]);
    UIColor *inactive = dark ? [UIColor colorWithWhite:0 alpha:0x38/255.0]
                             : [UIColor colorWithWhite:1 alpha:0x55/255.0];

    CGFloat cx = X(237), cy = Y(211), r = 163.0f * s;
    CGRect rr = CGRectMake(cx - r, cy - r, 2*r, 2*r);

    // ---------- 1) Battery C-ring (gap at bottom for the dots) ----------
    CGFloat start = 151.5f, sweep = 237.0f;
    CGFloat ringW = 26.0f * s;

    UIBezierPath *(^arc)(CGFloat, CGFloat) = ^UIBezierPath *(CGFloat a0, CGFloat a1){
        UIBezierPath *p = [UIBezierPath bezierPathWithArcCenter:CGPointMake(CGRectGetMidX(rr), CGRectGetMidY(rr))
                                                        radius:r startAngle:DEG(a0) endAngle:DEG(a1) clockwise:YES];
        p.lineWidth = ringW; p.lineCapStyle = kCGLineCapRound; return p;
    };
    CGFloat lvl = MAX(0.0f, MIN(1.0f, self.batteryLevel));
    UIColor *bcol = [self batteryColorActive:active];
    NSInteger pct = (NSInteger)lroundf(lvl * 100.0f);

    if (!self.showPercent) {
        // full C-ring
        [inactive setStroke]; [arc(start, start + sweep) stroke];
        if (lvl > 0.0f) { [bcol setStroke]; [arc(start, start + sweep * lvl) stroke]; }
    } else {
        // percentage mode: open the TOP of the ring for the number (ported from O.status)
        CGFloat oStart = 151.5f, oEnd = 388.5f;
        BOOL full = (pct >= 100);
        CGFloat leftTopEnd    = full ? 231.0f : 236.0f;
        CGFloat rightTopStart = full ? 309.0f : 304.0f;
        [inactive setStroke];
        [arc(oStart, leftTopEnd) stroke];
        [arc(rightTopStart, oEnd) stroke];
        CGFloat progressEnd = oStart + sweep * lvl;
        [bcol setStroke];
        CGFloat leftProgEnd = MIN(progressEnd, leftTopEnd);
        if (leftProgEnd > oStart) [arc(oStart, leftProgEnd) stroke];
        if (progressEnd > rightTopStart) { CGFloat rp = MIN(progressEnd, oEnd); [arc(rightTopStart, rp) stroke]; }
        // the number, centred in the top opening (design Y=60)
        UIFont *bf = [UIFont systemFontOfSize:92.0f * s weight:UIFontWeightBold];
        NSDictionary *att = @{ NSFontAttributeName: bf, NSForegroundColorAttributeName: active };
        NSString *txt = [NSString stringWithFormat:@"%ld", (long)pct];
        CGSize ts = [txt sizeWithAttributes:att];
        [txt drawAtPoint:CGPointMake(X(237) - ts.width/2.0f, Y(60) - ts.height/2.0f) withAttributes:att];
    }

    // ---------- 2) Cellular dots (locked geometry) ----------
    const CGFloat dotx[4] = {143, 202, 272, 331};
    const CGFloat doty[4] = {342, 372, 372, 342};
    NSInteger shownCell = self.airplaneMode ? 0 : self.cellularBars; // -1/airplane -> none active
    for (int i = 0; i < 4; i++) {
        UIColor *col = (shownCell > i) ? active : inactive;
        [col setFill];
        UIBezierPath *d = [UIBezierPath bezierPathWithArcCenter:CGPointMake(X(dotx[i]), Y(doty[i]))
                                                        radius:18.0f*s startAngle:0 endAngle:DEG(360) clockwise:YES];
        [d fill];
    }

    // ---------- 3) Centre: Wi-Fi fan (when connected) ----------
    BOOL wifiConnected = (self.wifiState >= 0);
    CGFloat wifiW = 21.0f * s;
    if (wifiConnected) {
        NSInteger lv = self.wifiState;
        // outer arc (>=2)
        UIBezierPath *a1p = [UIBezierPath bezierPath];
        [a1p moveToPoint:CGPointMake(X(171), Y(194))];
        [a1p addCurveToPoint:CGPointMake(X(304), Y(194)) controlPoint1:CGPointMake(X(205), Y(160)) controlPoint2:CGPointMake(X(269), Y(160))];
        a1p.lineWidth = wifiW; a1p.lineCapStyle = kCGLineCapRound;
        [(lv >= 2 ? active : inactive) setStroke]; [a1p stroke];
        // middle arc (>=1)
        UIBezierPath *a2p = [UIBezierPath bezierPath];
        [a2p moveToPoint:CGPointMake(X(199), Y(224))];
        [a2p addCurveToPoint:CGPointMake(X(277), Y(224)) controlPoint1:CGPointMake(X(220), Y(203)) controlPoint2:CGPointMake(X(256), Y(203))];
        a2p.lineWidth = wifiW; a2p.lineCapStyle = kCGLineCapRound;
        [(lv >= 1 ? active : inactive) setStroke]; [a2p stroke];
        // terminal teardrop (always active)
        UIBezierPath *tp = [UIBezierPath bezierPath];
        [tp moveToPoint:CGPointMake(X(237), Y(238))];
        [tp addCurveToPoint:CGPointMake(X(215), Y(255)) controlPoint1:CGPointMake(X(223), Y(238)) controlPoint2:CGPointMake(X(215), Y(247))];
        [tp addCurveToPoint:CGPointMake(X(233), Y(279)) controlPoint1:CGPointMake(X(215), Y(262)) controlPoint2:CGPointMake(X(226), Y(273))];
        [tp addCurveToPoint:CGPointMake(X(242), Y(279)) controlPoint1:CGPointMake(X(236), Y(282)) controlPoint2:CGPointMake(X(239), Y(282))];
        [tp addCurveToPoint:CGPointMake(X(260), Y(255)) controlPoint1:CGPointMake(X(249), Y(273)) controlPoint2:CGPointMake(X(260), Y(262))];
        [tp addCurveToPoint:CGPointMake(X(237), Y(238)) controlPoint1:CGPointMake(X(260), Y(247)) controlPoint2:CGPointMake(X(251), Y(238))];
        [tp closePath];
        [active setFill]; [tp fill];
    } else if (self.airplaneMode) {
        // Airplane silhouette (nose-up), ported from the reference. Uses Y-18 offset.
        #define YA(v) (Y((CGFloat)(v) - 18.0f))
        UIBezierPath *p = [UIBezierPath bezierPath];
        [p moveToPoint:CGPointMake(X(237), YA(143))];
        [p addCurveToPoint:CGPointMake(X(225), YA(163)) controlPoint1:CGPointMake(X(230), YA(143)) controlPoint2:CGPointMake(X(226), YA(151))];
        [p addLineToPoint:CGPointMake(X(221), YA(205))];
        [p addLineToPoint:CGPointMake(X(165), YA(239))];
        [p addCurveToPoint:CGPointMake(X(156), YA(257)) controlPoint1:CGPointMake(X(157), YA(244)) controlPoint2:CGPointMake(X(154), YA(251))];
        [p addCurveToPoint:CGPointMake(X(174), YA(261)) controlPoint1:CGPointMake(X(158), YA(263)) controlPoint2:CGPointMake(X(166), YA(264))];
        [p addLineToPoint:CGPointMake(X(221), YA(244))];
        [p addLineToPoint:CGPointMake(X(220), YA(278))];
        [p addLineToPoint:CGPointMake(X(196), YA(297))];
        [p addCurveToPoint:CGPointMake(X(193), YA(311)) controlPoint1:CGPointMake(X(191), YA(301)) controlPoint2:CGPointMake(X(190), YA(307))];
        [p addCurveToPoint:CGPointMake(X(207), YA(312)) controlPoint1:CGPointMake(X(196), YA(315)) controlPoint2:CGPointMake(X(202), YA(314))];
        [p addLineToPoint:CGPointMake(X(237), YA(300))];
        [p addLineToPoint:CGPointMake(X(267), YA(312))];
        [p addCurveToPoint:CGPointMake(X(281), YA(311)) controlPoint1:CGPointMake(X(272), YA(314)) controlPoint2:CGPointMake(X(278), YA(315))];
        [p addCurveToPoint:CGPointMake(X(278), YA(297)) controlPoint1:CGPointMake(X(284), YA(307)) controlPoint2:CGPointMake(X(283), YA(301))];
        [p addLineToPoint:CGPointMake(X(254), YA(278))];
        [p addLineToPoint:CGPointMake(X(253), YA(244))];
        [p addLineToPoint:CGPointMake(X(300), YA(261))];
        [p addCurveToPoint:CGPointMake(X(318), YA(257)) controlPoint1:CGPointMake(X(308), YA(264)) controlPoint2:CGPointMake(X(316), YA(263))];
        [p addCurveToPoint:CGPointMake(X(309), YA(239)) controlPoint1:CGPointMake(X(320), YA(251)) controlPoint2:CGPointMake(X(317), YA(244))];
        [p addLineToPoint:CGPointMake(X(253), YA(205))];
        [p addLineToPoint:CGPointMake(X(249), YA(163))];
        [p addCurveToPoint:CGPointMake(X(237), YA(143)) controlPoint1:CGPointMake(X(248), YA(151)) controlPoint2:CGPointMake(X(244), YA(143))];
        [p closePath];
        [active setFill]; [p fill];
        #undef YA
    }

    #undef X
    #undef Y
}

@end

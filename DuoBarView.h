#import <UIKit/UIKit.h>

// A single circular indicator that packs three signals, iPhone Duo style:
//   - Battery  -> outer ring arc (continuous gauge, gap at the bottom)
//   - Wi-Fi    -> "fan" symbol in the centre
//   - Cellular -> row of dots in the bottom gap
@interface DuoBarView : UIView
@property (nonatomic, assign) CGFloat batteryLevel;   // 0.0 .. 1.0
@property (nonatomic, assign) BOOL    charging;       // plugged / charging
@property (nonatomic, assign) BOOL    lowPowerMode;   // yellow ring
@property (nonatomic, assign) NSInteger wifiState;    // -1 off/none, 0..3 strength
@property (nonatomic, assign) NSInteger cellularBars; // -1 no service, 0..4 bars
@property (nonatomic, assign) BOOL    airplaneMode;   // hides cellular dots, shows plane hint
@property (nonatomic, assign) BOOL    showPercent;    // draw battery % number in the ring (top opens up)
@property (nonatomic, strong) UIColor *tint;          // base foreground colour (usually white/black)
- (void)refresh; // pulls battery from UIDevice, marks needsDisplay
@end

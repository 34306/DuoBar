#import "DuoBarView.h"
// Shared live status values, registry of on-screen DuoBarViews, and user prefs.
@interface DuoBarShared : NSObject
+ (instancetype)shared;

// live status
@property (nonatomic, assign) CGFloat battery;      // 0..1
@property (nonatomic, assign) BOOL    charging;
@property (nonatomic, assign) BOOL    lowPowerMode;
@property (nonatomic, assign) NSInteger wifi;        // -1..3
@property (nonatomic, assign) NSInteger cellular;    // -1..4
@property (nonatomic, assign) BOOL    airplane;

// preferences (com.34306.duobar)
@property (nonatomic, assign) BOOL    enabled;       // master
@property (nonatomic, assign) BOOL    cfgShowPercent;
@property (nonatomic, assign) NSInteger colorMode;   // 0 adaptive, 1 white, 2 black, 3 custom
@property (nonatomic, strong) UIColor *customColor;
@property (nonatomic, assign) CGFloat scale;         // 0.5..1.8
@property (nonatomic, assign) BOOL    customPosition; // apply offsets, else auto-centre
@property (nonatomic, assign) CGFloat offsetX;       // pt
@property (nonatomic, assign) CGFloat offsetY;       // pt

- (void)registerView:(DuoBarView *)v;
- (void)pushToViews;
- (void)startTimer;
- (void)loadPrefs;
- (void)relayoutHosts;   // force status bars to re-run layout (apply scale/pos/colour)
@end

#import <UIKit/UIKit.h>

// Minimal, read-only surface. We never hook the item/update path (that path is
// fragile — hooking -applyUpdate:toDisplayItem: crashed SpringBoard). We only
// read STStatusBarData off the container and hide the stock glyph views.

@interface STStatusBarDataEntry : NSObject
@property (nonatomic, readonly, getter=isEnabled) BOOL enabled;
@end

@interface STStatusBarDataIntegerEntry : STStatusBarDataEntry
@property (nonatomic, readonly) NSInteger displayValue;   // bar count actually shown
@end

@interface STStatusBarDataBatteryEntry : STStatusBarDataEntry
@property (nonatomic, readonly) NSInteger capacity;        // 0..100
@property (nonatomic, readonly) NSInteger state;           // 0 unplugged, else charging/full
@property (nonatomic, readonly) BOOL saverModeActive;      // Low Power Mode
@end

@interface STStatusBarData : NSObject
@property (nonatomic, readonly) STStatusBarDataBatteryEntry  *mainBatteryEntry;
@property (nonatomic, readonly) STStatusBarDataIntegerEntry  *wifiEntry;
@property (nonatomic, readonly) STStatusBarDataIntegerEntry  *cellularEntry;
@end

@interface STUIStatusBar : UIView
@property (nonatomic, retain)   UIView *foregroundView;
@property (nonatomic, retain)   UIColor *foregroundColor;   // status bar tint (adapts light/dark)
@property (nonatomic, readonly) STStatusBarData *currentData;
@property (nonatomic, readonly) STStatusBarData *currentAggregatedData;
- (void)setForegroundColor:(UIColor *)color;
@end

#import <UIKit/UIKit.h>

@interface PSSpecifier : NSObject
- (void)performSetterWithValue:(id)value;
- (id)propertyForKey:(NSString *)key;
@end
@interface PSTableCell : UITableViewCell
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid specifier:(PSSpecifier *)specifier;
- (PSSpecifier *)specifier;
@end
@interface PSControlTableCell : PSTableCell
- (UIControl *)control;
@end
@interface PSSliderTableCell : PSControlTableCell
@end

// Continuous slider cell with a live value readout, so drags move/scale the icon
// in real time and the sign/direction is always visible.
@interface DuoSliderCell : PSSliderTableCell {
    UILabel *_valueLabel;
}
@end

@implementation DuoSliderCell
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:rid specifier:specifier];
    if (self) {
        _valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 52, 24)];
        _valueLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightSemibold];
        _valueLabel.textAlignment = NSTextAlignmentRight;
        _valueLabel.textColor = [UIColor secondaryLabelColor];
        self.accessoryView = _valueLabel;

        UIControl *c = [self control];
        if ([c isKindOfClass:[UISlider class]]) {
            ((UISlider *)c).continuous = YES;
            [c addTarget:self action:@selector(duoLive:) forControlEvents:UIControlEventValueChanged];
            [self updateLabel:(UISlider *)c];
        }
    }
    return self;
}

- (void)updateLabel:(UISlider *)slider {
    if (slider.minimumValue >= 0) {                 // Scale
        _valueLabel.text = [NSString stringWithFormat:@"%.2f×", slider.value];
    } else {                                        // signed offset
        int v = (int)lroundf(slider.value);
        _valueLabel.text = (v > 0) ? [NSString stringWithFormat:@"+%d", v]
                                   : [NSString stringWithFormat:@"%d", v];
    }
}

- (void)duoLive:(UISlider *)slider {
    [self updateLabel:slider];
    @try {
        PSSpecifier *spec = [self specifier];
        if (spec) [spec performSetterWithValue:@(slider.value)];   // writes pref (+PostNotification)
    } @catch (__unused NSException *e) {}
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.34306.duobar/prefsChanged"), NULL, NULL, YES);
}
@end

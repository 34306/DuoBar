#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>

@interface DuoBarPrefsListController : PSListController
@end

@implementation DuoBarPrefsListController
- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)resetPrefs {
    CFStringRef app = CFSTR("com.34306.duobar");
    NSArray *keys = @[@"Enabled", @"ShowPercent", @"ColorMode", @"CustomColor",
                      @"Scale", @"CustomPosition", @"OffsetX", @"OffsetY"];
    for (NSString *k in keys) CFPreferencesSetAppValue((__bridge CFStringRef)k, NULL, app);
    CFPreferencesAppSynchronize(app);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.34306.duobar/prefsChanged"), NULL, NULL, YES);
    [self reloadSpecifiers];
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Reset"
        message:@"DuoBar settings restored to defaults." preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:a animated:YES completion:nil];
}

- (void)respring {
    pid_t pid;
    const char *argv[] = { "sbreload", NULL };
    if (posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)argv, NULL) != 0) {
        const char *a2[] = { "killall", "-9", "SpringBoard", NULL };
        posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)a2, NULL);
    }
}
@end

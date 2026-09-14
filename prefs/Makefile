include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = DuoBarPrefs
DuoBarPrefs_FILES = DuoBarPrefsListController.m DuoSliderCell.m
DuoBarPrefs_INSTALL_PATH = /Library/PreferenceBundles
DuoBarPrefs_FRAMEWORKS = UIKit
DuoBarPrefs_CFLAGS = -fobjc-arc
DuoBarPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk

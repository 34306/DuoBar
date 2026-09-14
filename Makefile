ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DuoBar
DuoBar_FILES = Tweak.x DuoBarView.m DuoBarShared.m
DuoBar_CFLAGS = -fobjc-arc
DuoBar_FRAMEWORKS = UIKit IOKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

ARCHS = armv7 arm64

include theos/makefiles/common.mk

APPLICATION_NAME = MTerminal
MTerminal_FILES = $(wildcard *.m)
MTerminal_FRAMEWORKS = AudioToolbox CoreGraphics CoreText UIKit
MTerminal_CFLAGS = -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/application.mk

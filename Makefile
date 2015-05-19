ARCHS = armv7

include theos/makefiles/common.mk

APPLICATION_NAME = MTerminal
MTerminal_FILES = $(wildcard *.m)
MTerminal_FRAMEWORKS = AudioToolbox CoreGraphics CoreText UIKit

include $(THEOS_MAKE_PATH)/application.mk

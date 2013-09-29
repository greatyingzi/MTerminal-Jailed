include theos/makefiles/common.mk

APPLICATION_NAME = MTerminal
MTerminal_FILES = $(wildcard *.m)
MTerminal_FRAMEWORKS = UIKit QuartzCore CoreGraphics CoreText

include $(THEOS_MAKE_PATH)/application.mk

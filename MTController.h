#import <AudioToolbox/AudioServices.h>
#import <CoreText/CoreText.h>
#import "MTKBAvoiding.h"
#import "VT100.h"

@interface MTController : MTKBAvoiding <UIActionSheetDelegate,UIKeyInput,UITableViewDataSource,VT100Delegate> {
  CFMutableBagRef colorBag;
  CGColorSpaceRef colorSpace;
  CGColorRef nullColor,colorTable[256];
  CGColorRef bgDefault,fgDefault,fgBold;
  CGColorRef bgCursor,fgCursor;
  CTFontRef ctFont;
  CTFontRef ctFontBold;
  CTFontRef ctFontItalic;
  CTFontRef ctFontBoldItalic;
  CFNumberRef ctUnderlineStyleSingle;
  CFNumberRef ctUnderlineStyleDouble;
  CGFloat colWidth,rowHeight;
  SystemSoundID bellSoundID;
  BOOL bellSound;
  BOOL darkBG;
  BOOL ctrlLock;
  NSTimer* repeatTimer;
  NSIndexSet* screenSection;
  NSMutableArray* allTerminals;
  VT100* activeTerminal;
  NSUInteger activeIndex,previousIndex;
}
-(BOOL)handleOpenURL:(NSURL*)URL;
-(BOOL)isRunning;
@end

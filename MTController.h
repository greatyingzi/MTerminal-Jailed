#import <AudioToolbox/AudioServices.h>
#import <CoreText/CoreText.h>
#import "MTKBAvoiding.h"
@class VT100;

@interface MTController : MTKBAvoiding <UIKeyInput,UITableViewDataSource> {
  NSData* kbUp[2];
  NSData* kbDown[2];
  NSData* kbRight[2];
  NSData* kbLeft[2];
  NSData* kbHome[2];
  NSData* kbEnd[2];
  NSData* kbInsert;
  NSData* kbDelete;
  NSData* kbPageUp;
  NSData* kbPageDown;
  NSData* kbTab;
  NSData* kbEscape;
  NSData* kbBack[2];
  NSData* kbReturn[2];
  CGColorRef colorTable[256],nullColor;
  CGColorRef bgDefault,bgCursor;
  CGColorRef fgDefault,fgBold,fgCursor;
  CTFontRef ctFont;
  CTFontRef ctFontBold;
  CTFontRef ctFontItalic;
  CTFontRef ctFontBoldItalic;
  CFNumberRef ctUnderlineStyleSingle;
  CFNumberRef ctUnderlineStyleDouble;
  CGFloat glyphAscent,glyphHeight,glyphMidY;
  CGFloat colWidth,rowHeight;
  BOOL bellSound;
  SystemSoundID bellSoundID;
  NSFileHandle* ptyHandle;
  pid_t ptypid;
  VT100* vt100;
  NSTimer* repeatTimer;
  BOOL ctrlLock;
}
-(BOOL)isRunning;
@end

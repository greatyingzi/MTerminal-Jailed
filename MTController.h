#import <AudioToolbox/AudioServices.h>
#import <CoreText/CoreText.h>
@class VT100;

@interface MTController : UITableViewController <UIKeyInput,UIGestureRecognizerDelegate> {
  NSData* kUp;
  NSData* kDown;
  NSData* kLeft;
  NSData* kRight;
  NSData* kPageUp;
  NSData* kPageDown;
  NSData* kHome;
  NSData* kEnd;
  NSData* kEscape;
  NSData* kTab;
  NSData* kInsert;
  NSData* kDelete;
  NSData* kBackspace;
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
  BOOL ctrlDown;
}
@end

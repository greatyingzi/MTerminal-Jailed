#import <AudioToolbox/AudioServices.h>
#import <CoreText/CoreText.h>
#import "MTKBAvoiding.h"
#import "VT100.h"

#define kPrefPalette @"palette"
#define kPrefBGDefaultColor @"bgColor"
#define kPrefFGDefaultColor @"fgColor"
#define kPrefFGBoldColor @"fgBoldColor"
#define kPrefBGCursorColor @"bgCursorColor"
#define kPrefFGCursorColor @"fgCursorColor"
#define kPrefFontName @"fontName"
#define kPrefFontSize @"fontSize"
#define kPrefFontWidthSample @"fontWidthSample"
#define kPrefFontProportional @"fontProportional"

@interface MTController : MTKBAvoiding <UIActionSheetDelegate,UIKeyInput,UITableViewDataSource,VT100Delegate> {
  CGColorRef colorTable[256],nullColor;
  CGColorRef bgDefault,fgDefault,fgBold;
  CGColorRef bgCursor,fgCursor;
  CTFontRef ctFont;
  CTFontRef ctFontBold;
  CTFontRef ctFontItalic;
  CTFontRef ctFontBoldItalic;
  CFNumberRef ctUnderlineStyleSingle;
  CFNumberRef ctUnderlineStyleDouble;
  CGFloat glyphAscent,glyphHeight,glyphMidY;
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
-(id)initWithSettings:(NSDictionary*)settings;
-(BOOL)isRunning;
@end

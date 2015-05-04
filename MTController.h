#import "VT100Row.h"
#import "VT100Screen.h"

@interface MTController : UITableViewController <UIKeyInput,UIGestureRecognizerDelegate,VT100RowDelegate,ScreenBufferRefreshDelegate> {
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
  CGColorRef colorTable[256],fgColor,fgBoldColor;
  NSTimer* repeatTimer;
  VT100Screen* screen;
  VT100Terminal* terminal;
  NSFileHandle* ptyHandle;
  pid_t ptypid;
  BOOL ctrlDown;
}
@end

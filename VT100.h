#import "VT100Screen.h"

@interface VT100 : NSObject <ScreenBufferRefreshDelegate,UITableViewDataSource> {
  VT100Terminal* terminal;
  VT100Screen* screen;
  pid_t child_pid;
  NSFileHandle* fileHandle;
}
@property(readonly) UITableView* tableView;

-(void)putData:(NSData*)data;
-(void)updateScreenSize;
@end

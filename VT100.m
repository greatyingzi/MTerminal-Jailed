#import "VT100.h"
#import "MTPreferences.h"
#import "VT100Row.h"
#import "VT100Screen.h"
#include <util.h>
#include <sys/ioctl.h>

@implementation VT100
@synthesize tableView;

-(void)startSubProcess {
  if(fileHandle){return;}
  int fd;
  pid_t pid=forkpty(&fd,NULL,NULL,NULL);
  if(pid==-1){
    [NSException raise:@"ForkException"
     format:@"forkpty failed (%d: %s)",errno,strerror(errno)];
    return;
  }
  else if(pid==0){
    if(execve("/usr/bin/login",
     (char*[]){"login","-fp",getenv("USER")?:"mobile",NULL},
     (char*[]){"TERM=xterm-color",NULL})==-1){
      [NSException raise:@"LoginException"
       format:@"execve(login) failed (%d: %s)",errno,strerror(errno)];
    }
    return;
  }
  child_pid=pid;
  fileHandle=[[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
  [[NSNotificationCenter defaultCenter]
   addObserver:self selector:@selector(dataAvailable:)
   name:NSFileHandleReadCompletionNotification object:fileHandle];
  [fileHandle readInBackgroundAndNotify];
}
-(void)stopSubProcess {
  if(!fileHandle){return;}
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  kill(child_pid,SIGKILL);
  int stat;
  waitpid(child_pid,&stat,WUNTRACED);
  child_pid=0;
  [fileHandle release];
  fileHandle=nil;
}
-(id)init {
  if((self=[super init])){
    MTPreferences* prefs=[MTPreferences sharedInstance];
    tableView=[[UITableView alloc] init];
    tableView.dataSource=self;
    tableView.indicatorStyle=UIScrollViewIndicatorStyleWhite;
    tableView.backgroundColor=prefs.backgroundColor;
    tableView.allowsSelection=NO;
    tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
    tableView.rowHeight=prefs.glyphSize.height;
    terminal=[[VT100Terminal alloc] init];
    screen=[[VT100Screen alloc] init];
    [terminal setScreen:screen];
    terminal.encoding=NSUTF8StringEncoding;
    screen.terminal=terminal;
    screen.refreshDelegate=self;
    [self startSubProcess];
  }
  return self;
}
-(void)refresh {
  [screen resetDirty];
  [tableView reloadData];
  [tableView scrollToRowAtIndexPath:[NSIndexPath
   indexPathForRow:screen.numberOfLines-1 inSection:0]
   atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}
-(void)dataAvailable:(NSNotification*)note {
  NSData* data=[note.userInfo objectForKey:NSFileHandleNotificationDataItem];
  if(!data.length){
    [self stopSubProcess];
    static const char* msg="[Process completed]\r\nPress any key to restart.\r\n";
    data=[NSData dataWithBytes:msg length:strlen(msg)];
  }
  // Forward the subprocess data into the terminal character handler
  [terminal putStreamData:data];
  while(1){
    VT100TCC token=[terminal getNextToken];
    if(token.type==VT100_WAIT || token.type==VT100CC_NULL){break;}
    if(token.type==VT100_SKIP){NSLog(@"VT100_SKIP");}
    else if(token.type==VT100_NOTSUPPORT){NSLog(@"VT100_NOTSUPPORT");}
    else {[screen putToken:token];}
  }
  [self refresh];
  // Queue another read
  [fileHandle readInBackgroundAndNotify];
}
-(void)updateScreenSize {
  CGSize glyphSize=[MTPreferences sharedInstance].glyphSize;
  CGSize frameSize=tableView.frame.size;
  int width=frameSize.width/glyphSize.width;
  int height=frameSize.height/glyphSize.height;
  [screen resizeWidth:width height:height];
  if(fileHandle){
    struct winsize window_size={.ws_col=width,.ws_row=height};
    if(ioctl(fileHandle.fileDescriptor,TIOCSWINSZ,&window_size)==-1){
      [NSException raise:@"IOException"
       format:@"ioctl(TIOCSWINSZ) failed (%d: %s)",errno,strerror(errno)];
    }
  }
}
-(void)putData:(NSData*)data {
  if(fileHandle){[fileHandle writeData:data];}
  else {
    // The sub process previously exited, restart it at the users request.
    [screen clearBuffer];
    [self startSubProcess];
    [self updateScreenSize];
  }
}
-(NSInteger)numberOfSectionsInTableView:(UITableView*)_tableView {
  return 1;
}
-(NSInteger)tableView:(UITableView*)_tableView numberOfRowsInSection:(NSInteger)section {
  return screen.numberOfLines;
}
-(UITableViewCell*)tableView:(UITableView*)_tableView cellForRowAtIndexPath:(NSIndexPath*)ipath {
  NSAssert(ipath.section==0,@"Invalid section");
  NSUInteger rowIndex=ipath.row;
  NSAssert(rowIndex<screen.numberOfLines,@"Invalid rowIndex");
  UITableViewCell* cell=[tableView dequeueReusableCellWithIdentifier:@"VT100"];
  VT100Row* rowView;
  if(cell){rowView=(VT100Row*)cell.backgroundView;}
  else {
    cell=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
     reuseIdentifier:@"VT100"] autorelease];
    rowView=[[VT100Row alloc] init];
    rowView.screen=screen;
    [cell.backgroundView=rowView release];
  }
  rowView.rowIndex=rowIndex;
  [rowView setNeedsDisplay];
  return cell;  
}
-(void)dealloc {
  [self stopSubProcess];
  [tableView release];
  [screen release];
  [terminal release];
  [super dealloc];
}
@end

#import "MTController.h"
#import "VT100Row.h"
#import "VT100Screen.h"
#include <sys/ioctl.h>
#include <util.h>

@interface UIKeyboardImpl
+(id)sharedInstance;
-(BOOL)isShifted;
-(BOOL)isShiftLocked;
-(void)setShift:(BOOL)shift;
@end

static CGColorRef $_createRGBColor(CGColorSpaceRef rgbspace,NSString* str,unsigned int v) {
  if(str){[[NSScanner scannerWithString:str] scanHexInt:&v];}
  return CGColorCreate(rgbspace,(CGFloat[]){
   ((v>>16)&0xff)/255.,((v>>8)&0xff)/255.,(v&0xff)/255.,1});
}
static CGPoint $_screenOrigin(UIScrollView* view,UIGestureRecognizer* gesture) {
  CGPoint origin=[gesture locationInView:view];
  CGPoint offset=view.contentOffset;
  origin.x-=offset.x;
  origin.y-=offset.y;
  return origin;
}
static CGSize $_screenSize(UIScrollView* view) {
  CGSize size=view.bounds.size;
  UIEdgeInsets inset=view.contentInset;
  size.width-=inset.left+inset.right;
  size.height-=inset.top+inset.bottom;
  return size;
}

@implementation MTController
@synthesize bgColor,bgCursorColor,fgCursorColor;
@synthesize font,glyphAscent,glyphSize;
@synthesize screen;
-(id)init {
  if((self=[super init])){
    kUp=[[NSData alloc] initWithBytesNoCopy:"\x1bOA" length:3 freeWhenDone:NO];
    kDown=[[NSData alloc] initWithBytesNoCopy:"\x1bOB" length:3 freeWhenDone:NO];
    kLeft=[[NSData alloc] initWithBytesNoCopy:"\x1bOD" length:3 freeWhenDone:NO];
    kRight=[[NSData alloc] initWithBytesNoCopy:"\x1bOC" length:3 freeWhenDone:NO];
    kPageUp=[[NSData alloc] initWithBytesNoCopy:"\x1b[5~" length:4 freeWhenDone:NO];
    kPageDown=[[NSData alloc] initWithBytesNoCopy:"\x1b[6~" length:4 freeWhenDone:NO];
    kHome=[[NSData alloc] initWithBytesNoCopy:"\x1bOH" length:3 freeWhenDone:NO];
    kEnd=[[NSData alloc] initWithBytesNoCopy:"\x1bOF" length:3 freeWhenDone:NO];
    kEscape=[[NSData alloc] initWithBytesNoCopy:"\x1b" length:1 freeWhenDone:NO];
    kTab=[[NSData alloc] initWithBytesNoCopy:"\t" length:1 freeWhenDone:NO];
    kInsert=[[NSData alloc] initWithBytesNoCopy:"\x1b[2~" length:4 freeWhenDone:NO];
    kDelete=[[NSData alloc] initWithBytesNoCopy:"\x1b[3~" length:4 freeWhenDone:NO];
    kBackspace=[[NSData alloc] initWithBytesNoCopy:"\x7f" length:1 freeWhenDone:NO];
    NSUserDefaults* defaults=[NSUserDefaults standardUserDefaults];
    // create color palette
    CGColorSpaceRef rgbspace=CGColorSpaceCreateDeviceRGB();
    const unsigned int xterm16[]={
     0x000000,0xcd0000,0x00cd00,0xcdcd00,0x0000ee,0xcd00cd,0x00cdcd,0xe5e5e5,
     0x7f7f7f,0xff0000,0x00ff00,0xffff00,0x5c5cff,0xff00ff,0x00ffff,0xffffff};
    unsigned int i;
    NSArray* palette=[defaults stringArrayForKey:@"palette"];
    NSUInteger count=palette.count;
    for (i=0;i<16;i++){
      colorTable[i]=$_createRGBColor(rgbspace,
       (i<count)?[palette objectAtIndex:i]:nil,xterm16[i]);
    }
    const CGFloat ccValues[]={0,0x5f/255.,0x87/255.,0xaf/255.,0xd7/255.,1};
    for (i=0;i<216;i++){
      colorTable[i+16]=CGColorCreate(rgbspace,
       (CGFloat[]){ccValues[(i/36)%6],ccValues[(i/6)%6],ccValues[i%6],1});
    }
    for (i=0;i<24;i++){
      CGFloat cv=(i*10+8)/255.;
      colorTable[i+232]=CGColorCreate(rgbspace,(CGFloat[]){cv,cv,cv,1});
    }
    bgColor=$_createRGBColor(rgbspace,[defaults stringForKey:@"bgColor"],0x000000);
    bgCursorColor=$_createRGBColor(rgbspace,[defaults stringForKey:@"bgCursorColor"],0x5f5f5f);
    fgCursorColor=$_createRGBColor(rgbspace,[defaults stringForKey:@"fgCursorColor"],0xe5e5e5);
    fgColor=$_createRGBColor(rgbspace,[defaults stringForKey:@"fgColor"],0xd7d7d7);
    fgBoldColor=$_createRGBColor(rgbspace,[defaults stringForKey:@"fgBoldColor"],0xffffff);
    CFRelease(rgbspace);
    // create monospaced font
    CTFontRef reffont=CTFontCreateWithName((CFStringRef)[defaults stringForKey:@"fontName"]?:
     CFSTR("Courier"),[defaults floatForKey:@"fontSize"]?:10,NULL);
    CGGlyph glyph;
    CTFontGetGlyphsForCharacters(reffont,(const unichar[]){'A'},&glyph,1);
    glyphSize.width=CTFontGetAdvancesForGlyphs(reffont,kCTFontDefaultOrientation,&glyph,NULL,1);
    CFNumberRef advance=CFNumberCreate(NULL,kCFNumberCGFloatType,&glyphSize.width);
    // disable common ligatures
    CFNumberRef ligkey=CFNumberCreate(NULL,kCFNumberIntType,(const int[]){1});
    CFNumberRef ligval=CFNumberCreate(NULL,kCFNumberIntType,(const int[]){3});
    CFDictionaryRef ligsetting=CFDictionaryCreate(NULL,
     (const void*[]){kCTFontFeatureTypeIdentifierKey,kCTFontFeatureSelectorIdentifierKey},
     (const void*[]){ligkey,ligval},2,NULL,&kCFTypeDictionaryValueCallBacks);
    CFRelease(ligkey);
    CFRelease(ligval);
    CFArrayRef fsettings=CFArrayCreate(NULL,
     (const void**)&ligsetting,1,&kCFTypeArrayCallBacks);
    CFRelease(ligsetting);
    CFDictionaryRef monoattr=CFDictionaryCreate(NULL,
     (const void*[]){kCTFontFixedAdvanceAttribute,kCTFontFeatureSettingsAttribute},
     (const void*[]){advance,fsettings},2,NULL,&kCFTypeDictionaryValueCallBacks);
    CFRelease(advance);
    CFRelease(fsettings);
    CTFontDescriptorRef monodesc=CTFontDescriptorCreateWithAttributes(monoattr);
    CFRelease(monoattr);
    font=CTFontCreateCopyWithAttributes(reffont,0,NULL,monodesc);
    CFRelease(reffont);
    CFRelease(monodesc);
    glyphAscent=CTFontGetAscent(font);
    glyphSize.height=glyphAscent+CTFontGetDescent(font)+CTFontGetLeading(font);
    // set up VT100
    screen=[[VT100Screen alloc] init];
    terminal=[[VT100Terminal alloc] init];
    terminal.screen=screen;
    terminal.encoding=NSUTF8StringEncoding;
    screen.terminal=terminal;
    screen.refreshDelegate=self;
    NSNotificationCenter* center=[NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(startSubProcess)
     name:UIKeyboardDidShowNotification object:nil];
    [center addObserver:self selector:@selector(updateScreenSize)
     name:UIKeyboardDidHideNotification object:nil];
  }
  return self;
}
-(void)updateScreenSize {
  CGSize screenSize=$_screenSize(self.tableView);
  int width=screenSize.width/glyphSize.width;
  int height=screenSize.height/glyphSize.height;
  if(width<1 || height<1){return;}
  [screen resizeWidth:width height:height];
  if(ptyHandle){
    struct winsize window_size={.ws_col=width,.ws_row=height};
    if(ioctl(ptyHandle.fileDescriptor,TIOCSWINSZ,&window_size)==-1){
      [NSException raise:@"ioctl(TIOCSWINSZ)" format:@"%d: %s",errno,strerror(errno)];
    }
  }
}
-(void)startSubProcess {
  if(!ptyHandle){
    int fd;
    pid_t pid=forkpty(&fd,NULL,NULL,NULL);
    if(pid==-1){
      [NSException raise:@"forkpty" format:@"%d: %s",errno,strerror(errno)];
      return;
    }
    else if(pid==0){
      if(execve("/usr/bin/login",
       (char*[]){"login","-fp",getenv("USER")?:"mobile",NULL},
       (char*[]){"TERM=xterm",NULL})==-1){
        [NSException raise:@"execve(login)" format:@"%d: %s",errno,strerror(errno)];
      }
      return;
    }
    ptyHandle=[[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    ptypid=pid;
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(dataAvailable:)
     name:NSFileHandleReadCompletionNotification object:ptyHandle];
    [ptyHandle readInBackgroundAndNotify];
  }
  [self updateScreenSize];
}
-(void)stopSubProcess:(int*)status {
  if(!ptyHandle){return;}
  [[NSNotificationCenter defaultCenter] removeObserver:self
   name:NSFileHandleReadCompletionNotification object:ptyHandle];
  kill(ptypid,SIGKILL);
  waitpid(ptypid,status,WUNTRACED);
  [ptyHandle release];
  ptyHandle=nil;
}
-(void)dataAvailable:(NSNotification*)note {
  NSData* data=[note.userInfo objectForKey:NSFileHandleNotificationDataItem];
  if(!data.length){
    int status=0;
    [self stopSubProcess:&status];
    data=[[NSString stringWithFormat:@"[Exited with status %d]\r\n"
     "Press any key to restart.\r\n",WIFEXITED(status)?WEXITSTATUS(status):-1]
     dataUsingEncoding:NSUTF8StringEncoding];
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
  [ptyHandle readInBackgroundAndNotify];
}
-(void)putData:(NSData*)data {
  if(ptyHandle){[ptyHandle writeData:data];}
  else {
    // The sub process previously exited, restart it at the users request.
    [screen clearBuffer];
    [self startSubProcess];
  }
}
-(BOOL)canBecomeFirstResponder {
  return YES;
}
-(UITextAutocapitalizationType)autocapitalizationType {
  return UITextAutocapitalizationTypeNone;
}
-(UITextAutocorrectionType)autocorrectionType {
  return UITextAutocorrectionTypeNo;
}
-(UIKeyboardAppearance)keyboardAppearance {
  return UIKeyboardAppearanceDark;
}
-(UIKeyboardType)keyboardType {
  return UIKeyboardTypeASCIICapable;
}
-(BOOL)hasText {
  return YES;// Make sure that the backspace key always works
}
-(void)deleteBackward {
  [self putData:kBackspace];
}
-(void)insertText:(NSString*)input {
  if(ctrlDown && input.length==1){
    unichar c=[input characterAtIndex:0];
    if(c>0x40 && c<0x60){c-=0x40;}
    else if(c>0x60 && c<0x7b){c-=0x60;}
    else {goto __sendKey;}
    input=[NSString stringWithCharacters:&c length:1];
  }
  else if([input isEqualToString:@"\n"]){input=@"\r";}
  __sendKey:[self putData:[input dataUsingEncoding:NSUTF8StringEncoding]];
}
-(CGColorRef)colorAtIndex:(unsigned int)index {
  return (index&COLOR_CODE_MASK)?
   (index==CURSOR_TEXT)?fgCursorColor:(index==CURSOR_BG)?bgCursorColor:
   (index==BG_COLOR_CODE || index==BG_COLOR_CODE+BOLD_MASK)?bgColor:
   (index&BOLD_MASK)?fgBoldColor:fgColor:colorTable[index&0xff];
}
-(void)refresh {
  [screen resetDirty];
  UITableView* tableView=self.tableView;
  [tableView reloadData];
  [tableView scrollToRowAtIndexPath:[NSIndexPath
   indexPathForRow:screen.numberOfLines-1 inSection:0]
   atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}
-(NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return 1;
}
-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  return screen.numberOfLines;
}
-(UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)ipath {
  NSUInteger rowIndex=ipath.row;
  UITableViewCell* cell=[tableView dequeueReusableCellWithIdentifier:@"Cell"];
  if(!cell){
    cell=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
     reuseIdentifier:@"Cell"] autorelease];
    [cell.backgroundView=[[VT100Row alloc] initWithDelegate:self] release];
  }
  [(VT100Row*)cell.backgroundView setRowIndex:rowIndex];
  return cell;
}
-(void)handleZoneGesture:(UIGestureRecognizer*)gesture {
  UITableView* tableView=self.tableView;
  CGPoint origin=$_screenOrigin(tableView,gesture);
  CGSize size=$_screenSize(tableView);
  UIKeyboardImpl* keyboard=[UIKeyboardImpl sharedInstance];
  BOOL right=(origin.x>size.width-60),shift=keyboard.isShifted;
  NSData* input=(origin.y<60)?right?kDelete:(origin.x<60)?kInsert:shift?kPageUp:kUp:
   (origin.y>size.height-60)?right?kTab:(origin.x<60)?kEscape:shift?kPageDown:kDown:
   right?shift?kEnd:kRight:(origin.x<60)?shift?kHome:kLeft:nil;
  if(input){
    [self putData:input];
    if(shift && !keyboard.isShiftLocked){[keyboard setShift:NO];}
  }
}
-(void)handlePasteGesture:(UIGestureRecognizer*)gesture {
  UIPasteboard* pb=[UIPasteboard generalPasteboard];
  if([pb containsPasteboardTypes:UIPasteboardTypeListString]){
    [self putData:[pb dataForPasteboardType:@"public.utf8-plain-text"]];
  }
}
-(void)handleRepeatGesture:(UIGestureRecognizer*)gesture {
  if(gesture.state==UIGestureRecognizerStateBegan){
    if(repeatTimer){return;}
    UITableView* tableView=self.tableView;
    CGPoint origin=$_screenOrigin(tableView,gesture);
    CGSize size=$_screenSize(tableView);
    NSData* input=(origin.x<60)?kLeft:(origin.x>size.width-60)?kRight:
     (origin.y<60)?kUp:(origin.y>size.height-60)?kDown:nil;
    if(input){
      repeatTimer=[[NSTimer scheduledTimerWithTimeInterval:0.1
       target:self selector:@selector(repeatTimerFired:)
       userInfo:input repeats:YES] retain];
    }
  }
  else if(gesture.state==UIGestureRecognizerStateEnded){
    if(!repeatTimer){return;}
    [repeatTimer invalidate];
    [repeatTimer release];
    repeatTimer=nil;
  }
}
-(void)repeatTimerFired:(NSTimer*)timer {
  [self putData:timer.userInfo];
}
-(void)handleCtrlGesture:(UIGestureRecognizer*)gesture {
  if(gesture.state==UIGestureRecognizerStateBegan){ctrlDown=YES;}
  else if(gesture.state==UIGestureRecognizerStateEnded){ctrlDown=NO;}
}
-(void)handleKeyboardGesture:(UIGestureRecognizer*)gesture {
  if(gesture.state==UIGestureRecognizerStateBegan){
    if(self.isFirstResponder){[self resignFirstResponder];}
    else {[self becomeFirstResponder];}
  }
}
-(BOOL)gestureRecognizer:(UIGestureRecognizer*)gesture1 shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer*)gesture2 {
  return YES;
}
-(void)viewDidLoad {
  UITableView* tableView=self.tableView;
  tableView.indicatorStyle=UIScrollViewIndicatorStyleWhite;
  tableView.backgroundColor=[UIColor colorWithCGColor:bgColor];
  tableView.allowsSelection=NO;
  tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
  tableView.rowHeight=glyphSize.height;
  UITapGestureRecognizer* zoneGesture=[[UITapGestureRecognizer alloc]
   initWithTarget:self action:@selector(handleZoneGesture:)];
  [tableView addGestureRecognizer:zoneGesture];
  [zoneGesture release];
  UITapGestureRecognizer* pasteGesture=[[UITapGestureRecognizer alloc]
   initWithTarget:self action:@selector(handlePasteGesture:)];
  pasteGesture.numberOfTouchesRequired=2;
  pasteGesture.numberOfTapsRequired=2;
  [tableView addGestureRecognizer:pasteGesture];
  [pasteGesture release];
  UILongPressGestureRecognizer* repeatGesture=[[UILongPressGestureRecognizer alloc]
   initWithTarget:self action:@selector(handleRepeatGesture:)];
  repeatGesture.minimumPressDuration=0.25;
  [tableView addGestureRecognizer:repeatGesture];
  [repeatGesture release];
  UILongPressGestureRecognizer* ctrlGesture=[[UILongPressGestureRecognizer alloc]
   initWithTarget:self action:@selector(handleCtrlGesture:)];
  ctrlGesture.minimumPressDuration=0;
  ctrlGesture.cancelsTouchesInView=NO;
  ctrlGesture.delegate=self;
  [tableView addGestureRecognizer:ctrlGesture];
  [ctrlGesture release];
  UILongPressGestureRecognizer* kbGesture=[[UILongPressGestureRecognizer alloc]
   initWithTarget:self action:@selector(handleKeyboardGesture:)];
  kbGesture.numberOfTouchesRequired=2;
  [tableView addGestureRecognizer:kbGesture];
  [kbGesture release];
}
-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return orientation==UIInterfaceOrientationPortrait
   || orientation==UIInterfaceOrientationLandscapeLeft
   || orientation==UIInterfaceOrientationLandscapeRight;
}
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation {
  if(!self.isFirstResponder){[self updateScreenSize];}
}
-(void)dealloc {
  [self stopSubProcess:NULL];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [kUp release];
  [kDown release];
  [kLeft release];
  [kRight release];
  [kPageUp release];
  [kPageDown release];
  [kHome release];
  [kEnd release];
  [kEscape release];
  [kTab release];
  [kInsert release];
  [kDelete release];
  [kBackspace release];
  unsigned int i;
  for (i=0;i<256;i++){CFRelease(colorTable[i]);}
  CFRelease(bgColor);
  CFRelease(bgCursorColor);
  CFRelease(fgCursorColor);
  CFRelease(fgColor);
  CFRelease(fgBoldColor);
  CFRelease(font);
  [repeatTimer release];
  [screen release];
  [terminal release];
  [super dealloc];
}
@end

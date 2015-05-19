#include "MTController.h"
#include "VT100.h"
#include "VT100Row.h"
#include "vttext.h"
#include <sys/ioctl.h>
#include <util.h>

@interface UIKeyboardImpl
+(id)sharedInstance;
-(BOOL)isShifted;
-(BOOL)isShiftLocked;
-(void)setShift:(BOOL)shift;
@end

static CGColorRef $_createRGBColor(CGColorSpaceRef rgbspace,CFMutableDictionaryRef unique,NSString* str,unsigned int v) {
  if(str){[[NSScanner scannerWithString:str] scanHexInt:&v];}
  const void* existing=CFDictionaryGetValue(unique,(void*)(v&0xffffff));
  return existing?(CGColorRef)CFRetain(existing):
   CGColorCreate(rgbspace,(CGFloat[]){
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
-(id)init {
  if((self=[super init])){
    kUp=[[NSData alloc] initWithBytesNoCopy:"\033OA" length:3 freeWhenDone:NO];
    kDown=[[NSData alloc] initWithBytesNoCopy:"\033OB" length:3 freeWhenDone:NO];
    kLeft=[[NSData alloc] initWithBytesNoCopy:"\033OD" length:3 freeWhenDone:NO];
    kRight=[[NSData alloc] initWithBytesNoCopy:"\033OC" length:3 freeWhenDone:NO];
    kPageUp=[[NSData alloc] initWithBytesNoCopy:"\033[5~" length:4 freeWhenDone:NO];
    kPageDown=[[NSData alloc] initWithBytesNoCopy:"\033[6~" length:4 freeWhenDone:NO];
    kHome=[[NSData alloc] initWithBytesNoCopy:"\033OH" length:3 freeWhenDone:NO];
    kEnd=[[NSData alloc] initWithBytesNoCopy:"\033OF" length:3 freeWhenDone:NO];
    kEscape=[[NSData alloc] initWithBytesNoCopy:"\033" length:1 freeWhenDone:NO];
    kTab=[[NSData alloc] initWithBytesNoCopy:"\t" length:1 freeWhenDone:NO];
    kInsert=[[NSData alloc] initWithBytesNoCopy:"\033[2~" length:4 freeWhenDone:NO];
    kDelete=[[NSData alloc] initWithBytesNoCopy:"\033[3~" length:4 freeWhenDone:NO];
    kBackspace=[[NSData alloc] initWithBytesNoCopy:"\177" length:1 freeWhenDone:NO];
    // create color palette
    NSUserDefaults* defaults=[NSUserDefaults standardUserDefaults];
    CGColorSpaceRef rgbspace=CGColorSpaceCreateDeviceRGB();
    CFMutableDictionaryRef unique=CFDictionaryCreateMutable(NULL,0,NULL,NULL);
    const unsigned char cvalues[]={0,0x5f,0x87,0xaf,0xd7,1};
    unsigned int i,z=16;
    for (i=0;i<6;i++){
      unsigned int rv=cvalues[i],j;
      CGFloat r=rv/255.;rv<<=16;
      for (j=0;j<6;j++){
        unsigned int gv=cvalues[j],k;
        CGFloat g=gv/255.;gv<<=8;
        for (k=0;k<6;k++){
          unsigned int bv=cvalues[k];
          CFDictionaryAddValue(unique,(void*)(rv|gv|bv),
           colorTable[z++]=CGColorCreate(rgbspace,(CGFloat[]){r,g,bv/255.,1}));
        }
      }
    }
    for (i=0;i<24;i++){
      unsigned int cv=i*10+8;
      CGFloat c=cv/255.;
      CFDictionaryAddValue(unique,(void*)((cv<<16)|(cv<<8)|cv),
       colorTable[z++]=CGColorCreate(rgbspace,(CGFloat[]){c,c,c,1}));
    }
    nullColor=CGColorCreate(rgbspace,(CGFloat[]){0,0,0,0});
    const unsigned int xterm16[]={
     0x000000,0xcd0000,0x00cd00,0xcdcd00,0x0000ee,0xcd00cd,0x00cdcd,0xe5e5e5,
     0x7f7f7f,0xff0000,0x00ff00,0xffff00,0x5c5cff,0xff00ff,0x00ffff,0xffffff};
    NSArray* palette=[defaults stringArrayForKey:@"palette"];
    NSUInteger count=palette.count;
    for (i=0;i<16;i++){
      colorTable[i]=$_createRGBColor(rgbspace,unique,
       (i<count)?[palette objectAtIndex:i]:nil,xterm16[i]);
    }
    bgDefault=$_createRGBColor(rgbspace,unique,
     [defaults stringForKey:@"bgColor"],0x000000);
    bgCursor=$_createRGBColor(rgbspace,unique,
     [defaults stringForKey:@"bgCursorColor"],0x5f5f5f);
    fgDefault=$_createRGBColor(rgbspace,unique,
     [defaults stringForKey:@"fgColor"],0xd7d7d7);
    fgBold=$_createRGBColor(rgbspace,unique,
     [defaults stringForKey:@"fgBoldColor"],0xffffff);
    fgCursor=$_createRGBColor(rgbspace,unique,
     [defaults stringForKey:@"fgCursorColor"],0xe5e5e5);
    CFRelease(rgbspace);
    CFRelease(unique);
    // set up fonts
    ctFont=CTFontCreateWithName((CFStringRef)[defaults stringForKey:@"fontName"]?:
     CFSTR("Courier"),[defaults floatForKey:@"fontSize"]?:10,NULL);
    CTFontSymbolicTraits traits=CTFontGetSymbolicTraits(ctFont)
     ^kCTFontBoldTrait^kCTFontItalicTrait;
    ctFontBold=CTFontCreateCopyWithSymbolicTraits(ctFont,0,NULL,
     traits,kCTFontBoldTrait)?:CFRetain(ctFont);
    ctFontItalic=CTFontCreateCopyWithSymbolicTraits(ctFont,0,NULL,
     traits,kCTFontItalicTrait)?:CFRetain(ctFont);
    ctFontBoldItalic=CTFontCreateCopyWithSymbolicTraits(ctFont,0,NULL,
     traits,kCTFontBoldTrait^kCTFontItalicTrait)?:CFRetain(ctFont);
    int ul1=kCTUnderlineStyleSingle,ul2=kCTUnderlineStyleDouble;
    ctUnderlineStyleSingle=CFNumberCreate(NULL,kCFNumberIntType,&ul1);
    ctUnderlineStyleDouble=CFNumberCreate(NULL,kCFNumberIntType,&ul2);
    glyphAscent=CTFontGetAscent(ctFont);
    glyphHeight=glyphAscent+CTFontGetDescent(ctFont);
    glyphMidY=glyphAscent-CTFontGetXHeight(ctFont)/2;
    CGGlyph glyph;
    CTFontGetGlyphsForCharacters(ctFont,(const unichar[]){'$'},&glyph,1);
    colWidth=CTFontGetAdvancesForGlyphs(ctFont,kCTFontDefaultOrientation,&glyph,NULL,1);
    NSNumber* leading=[defaults objectForKey:@"fontLeading"];
    rowHeight=glyphHeight+(leading?leading.floatValue:CTFontGetLeading(ctFont));
    // get bell sound
    CFBundleRef bundle=CFBundleGetMainBundle();
    CFURLRef soundURL=CFBundleCopyResourceURL(bundle,CFSTR("bell"),CFSTR("caf"),NULL);
    if(soundURL){
      bellSound=AudioServicesCreateSystemSoundID(soundURL,
       &bellSoundID)==kAudioServicesNoError;
      CFRelease(soundURL);
    }
    // observe keyboard show/hide events
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
  CFIndex width=screenSize.width/colWidth;
  CFIndex height=screenSize.height/rowHeight;
  if(width<1 || height<1){return;}
  if(vt100){[vt100 setWidth:width height:height];}
  else {vt100=[[VT100 alloc] initWithWidth:width height:height];}
  if(ptyHandle && ioctl(ptyHandle.fileDescriptor,TIOCSWINSZ,
   &(struct winsize){.ws_col=width,.ws_row=height})==-1){
    [NSException raise:@"ioctl(TIOCSWINSZ)"
     format:@"%d: %s",errno,strerror(errno)];
  }
}
-(void)startSubProcess {
  if(!ptyHandle){
    int fd;
    pid_t pid=forkpty(&fd,NULL,NULL,NULL);
    if(pid==-1){
      [NSException raise:@"forkpty"
       format:@"%d: %s",errno,strerror(errno)];
      return;
    }
    else if(pid==0){
      if(execve("/usr/bin/login",
       (char*[]){"login","-fp",getenv("USER")?:"mobile",NULL},
       (char*[]){"TERM=xterm",NULL})==-1){
        [NSException raise:@"execve(login)"
         format:@"%d: %s",errno,strerror(errno)];
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
  NSData* input=[note.userInfo objectForKey:NSFileHandleNotificationDataItem];
  if(!input.length){
    int status=0;
    [self stopSubProcess:&status];
    input=[[NSString stringWithFormat:@"[Exited with status %d]\r\n"
     "Press any key to restart.\r\n",WIFEXITED(status)?WEXITSTATUS(status):-1]
     dataUsingEncoding:NSASCIIStringEncoding];
  }
  BOOL bell=NO;
  NSMutableData* output=[NSMutableData dataWithLength:0];
  [vt100 processInput:input output:output bell:&bell];
  if(output.length){[ptyHandle writeData:output];}
  if(bell && bellSound){AudioServicesPlaySystemSound(bellSoundID);}
  //! TODO: refresh only what changed
  UITableView* tableView=self.tableView;
  [tableView reloadData];
  [tableView scrollToRowAtIndexPath:[NSIndexPath
   indexPathForRow:vt100.numberOfLines-1 inSection:0]
   atScrollPosition:UITableViewScrollPositionBottom animated:NO];
  [ptyHandle readInBackgroundAndNotify];
}
-(void)sendData:(NSData*)data {
  if(ptyHandle){[ptyHandle writeData:data];}
  else {
    // restart the subprocess
    [vt100 resetTerminal];
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
  return UIKeyboardTypeDefault;
}
-(BOOL)hasText {
  return YES;// always enable the backspace key
}
-(void)deleteBackward {
  [self sendData:kBackspace];
}
-(void)insertText:(NSString*)text {
  if(text.length==1){
    unichar c=[text characterAtIndex:0];
    if(c=='\n'){// send CR or CRLF
      [self sendData:vt100.returnKey];
      return;
    }
    if(ctrlDown){
      if(c>0x40 && c<0x5b){c-=0x40;}
      else if(c>0x60 && c<0x7b){c-=0x60;}
    }
    if(c<0x80){// send an ASCII character
      [self sendData:[NSData dataWithBytes:(char[]){c} length:1]];
      return;
    }
  }
  // send the encoded string
  [self sendData:[text dataUsingEncoding:vt100.encoding]];
}
-(NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return 1;
}
-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  return vt100.numberOfLines;
}
-(UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)ipath {
  UITableViewCell* cell=[tableView dequeueReusableCellWithIdentifier:@"Cell"];
  VT100Row* rowView;
  if(cell){rowView=(VT100Row*)cell.backgroundView;}
  else {
    cell=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
     reuseIdentifier:@"Cell"] autorelease];
    cell.backgroundView=rowView=[[[VT100Row alloc] initWithBackgroundColor:bgDefault
     ascent:glyphAscent height:glyphHeight midY:glyphMidY] autorelease];
  }
  CFIndex length,cursorPosition;
  screen_char_t* ptr=[vt100 charactersAtLineIndex:ipath.row
   length:&length cursorPosition:&cursorPosition];
  if(ptr){
    unichar* ucbuf=malloc(length*sizeof(unichar));
    CFIndex i;
    for (i=0;i<length;i++){ucbuf[i]=ptr[i].c?:' ';}
    CFStringRef ucstr=CFStringCreateWithCharactersNoCopy(NULL,ucbuf,length,kCFAllocatorMalloc);
    CFMutableAttributedStringRef string=CFAttributedStringCreateMutable(NULL,length);
    CFAttributedStringBeginEditing(string);
    CFAttributedStringReplaceString(string,CFRangeMake(0,0),ucstr);
    CFRelease(ucstr);// will automatically free(ucbuf)
    CTFontRef fontface=NULL;
    CGColorRef bgcolor=NULL,fgcolor=NULL,stcolor=NULL,ulcolor=NULL;
    CFNumberRef ulstyle=NULL;
    CFIndex ffspan=0,bgcspan=0,fgcspan=0,stcspan=0,ulcspan=0,ulsspan=0;
    for (i=0;i<=length;i++,ptr++){
      CTFontRef ff;
      CGColorRef bgc,fgc,stc,ulc;
      CFNumberRef uls;
      if(i==length){
        ff=NULL;
        bgc=fgc=stc=ulc=NULL;
        uls=NULL;
      }
      else {
        ff=(ptr->bold==1)?ptr->italicize?ctFontBoldItalic:ctFontBold:
         ptr->italicize?ctFontItalic:ctFont;
        if(i==cursorPosition){
          bgc=bgCursor;
          fgc=fgCursor;
        }
        else {
          bgc=ptr->bgcolor_isset?colorTable[ptr->bgcolor]:bgDefault;
          fgc=ptr->fgcolor_isset?colorTable[(ptr->bold && ptr->fgcolor<8)?
           ptr->fgcolor+8:ptr->fgcolor]:ptr->bold?fgBold:fgDefault;
          if(ptr->inverse){
            CGColorRef _fgc=fgc;
            fgc=bgc;
            bgc=_fgc;
          }
        }
        stc=(ptr->strikethrough && fgc!=bgc)?fgc:NULL;
        switch(ptr->underline){
          case 1:
            ulc=fgc;
            uls=ctUnderlineStyleSingle;
            break;
          case 2:
            ulc=fgc;
            uls=ctUnderlineStyleDouble;
            break;
          default:
            ulc=NULL;
            uls=NULL;
            break;
        }
        if(ptr->hidden){fgc=nullColor;}
        if(bgc==bgDefault){bgc=NULL;}
      }
      if(fontface==ff){ffspan++;}
      else {
        if(fontface) CFAttributedStringSetAttribute(
         string,CFRangeMake(i-ffspan,ffspan),
         kCTFontAttributeName,fontface);
        fontface=ff;
        ffspan=1;
      }
      if(bgcolor==bgc){bgcspan++;}
      else {
        if(bgcolor) CFAttributedStringSetAttribute(
         string,CFRangeMake(i-bgcspan,bgcspan),
         kVTBackgroundColorAttributeName,bgcolor);
        bgcolor=bgc;
        bgcspan=1;
      }
      if(fgcolor==fgc){fgcspan++;}
      else {
        if(fgcolor) CFAttributedStringSetAttribute(
         string,CFRangeMake(i-fgcspan,fgcspan),
         kCTForegroundColorAttributeName,fgcolor);
        fgcolor=fgc;
        fgcspan=1;
      }
      if(stcolor==stc){stcspan++;}
      else {
        if(stcolor) CFAttributedStringSetAttribute(
         string,CFRangeMake(i-stcspan,stcspan),
         kVTStrikethroughColorAttributeName,stcolor);
        stcolor=stc;
        stcspan=1;
      }
      if(ulcolor==stc){ulcspan++;}
      else {
        if(ulcolor) CFAttributedStringSetAttribute(
         string,CFRangeMake(i-ulcspan,ulcspan),
         kCTUnderlineColorAttributeName,ulcolor);
        ulcolor=ulc;
        ulcspan=1;
      }
      if(ulstyle==uls){ulsspan++;}
      else {
        if(ulstyle) CFAttributedStringSetAttribute(
         string,CFRangeMake(i-ulsspan,ulsspan),
         kCTUnderlineStyleAttributeName,ulstyle);
        ulstyle=uls;
        ulsspan=1;
      }
    }
    CFAttributedStringEndEditing(string);
    [rowView renderString:string];
    CFRelease(string);
  }
  return cell;
}
-(void)handleZoneGesture:(UIGestureRecognizer*)gesture {
  UITableView* tableView=self.tableView;
  CGPoint origin=$_screenOrigin(tableView,gesture);
  CGSize size=$_screenSize(tableView);
  UIKeyboardImpl* keyboard=[UIKeyboardImpl sharedInstance];
  BOOL right=(origin.x>size.width-60),shift=keyboard.isShifted;
  NSData* kdata=(origin.y<60)?right?kDelete:(origin.x<60)?kInsert:shift?kPageUp:kUp:
   (origin.y>size.height-60)?right?kTab:(origin.x<60)?kEscape:shift?kPageDown:kDown:
   right?shift?kEnd:kRight:(origin.x<60)?shift?kHome:kLeft:nil;
  if(kdata){
    [self sendData:kdata];
    if(shift && !keyboard.isShiftLocked){[keyboard setShift:NO];}
  }
}
-(void)handlePasteGesture:(UIGestureRecognizer*)gesture {
  UIPasteboard* pb=[UIPasteboard generalPasteboard];
  if([pb containsPasteboardTypes:UIPasteboardTypeListString]){
    [self sendData:[pb dataForPasteboardType:@"public.text"]];
  }
}
-(void)handleRepeatGesture:(UIGestureRecognizer*)gesture {
  if(gesture.state==UIGestureRecognizerStateBegan){
    if(repeatTimer){return;}
    UITableView* tableView=self.tableView;
    CGPoint origin=$_screenOrigin(tableView,gesture);
    CGSize size=$_screenSize(tableView);
    NSData* kdata=(origin.x<60)?kLeft:(origin.x>size.width-60)?kRight:
     (origin.y<60)?kUp:(origin.y>size.height-60)?kDown:nil;
    if(kdata){
      repeatTimer=[[NSTimer scheduledTimerWithTimeInterval:0.1
       target:self selector:@selector(repeatTimerFired:)
       userInfo:kdata repeats:YES] retain];
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
  [self sendData:timer.userInfo];
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
  tableView.backgroundColor=[UIColor colorWithCGColor:bgDefault];
  tableView.allowsSelection=NO;
  tableView.separatorStyle=UITableViewCellSeparatorStyleNone;
  tableView.rowHeight=rowHeight;
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
  CFRelease(nullColor);
  CFRelease(bgDefault);
  CFRelease(bgCursor);
  CFRelease(fgDefault);
  CFRelease(fgBold);
  CFRelease(fgCursor);
  CFRelease(ctFont);
  CFRelease(ctFontBold);
  CFRelease(ctFontItalic);
  CFRelease(ctFontBoldItalic);
  CFRelease(ctUnderlineStyleSingle);
  CFRelease(ctUnderlineStyleDouble);
  if(bellSound){AudioServicesDisposeSystemSoundID(bellSoundID);}
  [vt100 release];
  [repeatTimer release];
  [super dealloc];
}
@end

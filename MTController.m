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
    // set up normal cursor keys
    kbUp[0]=[[NSData alloc] initWithBytesNoCopy:"\033[A" length:3 freeWhenDone:NO];
    kbDown[0]=[[NSData alloc] initWithBytesNoCopy:"\033[B" length:3 freeWhenDone:NO];
    kbRight[0]=[[NSData alloc] initWithBytesNoCopy:"\033[C" length:3 freeWhenDone:NO];
    kbLeft[0]=[[NSData alloc] initWithBytesNoCopy:"\033[D" length:3 freeWhenDone:NO];
    kbHome[0]=[[NSData alloc] initWithBytesNoCopy:"\033[H" length:3 freeWhenDone:NO];
    kbEnd[0]=[[NSData alloc] initWithBytesNoCopy:"\033[F" length:3 freeWhenDone:NO];
    // set up application cursor keys
    kbUp[1]=[[NSData alloc] initWithBytesNoCopy:"\033OA" length:3 freeWhenDone:NO];
    kbDown[1]=[[NSData alloc] initWithBytesNoCopy:"\033OB" length:3 freeWhenDone:NO];
    kbRight[1]=[[NSData alloc] initWithBytesNoCopy:"\033OC" length:3 freeWhenDone:NO];
    kbLeft[1]=[[NSData alloc] initWithBytesNoCopy:"\033OD" length:3 freeWhenDone:NO];
    kbHome[1]=[[NSData alloc] initWithBytesNoCopy:"\033OH" length:3 freeWhenDone:NO];
    kbEnd[1]=[[NSData alloc] initWithBytesNoCopy:"\033OF" length:3 freeWhenDone:NO];
    // set up other PC-style function keys
    kbInsert=[[NSData alloc] initWithBytesNoCopy:"\033[2~" length:4 freeWhenDone:NO];
    kbDelete=[[NSData alloc] initWithBytesNoCopy:"\033[3~" length:4 freeWhenDone:NO];
    kbPageUp=[[NSData alloc] initWithBytesNoCopy:"\033[5~" length:4 freeWhenDone:NO];
    kbPageDown=[[NSData alloc] initWithBytesNoCopy:"\033[6~" length:4 freeWhenDone:NO];
    // set up miscellaneous keys
    kbTab=[[NSData alloc] initWithBytesNoCopy:"\t" length:1 freeWhenDone:NO];
    kbEscape=[[NSData alloc] initWithBytesNoCopy:"\033" length:1 freeWhenDone:NO];
    kbBack[0]=[[NSData alloc] initWithBytesNoCopy:"\177" length:1 freeWhenDone:NO];
    kbBack[1]=[[NSData alloc] initWithBytesNoCopy:"\b" length:1 freeWhenDone:NO];
    const char CRLF[]={'\r','\n'};
    kbReturn[0]=[[NSData alloc] initWithBytesNoCopy:(char*)CRLF length:1 freeWhenDone:NO];
    kbReturn[1]=[[NSData alloc] initWithBytesNoCopy:(char*)CRLF length:2 freeWhenDone:NO];
    // set up color palette
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
    // set up typeface
    ctFont=CTFontCreateWithName(
     (CFStringRef)[defaults stringForKey:@"fontName"]?:CFSTR("Courier"),
     [defaults floatForKey:@"fontSize"]?:10,NULL);
    id advance=[defaults objectForKey:@"columnWidth"];
    unichar mchar='$';// default model character
    if([advance isKindOfClass:[NSString class]]){
      // use a different model character to calculate the column width
      if([advance length]){mchar=[advance characterAtIndex:0];}
    }
    else if((colWidth=[advance floatValue])>0){mchar=0;}
    if(mchar){
      CGGlyph mglyph;
      CTFontGetGlyphsForCharacters(ctFont,&mchar,&mglyph,1);
      colWidth=CTFontGetAdvancesForGlyphs(ctFont,
       kCTFontDefaultOrientation,&mglyph,NULL,1);
    }
    if(![defaults boolForKey:@"fontProportional"]){
      // turn off all optional ligatures
      const int values[]={kCommonLigaturesOffSelector,kRareLigaturesOffSelector,
       kLogosOffSelector,kRebusPicturesOffSelector,kDiphthongLigaturesOffSelector,
       kSquaredLigaturesOffSelector,kAbbrevSquaredLigaturesOffSelector,
       kSymbolLigaturesOffSelector,kContextualLigaturesOffSelector,
       kHistoricalLigaturesOffSelector};
      const size_t nvalues=sizeof(values)/sizeof(int);
      const int key=kLigaturesType;
      CFNumberRef ligkey=CFNumberCreate(NULL,kCFNumberIntType,&key);
      CFMutableArrayRef ffsettings=CFArrayCreateMutable(NULL,nvalues,&kCFTypeArrayCallBacks);
      for (i=0;i<nvalues;i++){
        CFNumberRef ligvalue=CFNumberCreate(NULL,kCFNumberIntType,&values[i]);
        CFDictionaryRef ligsetting=CFDictionaryCreate(NULL,
         (const void*[]){kCTFontFeatureTypeIdentifierKey,kCTFontFeatureSelectorIdentifierKey},
         (const void*[]){ligkey,ligvalue},2,NULL,&kCFTypeDictionaryValueCallBacks);
        CFRelease(ligvalue);
        CFArrayAppendValue(ffsettings,ligsetting);
        CFRelease(ligsetting);
      }
      CFRelease(ligkey);
      // set fixed advance
      CFNumberRef advance=CFNumberCreate(NULL,kCFNumberCGFloatType,&colWidth);
      CFDictionaryRef attrdict=CFDictionaryCreate(NULL,
       (const void*[]){kCTFontFixedAdvanceAttribute,kCTFontFeatureSettingsAttribute},
       (const void*[]){advance,ffsettings},2,NULL,&kCFTypeDictionaryValueCallBacks);
      CFRelease(advance);
      CFRelease(ffsettings);
      CTFontDescriptorRef desc=CTFontDescriptorCreateWithAttributes(attrdict);
      CFRelease(attrdict);
      // try to derive a new font
      CTFontRef font=CTFontCreateCopyWithAttributes(ctFont,0,NULL,desc);
      CFRelease(desc);
      if(font){
        CFRelease(ctFont);
        ctFont=font;
      }
    }
    glyphAscent=CTFontGetAscent(ctFont);
    glyphHeight=glyphAscent+CTFontGetDescent(ctFont);
    glyphMidY=glyphAscent-CTFontGetXHeight(ctFont)/2;
    NSNumber* leading=[defaults objectForKey:@"lineSpacing"];
    rowHeight=glyphHeight+(leading?leading.floatValue:CTFontGetLeading(ctFont));
    CTFontSymbolicTraits traits=CTFontGetSymbolicTraits(ctFont)
     ^kCTFontBoldTrait^kCTFontItalicTrait;
    ctFontBold=CTFontCreateCopyWithSymbolicTraits(ctFont,0,NULL,
     traits,kCTFontBoldTrait)?:CFRetain(ctFont);
    ctFontItalic=CTFontCreateCopyWithSymbolicTraits(ctFont,0,NULL,
     traits,kCTFontItalicTrait)?:CFRetain(ctFont);
    ctFontBoldItalic=CTFontCreateCopyWithSymbolicTraits(ctFont,0,NULL,
     traits,kCTFontBoldTrait^kCTFontItalicTrait)?:CFRetain(ctFont);
    // set up text decoration attributes
    int ul1=kCTUnderlineStyleSingle,ul2=kCTUnderlineStyleDouble;
    ctUnderlineStyleSingle=CFNumberCreate(NULL,kCFNumberIntType,&ul1);
    ctUnderlineStyleDouble=CFNumberCreate(NULL,kCFNumberIntType,&ul2);
    // set up bell sound
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
-(void)redrawScreen {
  CFSetRef iset[3];
  UITableView* tableView=self.tableView;
  if([vt100 copyChanges:&iset[0] deletions:&iset[1] insertions:&iset[2]]){
    [UIView setAnimationsEnabled:NO];
    [tableView beginUpdates];
    unsigned int i;
    for (i=0;i<3;i++){
      CFIndex count=CFSetGetCount(iset[i]),j;
      id* items=malloc(count*sizeof(id));
      CFSetGetValues(iset[i],(const void**)items);
      CFRelease(iset[i]);
      for (j=0;j<count;j++){
        items[j]=[NSIndexPath indexPathForRow:(NSUInteger)items[j] inSection:0];
      }
      NSArray* ipaths=[NSArray arrayWithObjects:items count:count];
      free(items);
      switch(i){
        case 0:[tableView reloadRowsAtIndexPaths:ipaths
         withRowAnimation:UITableViewRowAnimationNone];break;
        case 1:[tableView deleteRowsAtIndexPaths:ipaths
         withRowAnimation:UITableViewRowAnimationNone];break;
        case 2:[tableView insertRowsAtIndexPaths:ipaths
         withRowAnimation:UITableViewRowAnimationNone];break;
      }
    }
    [tableView endUpdates];
    [UIView setAnimationsEnabled:YES];
  }
  else {[tableView reloadData];}
  [tableView scrollToRowAtIndexPath:[NSIndexPath
   indexPathForRow:vt100.numberOfLines-1 inSection:0]
   atScrollPosition:UITableViewScrollPositionBottom animated:NO];
}
-(void)updateScreenSize {
  CGSize screenSize=$_screenSize(self.tableView);
  CFIndex width=screenSize.width/colWidth;
  CFIndex height=screenSize.height/rowHeight;
  if(width<1 || height<1){return;}
  if(vt100){[vt100 setWidth:width height:height];}
  else {
    vt100=[[VT100 alloc] initWithWidth:width height:height];
    vt100.encoding=kCFStringEncodingUTF8;
  }
  if(ptyHandle && ioctl(ptyHandle.fileDescriptor,TIOCSWINSZ,
   &(struct winsize){.ws_col=width,.ws_row=height})==-1){
    [NSException raise:@"ioctl(TIOCSWINSZ)"
     format:@"%d: %s",errno,strerror(errno)];
  }
  [self redrawScreen];
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
    input=[[NSString stringWithFormat:@"\033[m[Exit %d]\r\n\033[1m"
     "Press any key to restart.",WIFEXITED(status)?WEXITSTATUS(status):-1]
     dataUsingEncoding:NSASCIIStringEncoding];
  }
  BOOL bell=NO;
  NSMutableData* output=[NSMutableData dataWithLength:0];
  [vt100 processInput:input output:output bell:&bell];
  if(output.length){[ptyHandle writeData:output];}
  if(bell && bellSound){AudioServicesPlaySystemSound(bellSoundID);}
  [self redrawScreen];
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
-(UITextRange*)selectedTextRange {
  return nil;// from <UITextInput>
}
-(BOOL)hasText {
  return YES;// always enable the backspace key
}
-(void)deleteBackward {
  [self sendData:kbBack[vt100.bDECBKM]];
}
-(void)insertText:(NSString*)text {
  if(text.length==1){
    unichar c=[text characterAtIndex:0];
    if(c=='\n'){// send CR or CRLF
      [self sendData:kbReturn[vt100.bLNM]];
      return;
    }
    if(ctrlDown){// send Control+(A..Z)
      if(c>0x40 && c<0x5b){c-=0x40;}
      else if(c>0x60 && c<0x7b){c-=0x60;}
    }
    if(c<0x80){// send an ASCII character
      [self sendData:[NSData dataWithBytes:(char[]){c} length:1]];
      return;
    }
  }
  // send the encoded string
  [self sendData:[text dataUsingEncoding:NSUTF8StringEncoding]];
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
  CFIndex length,cursorColumn;
  screen_char_t* ptr=[vt100 charactersAtLineIndex:ipath.row
   length:&length cursorColumn:&cursorColumn];
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
        if(i==cursorColumn){
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
  NSData* kbdata=(origin.y<60)?right?kbDelete:(origin.x<60)?kbInsert:
   shift?kbPageUp:kbUp[vt100.bDECCKM]:
   (origin.y>size.height-60)?right?kbTab:(origin.x<60)?kbEscape:
   shift?kbPageDown:kbDown[vt100.bDECCKM]:
   right?shift?kbEnd[vt100.bDECCKM]:kbRight[vt100.bDECCKM]:
   (origin.x<60)?shift?kbHome[vt100.bDECCKM]:kbLeft[vt100.bDECCKM]:nil;
  if(kbdata){
    [self sendData:kbdata];
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
    NSData* kbdata=(origin.x<60)?kbLeft[vt100.bDECCKM]:
     (origin.x>size.width-60)?kbRight[vt100.bDECCKM]:
     (origin.y<60)?kbUp[vt100.bDECCKM]:
     (origin.y>size.height-60)?kbDown[vt100.bDECCKM]:nil;
    if(kbdata){
      repeatTimer=[[NSTimer scheduledTimerWithTimeInterval:0.1
       target:self selector:@selector(repeatTimerFired:)
       userInfo:kbdata repeats:YES] retain];
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
  [kbUp[0] release];
  [kbDown[0] release];
  [kbRight[0] release];
  [kbLeft[0] release];
  [kbHome[0] release];
  [kbEnd[0] release];
  [kbUp[1] release];
  [kbDown[1] release];
  [kbRight[1] release];
  [kbLeft[1] release];
  [kbHome[1] release];
  [kbEnd[1] release];
  [kbInsert release];
  [kbDelete release];
  [kbPageUp release];
  [kbPageDown release];
  [kbTab release];
  [kbEscape release];
  [kbBack[0] release];
  [kbBack[1] release];
  [kbReturn[0] release];
  [kbReturn[1] release];
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

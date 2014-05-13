#import "MTController.h"
#import "MTView.h"
#import "VT100.h"

@interface UIKeyboardImpl
+(id)sharedInstance;
-(BOOL)isShifted;
-(BOOL)isShiftLocked;
-(void)setShift:(BOOL)shift;
@end

@implementation MTController
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
    kEsc=[[NSData alloc] initWithBytesNoCopy:"\x1b" length:1 freeWhenDone:NO];
    kTab=[[NSData alloc] initWithBytesNoCopy:"\t" length:1 freeWhenDone:NO];
    kInsert=[[NSData alloc] initWithBytesNoCopy:"\x1b[2~" length:4 freeWhenDone:NO];
    kDelete=[[NSData alloc] initWithBytesNoCopy:"\x1b[3~" length:4 freeWhenDone:NO];
    NSNotificationCenter* center=[NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(keyboardDidShow:)
     name:UIKeyboardDidShowNotification object:nil];
    [center addObserver:self selector:@selector(keyboardWillHide)
     name:UIKeyboardWillHideNotification object:nil];
  }
  return self;
}
-(void)keyboardDidShow:(NSNotification*)note {
  MTView* view=(MTView*)self.view;
  CGRect frame=view.bounds;
  frame.size.height-=[view.window convertRect:[[note.userInfo
   objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue]
   toView:view].size.height;
  if(!vt100){
    view.receiver=vt100=[[VT100 alloc] init];
    [view addSubview:vt100.tableView];
  }
  vt100.tableView.frame=frame;
  [vt100 updateScreenSize];
}
-(void)keyboardWillHide {
  vt100.tableView.frame=self.view.bounds;
  [vt100 updateScreenSize];
}
-(void)handleSpecialKeyGesture:(UIGestureRecognizer*)gesture {
  MTView* view=(MTView*)self.view;
  CGSize size=vt100.tableView.bounds.size;
  CGPoint origin=[gesture locationInView:view];
  UIKeyboardImpl* keyboard=[UIKeyboardImpl sharedInstance];
  BOOL right=(origin.x>size.width-60),shift=keyboard.isShifted;
  NSData* input=(origin.y<60)?right?kDelete:(origin.x<60)?kInsert:shift?kPageUp:kUp:
   (origin.y>size.height-60)?right?kTab:(origin.x<60)?kEsc:shift?kPageDown:kDown:
   right?shift?kEnd:kRight:(origin.x<60)?shift?kHome:kLeft:nil;
  if(input){
    [vt100 putData:input];
    if(shift && !keyboard.isShiftLocked){[keyboard setShift:NO];}
  }
}
-(void)handlePasteGesture:(UIGestureRecognizer*)gesture {
  UIPasteboard* pb=[UIPasteboard generalPasteboard];
  if([pb containsPasteboardTypes:UIPasteboardTypeListString]){
    [vt100 putData:[pb.string dataUsingEncoding:NSUTF8StringEncoding]];
  }
}
-(void)repeatKey {
  if(!repeating){return;}
  [vt100 putData:repeating];
  [self performSelector:_cmd withObject:nil afterDelay:0.1];
}
-(void)handleRepeatKeyGesture:(UIGestureRecognizer*)gesture {
  if(gesture.state==UIGestureRecognizerStateBegan){
    if(repeating){return;}
    CGSize size=vt100.tableView.bounds.size;
    CGPoint origin=[gesture locationInView:self.view];
    BOOL base=(origin.y>size.height-60);
    if(origin.x<60){
      if(!base){repeating=kLeft;}
    }
    else if(origin.x>size.width-60){
      if(!base){repeating=kRight;}
    }
    else if(base){repeating=kDown;}
    else if(origin.y<60){repeating=kUp;}
    if(repeating){[self repeatKey];}
  }
  else if(gesture.state==UIGestureRecognizerStateEnded){repeating=nil;}
}
-(void)loadView {
  MTView* view=[[MTView alloc] init];
  UITapGestureRecognizer* tgesture;
  tgesture=[[UITapGestureRecognizer alloc]
   initWithTarget:self action:@selector(handleSpecialKeyGesture:)];
  [view addGestureRecognizer:tgesture];
  [tgesture release];
  tgesture=[[UITapGestureRecognizer alloc]
   initWithTarget:self action:@selector(handlePasteGesture:)];
  tgesture.numberOfTouchesRequired=2;
  tgesture.numberOfTapsRequired=2;
  [view addGestureRecognizer:tgesture];
  [tgesture release];
  UILongPressGestureRecognizer* lpgesture;
  lpgesture=[[UILongPressGestureRecognizer alloc]
   initWithTarget:self action:@selector(handleRepeatKeyGesture:)];
  lpgesture.minimumPressDuration=0.25;
  [view addGestureRecognizer:lpgesture];
  [lpgesture release];
  [self.view=view release];
}
-(void)viewDidAppear:(BOOL)animated {
  [self.view becomeFirstResponder];
  [super viewDidAppear:animated];
}
-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return orientation==UIInterfaceOrientationPortrait
   || orientation==UIInterfaceOrientationLandscapeLeft
   || orientation==UIInterfaceOrientationLandscapeRight;
}
-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation {
  if(!self.view.isFirstResponder){[self keyboardWillHide];}
}
-(void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [vt100 release];
  [kUp release];
  [kDown release];
  [kLeft release];
  [kRight release];
  [kPageUp release];
  [kPageDown release];
  [kHome release];
  [kEnd release];
  [kEsc release];
  [kTab release];
  [kInsert release];
  [kDelete release];
  [super dealloc];
}
@end

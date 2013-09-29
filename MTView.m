#import "MTView.h"
#import "VT100.h"

@implementation MTView
@synthesize receiver;
@synthesize selectedTextRange;
@synthesize markedTextStyle;
@synthesize selectionAffinity;
@synthesize inputDelegate;
-(UITextRange*)markedTextRange {return nil;}
-(UITextPosition*)beginningOfDocument {return nil;}
-(UITextPosition*)endOfDocument {return nil;}
-(id<UITextInputTokenizer>)tokenizer {return nil;}
-(UITextRange*)characterRangeAtPoint:(CGPoint)point {return nil;}
-(UITextPosition*)closestPositionToPoint:(CGPoint)point withinRange:(UITextRange*)range {return nil;}
-(UITextPosition*)closestPositionToPoint:(CGPoint)point {return nil;}
-(CGRect)caretRectForPosition:(UITextPosition*)position {return CGRectMake(0,0,0,0);}
-(CGRect)firstRectForRange:(UITextRange*)range {return CGRectMake(0,0,0,0);}
-(void)setBaseWritingDirection:(UITextWritingDirection)writingDirection forRange:(UITextRange*)range {}
-(UITextWritingDirection)baseWritingDirectionForPosition:(UITextPosition*)position inDirection:(UITextStorageDirection)direction {return UITextWritingDirectionNatural;}
-(UITextRange*)characterRangeByExtendingPosition:(UITextPosition*)position inDirection:(UITextLayoutDirection)direction {return nil;}
-(UITextPosition*)positionWithinRange:(UITextRange*)range farthestInDirection:(UITextLayoutDirection)direction {return nil;}
-(NSInteger)offsetFromPosition:(UITextPosition*)position toPosition:(UITextPosition*)toPosition {return 0;}
-(NSComparisonResult)comparePosition:(UITextPosition*)position toPosition:(UITextPosition*)other {return NSOrderedSame;}
-(UITextPosition*)positionFromPosition:(UITextPosition*)position inDirection:(UITextLayoutDirection)direction offset:(NSInteger)offset {return nil;}
-(UITextPosition*)positionFromPosition:(UITextPosition*)position offset:(NSInteger)offset {return nil;}
-(UITextRange*)textRangeFromPosition:(UITextPosition*)fromPosition toPosition:(UITextPosition*)toPosition {return nil;}
-(void)unmarkText {}
-(void)setMarkedText:(NSString*)markedText selectedRange:(NSRange)selectedRange {}
-(void)replaceRange:(UITextRange*)range withText:(NSString*)text {}
-(NSString*)textInRange:(UITextRange*)range {return nil;}

-(UITextAutocapitalizationType)autocapitalizationType {return UITextAutocapitalizationTypeNone;}
-(UITextAutocorrectionType)autocorrectionType {return UITextAutocorrectionTypeNo;}
-(UIKeyboardType)keyboardType {return UIKeyboardTypeASCIICapable;}

-(id)init {
  if((self=[super init])){
    kBackspace=[[NSData alloc] initWithBytesNoCopy:"\x7f" length:1 freeWhenDone:NO];
    UILongPressGestureRecognizer* lpgesture;
    lpgesture=[[UILongPressGestureRecognizer alloc]
     initWithTarget:self action:@selector(toggleControlKey:)];
    lpgesture.minimumPressDuration=0;
    lpgesture.delegate=self;
    lpgesture.cancelsTouchesInView=NO;
    [self addGestureRecognizer:lpgesture];
    [lpgesture release];
    lpgesture=[[UILongPressGestureRecognizer alloc]
     initWithTarget:self action:@selector(toggleKeyboard:)];
    lpgesture.numberOfTouchesRequired=2;
    lpgesture.delegate=self;
    lpgesture.cancelsTouchesInView=NO;
    [self addGestureRecognizer:lpgesture];
    [lpgesture release];
  }
  return self;
}
-(void)toggleControlKey:(UILongPressGestureRecognizer*)gesture {
  if(gesture.state==UIGestureRecognizerStateBegan){controlKey=YES;}
  else if(gesture.state==UIGestureRecognizerStateEnded){controlKey=NO;}
}
-(void)toggleKeyboard:(UILongPressGestureRecognizer*)gesture {
  if(gesture.state==UIGestureRecognizerStateBegan){
    if(self.isFirstResponder){[self resignFirstResponder];}
    else {[self becomeFirstResponder];}
  }
}
-(BOOL)gestureRecognizer:(UIGestureRecognizer*)gesture1 shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer*)gesture2 {
  return YES;
}
-(BOOL)hasText {
  return YES;// Make sure that the backspace key always works
}
-(void)deleteBackward {
  [receiver putData:kBackspace];
}
-(void)insertText:(NSString*)input {
  if(controlKey && input.length==1){
    unichar c=[input characterAtIndex:0];
    if(c<0x60 && c>0x40){c-=0x40;}
    else if(c<0x7b && c>0x60){c-=0x60;}
    else {goto __sendkey;}
    input=[NSString stringWithCharacters:&c length:1];
  }
  else if([input isEqualToString:@"\n"]){input=@"\r";}
  __sendkey:
  [receiver putData:[input dataUsingEncoding:NSUTF8StringEncoding]];
}
-(BOOL)canBecomeFirstResponder {
  return YES;
}
-(void)dealloc {
  [kBackspace release];
  [selectedTextRange release];
  [markedTextStyle release];
  [super dealloc];
}
@end

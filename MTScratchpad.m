#include "MTScratchpad.h"

@implementation MTScratchpad
-(id)initWithText:(NSString*)_text fontSize:(CGFloat)_fontSize darkBG:(BOOL)_darkBG {
  if((self=[super init])){
    text=[_text retain];
    fontSize=_fontSize;
    darkBG=_darkBG;
    UINavigationItem* navitem=self.navigationItem;
    [navitem.leftBarButtonItem=[[UIBarButtonItem alloc]
     initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
     target:self action:@selector(dismiss)] release];
    navitem.rightBarButtonItem=self.editButtonItem;
  }
  return self;
}
-(void)dismiss {
  [self dismissModalViewControllerAnimated:YES];
}
-(void)setEditing:(BOOL)editing animated:(BOOL)animated {
  [super setEditing:editing animated:animated];
  UITextView* view=(UITextView*)self.view;
  view.editable=editing;
  [view becomeFirstResponder];
}
-(void)loadView {
  UITextView* view=[[UITextView alloc] init];
  view.editable=NO;
  view.autocapitalizationType=UITextAutocapitalizationTypeNone;
  view.autocorrectionType=UITextAutocorrectionTypeNo;
  view.keyboardAppearance=darkBG?
   UIKeyboardAppearanceDark:UIKeyboardAppearanceDefault;
  view.backgroundColor=darkBG?[UIColor blackColor]:[UIColor whiteColor];
  view.textColor=darkBG?[UIColor lightTextColor]:[UIColor darkTextColor];
  view.indicatorStyle=darkBG?
   UIScrollViewIndicatorStyleWhite:UIScrollViewIndicatorStyleBlack;
  view.font=[UIFont fontWithName:@"Courier" size:fontSize];
  view.text=text;
  [self.view=view release];
}
-(void)dealloc {
  [text release];
  [super dealloc];
}
@end

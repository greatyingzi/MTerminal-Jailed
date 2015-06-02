#include "MTScratchpad.h"

@implementation MTScratchpad
-(id)initWithTitle:(NSString*)title content:(NSString*)_content font:(UIFont*)_font bgColor:(UIColor*)_bgColor fgColor:(UIColor*)_fgColor {
  if((self=[super init])){
    content=[_content retain];
    font=[_font retain];
    bgColor=[_bgColor retain];
    fgColor=[_fgColor retain];
    UINavigationItem* navitem=self.navigationItem;
    navitem.title=title;
    [navitem.leftBarButtonItem=[[UIBarButtonItem alloc]
     initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
     target:self action:@selector(dismiss)] release];
    navitem.rightBarButtonItem=self.editButtonItem;
  }
  return self;
}
-(void)dismiss {
  [self dismissViewControllerAnimated:YES completion:NULL];
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
  view.keyboardAppearance=UIKeyboardAppearanceDark;
  [view.text=content release];content=nil;
  [view.font=font release];font=nil;
  [view.backgroundColor=bgColor release];bgColor=nil;
  [view.textColor=fgColor release];fgColor=nil;
  [self.view=view release];
}
-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation {
  return orientation==UIInterfaceOrientationPortrait
   || orientation==UIInterfaceOrientationLandscapeLeft
   || orientation==UIInterfaceOrientationLandscapeRight;
}
-(void)dealloc {
  [content release];
  [font release];
  [bgColor release];
  [fgColor release];
  [super dealloc];
}
@end

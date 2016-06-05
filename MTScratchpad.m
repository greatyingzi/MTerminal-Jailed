#include "MTScratchpad.h"

@implementation MTScratchpad
-(id)initWithTitle:(NSString*)title content:(NSString*)_content font:(UIFont*)_font textColor:(UIColor*)_textColor refDelegate:(id<MTController>)_refDelegate {
  if((self=[super init])){
    content=[_content retain];
    font=[_font retain];
    textColor=[_textColor retain];
    refDelegate=_refDelegate;
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
  view.autocapitalizationType=refDelegate.autocapitalizationType;
  view.autocorrectionType=refDelegate.autocorrectionType;
  view.keyboardAppearance=refDelegate.keyboardAppearance;
  UIScrollView* refview=refDelegate.view;
  view.indicatorStyle=refview.indicatorStyle;
  view.backgroundColor=refview.backgroundColor;
  view.text=content;
  view.font=font;
  view.textColor=textColor;
  [self.view=view release];
}
-(void)dealloc {
  [content release];
  [font release];
  [textColor release];
  [super dealloc];
}
@end

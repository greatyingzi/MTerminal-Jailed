#import "MTKBAvoiding.h"

@protocol MTController <UIKeyInput>
-(UIScrollView*)view;
@end

@interface MTScratchpad : MTKBAvoiding {
  NSString* content;
  UIFont* font;
  UIColor* textColor;
  id<MTController> refDelegate;
}
-(id)initWithTitle:(NSString*)title content:(NSString*)_content font:(UIFont*)_font textColor:(UIColor*)_textColor refDelegate:(id<MTController>)_refDelegate;
@end

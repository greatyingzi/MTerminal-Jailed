#import "MTKBAvoiding.h"

@interface MTScratchpad : MTKBAvoiding {
  NSString* content;
  UIFont* font;
  UIColor* bgColor;
  UIColor* fgColor;
}
-(id)initWithTitle:(NSString*)title content:(NSString*)_content font:(UIFont*)_font bgColor:(UIColor*)_bgColor fgColor:(UIColor*)_fgColor;
@end

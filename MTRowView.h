#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

#define kMTBackgroundColorAttributeName CFSTR("MTBackgroundColor")
#define kMTStrikethroughColorAttributeName CFSTR("MTStrikethroughColor")

@interface MTRowView : UIView {
  CGColorRef bgColor;
  CTLineRef ctLine;
  CGFloat lineAscent;
  CFMutableDictionaryRef bgMap,stMap;
}
-(void)renderString:(CFAttributedStringRef)string withBGColor:(CGColorRef)_bgColor;
@end

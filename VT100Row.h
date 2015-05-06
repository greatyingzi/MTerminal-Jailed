#import <CoreText/CoreText.h>
#import "VT100Screen.h"

@protocol VT100RowDelegate <NSObject>
@property(nonatomic,readonly) CGColorRef bgColor,bgCursorColor,fgCursorColor;
@property(nonatomic,readonly) CTFontRef font;
@property(nonatomic,readonly) CGFloat glyphAscent,glyphHeight;
-(CGColorRef)colorAtIndex:(unsigned int)index;
@end

@interface VT100Row : UIView {
  id<VT100RowDelegate> delegate;
  CFMutableDictionaryRef bgMap;
  CTLineRef textLine;
  CGFloat* offsets;
}
-(id)initWithDelegate:(id<VT100RowDelegate>)_delegate;
-(void)setBuffer:(screen_char_t*)buffer length:(int)length cursorX:(int)cursorX;
@end

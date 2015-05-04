#import <CoreText/CoreText.h>

@class VT100Screen;

@protocol VT100RowDelegate <NSObject>
@property(nonatomic,readonly) CGColorRef bgColor,bgCursorColor,fgCursorColor;
@property(nonatomic,readonly) CTFontRef font;
@property(nonatomic,readonly) CGFloat glyphDescent;
@property(nonatomic,readonly) CGSize glyphSize;
@property(nonatomic,readonly) VT100Screen* screen;
-(CGColorRef)colorAtIndex:(unsigned int)index;
@end

@interface VT100Row : UIView {
  id<VT100RowDelegate> delegate;
  int rowIndex;
}
-(id)initWithDelegate:(id<VT100RowDelegate>)_delegate;
-(void)setRowIndex:(int)_rowIndex;
@end

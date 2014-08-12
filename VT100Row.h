@class VT100Screen;

@interface VT100Row : UIView
@property(nonatomic,assign) int rowIndex;
@property(nonatomic,assign) VT100Screen* screen;
@end

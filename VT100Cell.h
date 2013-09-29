@class VT100Screen;

@interface VT100Cell : UITableViewCell
@property(nonatomic,assign) int rowIndex;
@property(nonatomic,assign) VT100Screen* screen;
@end

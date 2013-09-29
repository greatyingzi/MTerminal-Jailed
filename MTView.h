@class VT100;

@interface MTView : UIView <UITextInput, UIGestureRecognizerDelegate> {
  NSData* kBackspace;
  BOOL controlKey;
}
@property(nonatomic,assign) VT100* receiver;
@end

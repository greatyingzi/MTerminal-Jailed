@class VT100;

@interface MTController : UIViewController {
  VT100* vt100;
  NSData* kUp;
  NSData* kDown;
  NSData* kLeft;
  NSData* kRight;
  NSData* kPageUp;
  NSData* kPageDown;
  NSData* kHome;
  NSData* kEnd;
  NSData* kEsc;
  NSData* kTab;
  NSData* kInsert;
  NSData* kDelete;
  NSData* repeating;
}
@end

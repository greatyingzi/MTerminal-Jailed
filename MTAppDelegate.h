@class MTController;

@interface MTAppDelegate : NSObject <UIApplicationDelegate> {
  MTController* controller;
}
@property(nonatomic,retain) UIWindow *window;
@end

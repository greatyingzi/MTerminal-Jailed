#import "MTAppDelegate.h"
#import "MTController.h"

@interface UIApplication (Private)
-(void)terminateWithSuccess;
@end

@implementation MTAppDelegate
@synthesize window;
-(void)applicationDidFinishLaunching:(UIApplication*)application {
  window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  window.rootViewController=controller=[[MTController alloc] init];
  [window makeKeyAndVisible];
}
-(void)applicationDidEnterBackground:(UIApplication*)application {
  if(!controller.isRunning){[application terminateWithSuccess];}
}
-(void)dealloc {
  [window release];
  [controller release];
  [super dealloc];
}
@end

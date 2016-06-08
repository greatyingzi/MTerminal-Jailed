#import "MTAppDelegate.h"
#import "MTController.h"

@implementation MTAppDelegate
-(void)applicationDidFinishLaunching:(UIApplication*)application {
  window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  window.rootViewController=controller=[[MTController alloc] init];
  [window makeKeyAndVisible];
}
-(BOOL)application:(UIApplication*)application handleOpenURL:(NSURL*)URL {
  return [controller handleOpenURL:URL];
}
-(void)applicationDidEnterBackground:(UIApplication*)application {
  if(!controller.isRunning){exit(0);}
}
-(UIWindow*)window {
  return window;
}
-(void)dealloc {
  [window release];
  [controller release];
  [super dealloc];
}
@end

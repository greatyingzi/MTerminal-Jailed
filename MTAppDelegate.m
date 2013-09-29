#import "MTAppDelegate.h"
#import "MTController.h"

@implementation MTAppDelegate
@synthesize window;
-(void)applicationDidFinishLaunching:(UIApplication*)application {
  window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  [window.rootViewController=[[MTController alloc] init] release];
  [window makeKeyAndVisible];
}
-(void)dealloc {
  [window release];
  [super dealloc];
}
@end

#import "MTAppDelegate.h"
#import "MTController.h"
#import "async_wake/async_wake.h"
#import "the_fun_part/fun.h"

@implementation MTAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    mach_port_t user_client;
    mach_port_t tfp0 = get_tfp0(&user_client);
    
    let_the_fun_begin(tfp0, user_client);
    
    window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    window.rootViewController=controller=[[MTController alloc] init];
    [window makeKeyAndVisible];
    
    return YES;
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

#import "MTAppDelegate.h"
#import "MTController.h"

@interface UIApplication (Private)
-(void)terminateWithSuccess;
@end

@implementation MTAppDelegate
@synthesize window;
-(void)alertView:(UIAlertView*)alert clickedButtonAtIndex:(NSInteger)index {
  if(index!=alert.cancelButtonIndex){
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"firstRun"];
  }
}
-(void)applicationDidFinishLaunching:(UIApplication*)application {
  window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  window.rootViewController=controller=[[MTController alloc] init];
  [window makeKeyAndVisible];
  if(![[NSUserDefaults standardUserDefaults] boolForKey:@"firstRun"]){
    UIAlertView* alert=[[UIAlertView alloc] initWithTitle:@"Help" message:
     @"- To send an arrow key, tap on the corresponding edge of the screen."
     " Tap and hold to repeat an arrow key.\n"
     "- To send a control key, invoke the edit menu and tap the corresponding"
     " letter (e.g. C for Control-C) on the keyboard.\n"
     "- To send Page Up, Page Down, Home, or End, activate the Shift key on"
     " the keyboard and tap on the top, bottom, left, or right edge of the"
     " screen, respectively.\n"
     "- To send Insert, Delete, Esc, or Tab, tap on the upper left,"
     " upper right, lower left, or lower right corner, respectively.\n"
     "- To copy and paste text, invoke the edit menu by tapping and holding"
     " the center of the screen.\n"
     "- To dismiss the keyboard, tap and hold with two fingers.\n"
     "- To open a new window or switch between windows, tap and hold"
     " the lower right corner of the screen.\n"
     "- To close the current window, tap and hold"
     " the upper right corner of the screen." delegate:self
     cancelButtonTitle:@"Later" otherButtonTitles:@"Dismiss",nil];
    [alert show];
    [alert release];
  }
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

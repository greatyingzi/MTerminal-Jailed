#import "MTAppDelegate.h"
#import "MTController.h"

@implementation MTAppDelegate
@synthesize window;
-(void)alertView:(UIAlertView*)alert clickedButtonAtIndex:(NSInteger)index {
  if(index!=alert.cancelButtonIndex){
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"firstRun"];
  }
}
-(void)applicationDidFinishLaunching:(UIApplication*)application {
  window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  [window.rootViewController=[[MTController alloc] init] release];
  [window makeKeyAndVisible];
  if(![[NSUserDefaults standardUserDefaults] boolForKey:@"firstRun"]){
    UIAlertView* alert=[[UIAlertView alloc] initWithTitle:@"Welcome"
     message:@"Welcome to MTerminal. Before using this app, you should be"
     " aware of a powerful but easily overlooked feature: tap zones."
     " Tap zones allow you to easily access keys and options not available"
     " from the default keyboard, such as the arrow keys and control keys.\n\n"
     "- To paste text from the system pasteboard, double tap on the terminal"
     " with two fingers.\n"
     "- To dismiss the keyboard, tap and hold with two fingers.\n"
     "- To send an arrow key, tap on the corresponding edge of the terminal."
     " For example, tap the top edge to send the Up arrow key, and tap the"
     " right edge to send the Right arrow key. Tap and hold to repeatedly send"
     " the corresponding arrow key.\n"
     "- To send a control key, tap and hold anywhere on the terminal and"
     " simultaneously tap the corresponding letter (e.g. C for Control-C)"
     " on the keyboard.\n"
     "- To send Page Up, Page Down, Home, or End, press the Shift key on"
     " the keyboard and tap on the top, bottom, left, or right edge of the"
     " terminal, respectively. Shift lock is also supported.\n"
     "- To send Insert, Delete, Esc, or Tab, tap on the upper left,"
     " upper right, lower left, or lower right corner, respectively."
     delegate:self cancelButtonTitle:@"Later" otherButtonTitles:@"Dismiss",nil];
    [alert show];
    [alert release];
  }
}
-(void)dealloc {
  [window release];
  [super dealloc];
}
@end

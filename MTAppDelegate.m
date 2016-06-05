#import "MTAppDelegate.h"
#import "MTController.h"

@implementation MTAppDelegate
-(BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
  NSUserDefaults* defaults=[NSUserDefaults standardUserDefaults];
  NSString* name=[NSBundle mainBundle].bundleIdentifier;
  NSDictionary* settings;
  NSURL* URL=[options objectForKey:UIApplicationLaunchOptionsURLKey];
  if(URL){
    NSString* keys[]={
     kPrefPalette,kPrefFontSize,kPrefFontProportional,
     kPrefBGDefaultColor,kPrefFGDefaultColor,kPrefFGBoldColor,
     kPrefBGCursorColor,kPrefFGCursorColor,kPrefFontName,kPrefFontWidthSample};
    const int nkeys=sizeof(keys)/sizeof(NSString*);
    NSMutableDictionary* msettings=[NSMutableDictionary
     dictionaryWithCapacity:nkeys];
    for (NSString* keyvalue in [URL.resourceSpecifier
     componentsSeparatedByString:@"&"]){
      NSUInteger pos=[keyvalue rangeOfString:@"="].location;
      if(pos==NSNotFound || pos==0 || pos==keyvalue.length-1){continue;}
      NSString* key=[keyvalue substringToIndex:pos];
      int i;
      for (i=0;i<nkeys;i++){
        if([key isEqualToString:keys[i]]){
          NSString* vstr=[[keyvalue substringFromIndex:pos+1]
           stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
          id value;
          if(i==0){value=[vstr componentsSeparatedByString:@","];}
          else if(i==1){
            double v=vstr.doubleValue;if(!v){break;}
            value=[NSNumber numberWithDouble:v];
          }
          else if(i==2){
            if(!vstr.intValue){break;}
            value=(id)kCFBooleanTrue;
          }
          else {value=vstr;}
          [msettings setObject:value forKey:key];
          break;
        }
      }
    }
    settings=msettings;
    if(settings.count){[defaults setPersistentDomain:settings forName:name];}
    else {[defaults removePersistentDomainForName:name];}
  }
  else {settings=[defaults persistentDomainForName:name];}
  controller=[[MTController alloc] initWithSettings:settings];
  [NSUserDefaults resetStandardUserDefaults];
  window=[[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  window.rootViewController=controller;
  [window makeKeyAndVisible];
  return YES;
}
-(void)applicationDidEnterBackground:(UIApplication*)application {
  if(!controller.isRunning){exit(0);}
}
-(void)dealloc {
  [window release];
  [controller release];
  [super dealloc];
}
@end

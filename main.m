int main(int argc,char** argv) {
  NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
  int retval=UIApplicationMain(argc,argv,nil,@"MTAppDelegate");
  [pool drain];
  return retval;
}

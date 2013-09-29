#import "MTPreferences.h"
#import "VT100Terminal.h"

@implementation MTPreferences
@synthesize fgCursorColor;
@synthesize bgCursorColor;
@synthesize backgroundColor;
@synthesize ctFont;
@synthesize glyphSize;
@synthesize glyphDescent;

-(id)init {
  if((self=[super init])){
    // 256 colors
    const uint64_t colors[]={
     0x000000FF,0xcd0000FF,0x00cd00FF,0xcdcd00FF,0x0000eeFF,0xcd00cdFF,0x00cdcdFF,0xe5e5e5FF,
     0x7f7f7fFF,0xff0000FF,0x00ff00FF,0xffff00FF,0x5c5cffFF,0xff00ffFF,0x00ffffFF,0xffffffFF,
     0x000000FF,0x00005fFF,0x000087FF,0x0000afFF,0x0000d7FF,0x0000ffFF,
     0x005f00FF,0x005f5fFF,0x005f87FF,0x005fafFF,0x005fd7FF,0x005fffFF,
     0x008700FF,0x00875fFF,0x008787FF,0x0087afFF,0x0087d7FF,0x0087ffFF,
     0x00af00FF,0x00af5fFF,0x00af87FF,0x00afafFF,0x00afd7FF,0x00afffFF,
     0x00d700FF,0x00d75fFF,0x00d787FF,0x00d7afFF,0x00d7d7FF,0x00d7ffFF,
     0x00ff00FF,0x00ff5fFF,0x00ff87FF,0x00ffafFF,0x00ffd7FF,0x00ffffFF,
     0x5f0000FF,0x5f005fFF,0x5f0087FF,0x5f00afFF,0x5f00d7FF,0x5f00ffFF,
     0x5f5f00FF,0x5f5f5fFF,0x5f5f87FF,0x5f5fafFF,0x5f5fd7FF,0x5f5fffFF,
     0x5f8700FF,0x5f875fFF,0x5f8787FF,0x5f87afFF,0x5f87d7FF,0x5f87ffFF,
     0x5faf00FF,0x5faf5fFF,0x5faf87FF,0x5fafafFF,0x5fafd7FF,0x5fafffFF,
     0x5fd700FF,0x5fd75fFF,0x5fd787FF,0x5fd7afFF,0x5fd7d7FF,0x5fd7ffFF,
     0x5fff00FF,0x5fff5fFF,0x5fff87FF,0x5fffafFF,0x5fffd7FF,0x5fffffFF,
     0x870000FF,0x87005fFF,0x870087FF,0x8700afFF,0x8700d7FF,0x8700ffFF,
     0x875f00FF,0x875f5fFF,0x875f87FF,0x875fafFF,0x875fd7FF,0x875fffFF,
     0x878700FF,0x87875fFF,0x878787FF,0x8787afFF,0x8787d7FF,0x8787ffFF,
     0x87af00FF,0x87af5fFF,0x87af87FF,0x87afafFF,0x87afd7FF,0x87afffFF,
     0x87d700FF,0x87d75fFF,0x87d787FF,0x87d7afFF,0x87d7d7FF,0x87d7ffFF,
     0x87ff00FF,0x87ff5fFF,0x87ff87FF,0x87ffafFF,0x87ffd7FF,0x87ffffFF,
     0xaf0000FF,0xaf005fFF,0xaf0087FF,0xaf00afFF,0xaf00d7FF,0xaf00ffFF,
     0xaf5f00FF,0xaf5f5fFF,0xaf5f87FF,0xaf5fafFF,0xaf5fd7FF,0xaf5fffFF,
     0xaf8700FF,0xaf875fFF,0xaf8787FF,0xaf87afFF,0xaf87d7FF,0xaf87ffFF,
     0xafaf00FF,0xafaf5fFF,0xafaf87FF,0xafafafFF,0xafafd7FF,0xafafffFF,
     0xafd700FF,0xafd75fFF,0xafd787FF,0xafd7afFF,0xafd7d7FF,0xafd7ffFF,
     0xafff00FF,0xafff5fFF,0xafff87FF,0xafffafFF,0xafffd7FF,0xafffffFF,
     0xd70000FF,0xd7005fFF,0xd70087FF,0xd700afFF,0xd700d7FF,0xd700ffFF,
     0xd75f00FF,0xd75f5fFF,0xd75f87FF,0xd75fafFF,0xd75fd7FF,0xd75fffFF,
     0xd78700FF,0xd7875fFF,0xd78787FF,0xd787afFF,0xd787d7FF,0xd787ffFF,
     0xd7af00FF,0xd7af5fFF,0xd7af87FF,0xd7afafFF,0xd7afd7FF,0xd7afffFF,
     0xd7d700FF,0xd7d75fFF,0xd7d787FF,0xd7d7afFF,0xd7d7d7FF,0xd7d7ffFF,
     0xd7ff00FF,0xd7ff5fFF,0xd7ff87FF,0xd7ffafFF,0xd7ffd7FF,0xd7ffffFF,
     0xff0000FF,0xff005fFF,0xff0087FF,0xff00afFF,0xff00d7FF,0xff00ffFF,
     0xff5f00FF,0xff5f5fFF,0xff5f87FF,0xff5fafFF,0xff5fd7FF,0xff5fffFF,
     0xff8700FF,0xff875fFF,0xff8787FF,0xff87afFF,0xff87d7FF,0xff87ffFF,
     0xffaf00FF,0xffaf5fFF,0xffaf87FF,0xffafafFF,0xffafd7FF,0xffafffFF,
     0xffd700FF,0xffd75fFF,0xffd787FF,0xffd7afFF,0xffd7d7FF,0xffd7ffFF,
     0xffff00FF,0xffff5fFF,0xffff87FF,0xffffafFF,0xffffd7FF,0xffffffFF,
     0x080808FF,0x121212FF,0x1c1c1cFF,0x262626FF,0x303030FF,0x3a3a3aFF,0x444444FF,0x4e4e4eFF,
     0x585858FF,0x626262FF,0x6c6c6cFF,0x767676FF,0x808080FF,0x8a8a8aFF,0x949494FF,0x9e9e9eFF,
     0xa8a8a8FF,0xb2b2b2FF,0xbcbcbcFF,0xc6c6c6FF,0xd0d0d0FF,0xdadadaFF,0xe4e4e4FF,0xeeeeeeFF,
    };
    CGColorSpaceRef rgbspace=CGColorSpaceCreateDeviceRGB();
    unsigned int i;
    for (i=0;i<256;i++){
      struct {uint8_t a,b,g,r;}* cv=(void*)(colors+i);
      colorTable[i]=CGColorCreate(rgbspace,(CGFloat[]){
       cv->r/255.0,cv->g/255.0,cv->b/255.0,cv->a/255.0});
    }
    fgColor=CGColorCreate(rgbspace,(CGFloat[]){0.85,0.85,0.85,1});
    fgBoldColor=CGColorCreate(rgbspace,(CGFloat[]){1,1,1,1});
    fgCursorColor=CGColorCreate(rgbspace,(CGFloat[]){0.9,0.9,0.9,1});
    bgCursorColor=CGColorCreate(rgbspace,(CGFloat[]){0.4,0.4,0.4,1});
    CFRelease(rgbspace);
    backgroundColor=[[UIColor blackColor] retain];
    // font metrics
    ctFont=CTFontCreateWithName(CFSTR("Courier"),
     (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad)?18:10,NULL);
    NSAssert(ctFont!=nil,@"Error in CTFontCreateWithName");
    CFMutableAttributedStringRef string=CFAttributedStringCreateMutable(NULL,0);
    CFAttributedStringReplaceString(string,CFRangeMake(0,0),CFSTR("A"));
    CFAttributedStringSetAttribute(string,CFRangeMake(0,1),kCTFontAttributeName,ctFont);
    CTLineRef line=CTLineCreateWithAttributedString(string);
    CFRelease(string);
    float ascent,height,width=CTLineGetTypographicBounds(line,&ascent,&glyphDescent,&height);
    glyphSize=CGSizeMake(width,ascent+glyphDescent+height);
    CFRelease(line);
  }
  return self;
}
+(MTPreferences*)sharedInstance {
  static id $_sharedInstance=nil;
  return $_sharedInstance?:($_sharedInstance=[[MTPreferences alloc] init]);
}
-(CGColorRef)color:(unsigned int)index {
  return (index&COLOR_CODE_MASK)?
   (index==CURSOR_TEXT)?fgCursorColor:(index==CURSOR_BG)?bgCursorColor:
   (index==BG_COLOR_CODE || index==BG_COLOR_CODE+BOLD_MASK)?backgroundColor.CGColor:
   (index&BOLD_MASK)?fgBoldColor:fgColor:colorTable[index&255];
}
-(void)dealloc {
  unsigned int i;
  for (i=0;i<256;i++){CFRelease(colorTable[i]);}
  CFRelease(fgColor);
  CFRelease(fgBoldColor);
  CFRelease(fgCursorColor);
  CFRelease(bgCursorColor);
  [backgroundColor release];
  CFRelease(ctFont);
  [super dealloc];
}
@end

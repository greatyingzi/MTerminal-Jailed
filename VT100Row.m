#import "VT100Row.h"
#import "MTPreferences.h"
#import "VT100Screen.h"

@implementation VT100Row
@synthesize rowIndex;
@synthesize screen;

-(void)drawRect:(CGRect)rect {
  CGContextRef context=UIGraphicsGetCurrentContext();
  CGContextClearRect(context,rect);
  MTPreferences* prefs=[MTPreferences sharedInstance];
  CGSize glyphSize=prefs.glyphSize;
  screen_char_t* linebuf=[screen getLineAtIndex:rowIndex];
  int width=screen.width,i;
  unichar* ucbuf=malloc(width*sizeof(unichar));
  for (i=0;i<width;i++){ucbuf[i]=linebuf[i].ch?:' ';}
  CFMutableAttributedStringRef attrString=CFAttributedStringCreateMutable(NULL,0);
  CFStringRef string=CFStringCreateWithCharactersNoCopy(NULL,ucbuf,width,NULL);
  CFAttributedStringReplaceString(attrString,CFRangeMake(0,0),string);
  CFRelease(string);
  CFAttributedStringSetAttribute(attrString,
   CFRangeMake(0,width),kCTFontAttributeName,prefs.ctFont);
  // The cursor is initially relative to the screen, not the position in the
  // scrollback buffer.
  int cursorX=screen.cursorX,cursorY=screen.cursorY;
  if(screen.numberOfLines>screen.height){
    cursorY+=screen.numberOfLines-screen.height;
  }
  // Update the string with background/foreground color attributes.  This loop
  // compares the the colors of characters and sets the attribute when it runs
  // into a character of a different color.  It runs one extra time to set the
  // attribute for the run of characters at the end of the line.
  unsigned int spanbg=0,spanfg=0;
  CGColorRef currentbg=NULL,currentfg=NULL;
  for (i=0;i<=width;i++){
    BOOL cursor=(i==cursorX && rowIndex==cursorY);
    BOOL valid=(i<width && linebuf[i].ch);
    CGColorRef color=cursor?prefs.bgCursorColor:
     valid?[prefs color:linebuf[i].bg_color]:NULL;
    if(CGColorEqualToColor(currentbg,color)){spanbg++;}
    else {
      if(currentbg){
        CGContextSetFillColorWithColor(context,currentbg);
        CGContextFillRect(context,CGRectMake(glyphSize.width*(i-spanbg),0,
         glyphSize.width*spanbg,glyphSize.height));
      }
      currentbg=color;
      spanbg=1;
    }
    color=cursor?prefs.fgCursorColor:
     valid?[prefs color:linebuf[i].fg_color]:NULL;
    if(CGColorEqualToColor(currentfg,color)){spanfg++;}
    else {
      if(currentfg){
        CFAttributedStringSetAttribute(attrString,CFRangeMake(i-spanfg,spanfg),
         kCTForegroundColorAttributeName,currentfg);
      }
      currentfg=color;
      spanfg=1;
    }
  }
  // By default, text is drawn upside down.  Apply a transformation to turn
  // orient the text correctly.
  CGContextSetTextMatrix(context,CGAffineTransformMake(1,0,0,-1,0,0));
  CGContextSetTextPosition(context,0,glyphSize.height-prefs.glyphDescent);
  CTLineRef line=CTLineCreateWithAttributedString(attrString);
  CFRelease(attrString);
  CTLineDraw(line,context);
  CFRelease(line);
}
@end

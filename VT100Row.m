#import "VT100Row.h"
#import "VT100Screen.h"

@implementation VT100Row
-(id)initWithDelegate:(id<VT100RowDelegate>)_delegate {
  if((self=[super init])){delegate=_delegate;}
  return self;
}
-(void)setRowIndex:(int)_rowIndex {
  rowIndex=_rowIndex;
  [self setNeedsDisplay];
}
-(void)drawRect:(CGRect)rect {
  CGContextRef context=UIGraphicsGetCurrentContext();
  CGContextClearRect(context,rect);
  CGSize glyphSize=delegate.glyphSize;
  VT100Screen* screen=delegate.screen;
  screen_char_t* linebuf=[screen getLineAtIndex:rowIndex];
  int width=screen.width,i;
  unichar* ucbuf=malloc(width*sizeof(unichar));
  for (i=0;i<width;i++){ucbuf[i]=linebuf[i].ch?:' ';}
  CFMutableAttributedStringRef attrString=CFAttributedStringCreateMutable(NULL,0);
  CFStringRef string=CFStringCreateWithCharactersNoCopy(NULL,ucbuf,width,NULL);
  CFAttributedStringReplaceString(attrString,CFRangeMake(0,0),string);
  CFRelease(string);
  CFAttributedStringSetAttribute(attrString,
   CFRangeMake(0,width),kCTFontAttributeName,delegate.font);
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
  CGContextSetFillColorWithColor(context,delegate.bgColor);
  CGContextFillRect(context,rect);
  unsigned int spanbg=0,spanfg=0;
  CGColorRef currentbg=NULL,currentfg=NULL;
  for (i=0;i<=width;i++){
    BOOL cursor=(i==cursorX && rowIndex==cursorY);
    BOOL valid=(i<width && linebuf[i].ch);
    CGColorRef bgcolor=cursor?delegate.bgCursorColor:
     valid?[delegate colorAtIndex:linebuf[i].bg_color]:NULL;
    if(CGColorEqualToColor(currentbg,bgcolor)){spanbg++;}
    else {
      if(currentbg){
        CGContextSetFillColorWithColor(context,currentbg);
        CGContextFillRect(context,CGRectMake(glyphSize.width*(i-spanbg),0,
         glyphSize.width*spanbg,glyphSize.height));
      }
      currentbg=bgcolor;
      spanbg=1;
    }
    CGColorRef fgcolor=cursor?delegate.fgCursorColor:
     valid?[delegate colorAtIndex:linebuf[i].fg_color]:NULL;
    if(CGColorEqualToColor(currentfg,fgcolor)){spanfg++;}
    else {
      if(currentfg){
        CFAttributedStringSetAttribute(attrString,CFRangeMake(i-spanfg,spanfg),
         kCTForegroundColorAttributeName,currentfg);
      }
      currentfg=fgcolor;
      spanfg=1;
    }
  }
  // By default, text is drawn upside down.  Apply a transformation to turn
  // orient the text correctly.
  CGContextSetTextMatrix(context,CGAffineTransformMake(1,0,0,-1,0,0));
  CGContextSetTextPosition(context,0,glyphSize.height-delegate.glyphDescent);
  CTLineRef line=CTLineCreateWithAttributedString(attrString);
  CFRelease(attrString);
  CTLineDraw(line,context);
  CFRelease(line);
}
@end

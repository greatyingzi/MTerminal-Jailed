#import "VT100Row.h"

@implementation VT100Row
-(id)initWithDelegate:(id<VT100RowDelegate>)_delegate {
  if((self=[super init])){
    delegate=_delegate;
    bgMap=CFDictionaryCreateMutable(NULL,0,
     NULL,&kCFTypeDictionaryValueCallBacks);
  }
  return self;
}
-(void)setBuffer:(screen_char_t*)buffer length:(int)length cursorX:(int)cursorX {
  if(textLine){
    CFRelease(textLine);
    free(offsets);
  }
  int i;
  unichar* ucbuf=malloc(length*sizeof(unichar));
  for (i=0;i<length;i++){ucbuf[i]=buffer[i].ch?:' ';}
  CFMutableAttributedStringRef attrString=CFAttributedStringCreateMutable(NULL,length);
  CFAttributedStringBeginEditing(attrString);
  CFStringRef string=CFStringCreateWithCharactersNoCopy(NULL,ucbuf,length,NULL);
  CFAttributedStringReplaceString(attrString,CFRangeMake(0,0),string);
  CFRelease(string);
  CFAttributedStringSetAttribute(attrString,
  CFRangeMake(0,length),kCTFontAttributeName,delegate.font);
  // set foreground colors
  NSUInteger fgspan=0;
  CGColorRef fgcolor=NULL;
  for (i=0;i<=length;i++){
    CGColorRef fg0=(i==cursorX)?delegate.fgCursorColor:
     (i<length && buffer[i].ch)?[delegate colorAtIndex:buffer[i].fg_color]:NULL;
    if(fgcolor==fg0){fgspan++;}
    else {
      if(fgcolor){
        CFAttributedStringSetAttribute(attrString,CFRangeMake(i-fgspan,fgspan),
         kCTForegroundColorAttributeName,fgcolor);
      }
      fgspan=1;
      fgcolor=fg0;
    }
  }
  CFAttributedStringEndEditing(attrString);
  textLine=CTLineCreateWithAttributedString(attrString);
  CFRelease(attrString);
  // get background offsets
  CFDictionaryRemoveAllValues(bgMap);
  CGFloat* ptr=offsets=malloc((length+1)*sizeof(CGFloat));
  CGColorRef bgcolor=NULL;
  for (i=0;i<=length;i++){
    CGColorRef bg0=(i==cursorX)?delegate.bgCursorColor:
     (i<length && buffer[i].ch)?[delegate colorAtIndex:buffer[i].bg_color]:NULL;
    if(bgcolor==bg0){continue;}
    if(bgcolor){
      CFMutableArrayRef ptrs=(void*)CFDictionaryGetValue(bgMap,bgcolor);
      if(!ptrs){
        ptrs=CFArrayCreateMutable(NULL,length,NULL);
        CFDictionarySetValue(bgMap,bgcolor,ptrs);
        CFRelease(ptrs);
      }
      CFArrayAppendValue(ptrs,ptr-1);
    }
    *(ptr++)=CTLineGetOffsetForStringIndex(textLine,i,NULL);
    bgcolor=bg0;
  }
  [self setNeedsDisplay];
}
-(void)drawRect:(CGRect)rect {
  if(!textLine){return;}
  CGContextRef context=UIGraphicsGetCurrentContext();
  // draw background
  CGContextSetFillColorWithColor(context,delegate.bgColor);
  CGContextFillRect(context,rect);
  CFIndex nbg=CFDictionaryGetCount(bgMap),i;
  CGColorRef* allcolors=malloc(nbg*sizeof(CGColorRef));
  CFArrayRef* allptrs=malloc(nbg*sizeof(CFArrayRef));
  CFDictionaryGetKeysAndValues(bgMap,(const void**)allcolors,(const void**)allptrs);
  CGFloat height=delegate.glyphHeight;
  for (i=0;i<nbg;i++){
    CGContextSetFillColorWithColor(context,allcolors[i]);
    unsigned int nptrs=CFArrayGetCount(allptrs[i]),j;
    for (j=0;j<nptrs;j++){
      CGFloat* offset=(void*)CFArrayGetValueAtIndex(allptrs[i],j);
      CGContextFillRect(context,CGRectMake(offset[0],0,offset[1]-offset[0],height));
    }
  }
  free(allcolors);
  free(allptrs);
  // draw correctly oriented text
  CGContextSetTextMatrix(context,CGAffineTransformMake(1,0,0,-1,0,0));
  CGContextSetTextPosition(context,0,delegate.glyphAscent);
  CTLineDraw(textLine,context);
}
-(void)dealloc {
  CFRelease(bgMap);
  if(textLine){
    CFRelease(textLine);
    free(offsets);
  }
  [super dealloc];
}
@end

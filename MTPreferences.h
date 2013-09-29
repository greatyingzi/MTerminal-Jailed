#import <CoreText/CoreText.h>

@interface MTPreferences : NSObject {
  CGColorRef colorTable[256],fgColor,fgBoldColor;
}
@property(readonly) CGColorRef fgCursorColor;
@property(readonly) CGColorRef bgCursorColor;
@property(readonly) UIColor* backgroundColor;
@property(readonly) CTFontRef ctFont;
@property(readonly) CGSize glyphSize;
@property(readonly) float glyphDescent;

+(MTPreferences*)sharedInstance;
-(CGColorRef)color:(unsigned int)index;
@end

typedef struct screen_char_t {
  unichar c;
  unsigned char bgcolor;
  unsigned char fgcolor;
  Boolean bgcolor_isset:1;
  Boolean fgcolor_isset:1;
  enum {
    kFontWeightNormal,
    kFontWeightBold,
    kFontWeightFaint,
  } weight:2;
  Boolean italicize:1;
  enum {
    kUnderlineNone,
    kUnderlineSingle,
    kUnderlineDouble,
  } underline:2;
  Boolean blink:1;
  Boolean inverse:1;
  Boolean hidden:1;
  Boolean strikethrough:1;
  Boolean wrapped:1;
} screen_char_t;

typedef struct screen_line_t {
  volatile int32_t retain_count;
  size_t size;// size of character buffer in bytes
  screen_char_t buf[];// the actual characters
} screen_line_t;

@interface VT100 : NSObject {
  // sequence parser
  enum {
    kSequenceNone,
    kSequenceESC,
    kSequenceCSI,
    kSequenceDEC,
    kSequenceSCS,
    kSequenceSkipEnd,
  } sequence;
  enum {
    kCSIModifierUndef,
    kCSIModifierNone,
    kCSIModifierGT,
    kCSIModifierQM,
  } CSIModifier;
  unsigned long CSIParam;
  CFMutableArrayRef CSIParams;
  unsigned int SCSIndex;
  unsigned char* encbuf;
  CFIndex encbuf_size,encbuf_index;
  // mode settings
  Boolean bDECBKM:1,mDECBKM:1;
  Boolean bDECCKM:1,mDECCKM:1;
  Boolean bDECOM:1,mDECOM:1,swapDECOM:1;
  Boolean bDECAWM:1,mDECAWM:1,swapDECAWM:1;
  Boolean bDECTCEM:1,mDECTCEM:1;
  Boolean bIRM:1;
  Boolean bLNM:1;
  // screen settings
  Boolean bPastEOL:1;
  Boolean bRedrawAll:1;
  CFIndex currentIndex;
  CFIndex cursorX,saveCursorX,swapCursorX;
  CFIndex cursorY,saveCursorY,swapCursorY;
  CFIndex windowTop,swapWindowTop;
  CFIndex windowBottom,swapWindowBottom;
  CFIndex screenWidth,swapScreenWidth;
  CFIndex screenHeight,swapScreenHeight;
  // graphical settings
  screen_char_t nullChar,saveNullChar,swapNullChar;
  unsigned char glCharset,saveGLCharset,swapGLCharset;
  unsigned char charsets[4],saveCharsets[4],swapCharsets[4];
  // tab stops
  Boolean* tabstops;
  size_t tabstops_size;
  // line buffers
  CFMutableArrayRef lineBuffer;
  CFArrayRef swapLineBuffer;
  screen_line_t* currentLine;
  // change tracking
  CFMutableArrayRef indexMap;
  CFMutableSetRef linesChanged;
  CFIndex indexTop,prevIndex,prevColumn;
}
@property(nonatomic,assign) CFStringEncoding encoding;
@property(nonatomic,readonly) Boolean bDECBKM,bDECCKM,bLNM;
-(id)initWithWidth:(CFIndex)_screenWidth height:(CFIndex)_screenHeight;
-(void)resetTerminal;
-(Boolean)copyChanges:(CFSetRef*)changes deletions:(CFSetRef*)deletions insertions:(CFSetRef*)insertions;
-(screen_char_t*)charactersAtLineIndex:(CFIndex)index length:(CFIndex*)length cursorColumn:(CFIndex*)cursorColumn;
-(CFIndex)numberOfLines;
-(void)processInput:(NSData*)input output:(NSMutableData*)output bell:(BOOL*)bell;
-(void)setWidth:(CFIndex)newWidth height:(CFIndex)newHeight;
@end

typedef struct screen_char_t {
  unichar c;
  unsigned char bgcolor;
  unsigned char fgcolor;
  unsigned int bgcolor_isset:1;
  unsigned int fgcolor_isset:1;
  int bold:2;// -1=faint, 0=normal, 1=bold
  unsigned int italicize:1;
  unsigned int underline:2;// 0=normal, 1=single, 2=double
  unsigned int blink:1;
  unsigned int inverse:1;
  unsigned int hidden:1;
  unsigned int strikethrough:1;
} screen_char_t;

typedef struct screen_line_t {
  volatile int32_t retain_count;
  unsigned int wrapped:1;// whether this line wraps to the next line
  screen_char_t buf[];// the actual characters in this line
} screen_line_t;

@interface VT100 : NSObject {
  // Return key sequences
  NSData* kReturnCR;
  NSData* kReturnCRLF;
  // Sequence parser variables
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
  NSUInteger CSIParam;
  CFMutableArrayRef CSIParams;
  int SCSIndex;
  size_t mbbuf_index,mbbuf_size;
  unsigned char* mbbuf;
  // Internal settings
  BOOL bDECOM,saveDECOM;
  BOOL bDECAWM,saveDECAWM;
  BOOL bIRM;
  BOOL bLNM;
  CFIndex screenWidth;
  CFIndex screenHeight;
  CFIndex windowTop;
  CFIndex windowBottom;
  CFIndex cursorX,saveCursorX;
  CFIndex cursorY,saveCursorY;
  unsigned char CHARSET,saveCHARSET;
  unsigned char charset[4],saveCharset[4];
  screen_char_t nullChar,saveNullChar;
  // Buffers
  BOOL* tabStop;
  CFMutableArrayRef lineBuffer;
  CFArrayRef swapLineBuffer;
  CFIndex swapScreenWidth;
  CFIndex swapScreenHeight;
  CFIndex swapWindowTop;
  CFIndex swapWindowBottom;
  CFIndex swapCursorX;
  CFIndex swapCursorY;
  screen_line_t* currentLine;
}
@property(nonatomic,assign) CFStringEncoding encoding;
-(id)initWithWidth:(CFIndex)_screenWidth height:(CFIndex)_screenHeight;
-(screen_char_t*)charactersAtLineIndex:(CFIndex)index length:(CFIndex*)length cursorPosition:(CFIndex*)cursorPosition;
-(CFIndex)numberOfLines;
-(void)processInput:(NSData*)input output:(NSMutableData*)output bell:(BOOL*)bell;
-(void)resetTerminal;
-(NSData*)returnKey;
-(void)setWidth:(CFIndex)newWidth height:(CFIndex)newHeight;
@end

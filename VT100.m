#include "VT100.h"
#include "vttext.h"
#include <libkern/OSAtomic.h>

#define TAB_WIDTH 8

#define VT100_DA "\033[?1;2c"
#define VT100_DA2 "\033[>61;20;1c"
#define VT100_DSR "\033[n"
#define VT100_CPR "\033[%ld;%ldR"
#define VT100_DECREPTPARM0 "\033[2;1;1;120;120;1;0x"
#define VT100_DECREPTPARM1 "\033[3x"

const unichar charmap_graphics[128]={
  0x0000,0x0001,0x0002,0x0003,0x0004,0x0005,0x0006,0x0007,
  0x0008,0x0009,0x000a,0x000b,0x000c,0x000d,0x000e,0x000f,
  0x0010,0x0011,0x0012,0x0013,0x0014,0x0015,0x0016,0x0017,
  0x0018,0x0019,0x001a,0x001b,0x001c,0x001d,0x001e,0x001f,
  0x0020,0x0021,0x0022,0x0023,0x0024,0x0025,0x0026,0x0027,
  0x0028,0x0029,0x002a,0x002b,0x002c,0x002d,0x002e,0x002f,
  0x0030,0x0031,0x0032,0x0033,0x0034,0x0035,0x0036,0x0037,
  0x0038,0x0039,0x003a,0x003b,0x003c,0x003d,0x003e,0x003f,
  0x0040,0x0041,0x0042,0x0043,0x0044,0x0045,0x0046,0x0047,
  0x0048,0x0049,0x004a,0x004b,0x004c,0x004d,0x004e,0x004f,
  0x0050,0x0051,0x0052,0x0053,0x0054,0x0055,0x0056,0x0057,
  0x0058,0x0059,0x005a,0x005b,0x005c,0x005d,0x005e,0x00a0,
  0x25c6,0x2592,0x2409,0x240c,0x240d,0x240a,0x00b0,0x00b1,
  0x2424,0x240b,0x2518,0x2510,0x250c,0x2514,0x253c,0x23ba,
  0x23bb,0x2500,0x23bc,0x23bd,0x251c,0x2524,0x2534,0x252c,
  0x2502,0x2264,0x2265,0x03c0,0x2260,0x00a3,0x00b7,0x007f,
};

static screen_line_t* screen_line_create(size_t width) {
  screen_line_t* line=malloc(sizeof(screen_line_t)+width*sizeof(screen_char_t));
  line->retain_count=1;
  line->wrapped=NO;
  return line;
}
static screen_line_t* screen_line_retain(CFAllocatorRef allocator,screen_line_t* line) {
  OSAtomicIncrement32Barrier(&line->retain_count);
  return line;
}
static void screen_line_release(CFAllocatorRef allocator,screen_line_t* line) {
  if(OSAtomicDecrement32Barrier(&line->retain_count)==0){free(line);}
}

@implementation VT100
@synthesize encoding;
-(id)initWithWidth:(CFIndex)_screenWidth height:(CFIndex)_screenHeight {
  if((self=[super init])){
    const char CRLF[]={'\r','\n'};
    kReturnCR=[[NSData alloc] initWithBytes:CRLF length:1];
    kReturnCRLF=[[NSData alloc] initWithBytes:CRLF length:2];
    CSIParams=CFArrayCreateMutable(NULL,0,NULL);
    self.encoding=kCFStringEncodingUTF8;
    screenWidth=_screenWidth;
    screenHeight=_screenHeight;
    tabStop=malloc(screenWidth*sizeof(BOOL));
    lineBuffer=CFArrayCreateMutable(NULL,0,&(CFArrayCallBacks){
     .retain=(CFArrayRetainCallBack)screen_line_retain,
     .release=(CFArrayReleaseCallBack)screen_line_release});
    [self resetTerminal];
  }
  return self;
}
-(void)setEncoding:(CFStringEncoding)_encoding {
  if(encoding!=_encoding){
    encoding=_encoding;
    // allocate a backlog for multi-byte characters
    if(mbbuf){free(mbbuf);}
    mbbuf_index=0;
    mbbuf_size=CFStringGetMaximumSizeForEncoding(1,encoding);
    mbbuf=malloc(mbbuf_size);
  }
}
-(screen_char_t*)charactersAtLineIndex:(CFIndex)index length:(CFIndex*)length cursorPosition:(CFIndex*)cursorPosition {
  if(index<0 || index>=CFArrayGetCount(lineBuffer)){return NULL;}
  screen_line_t* line=(screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,index);
  *length=screenWidth;
  *cursorPosition=(line==currentLine)?cursorX:-1;
  return line->buf;
}
-(CFIndex)numberOfLines {
  return CFArrayGetCount(lineBuffer);
}
-(screen_line_t*)insertLineAtIndex:(CFIndex)index {
  screen_line_t* line=screen_line_create(screenWidth);
  CFIndex i;
  for (i=0;i<screenWidth;i++){line->buf[i]=nullChar;}
  CFArrayInsertValueAtIndex(lineBuffer,index,(const void*)line);
  screen_line_release(NULL,line);
  return line;
}
-(void)resetTerminal {
  bDECAWM=YES;// enable auto-wrapping
  // move the cursor to the home position
  cursorX=cursorY=0;
  // reset margins
  windowTop=0;
  windowBottom=screenHeight-1;
  // reset character formatting
  memset(&nullChar,0,sizeof(nullChar));
  // reset tab stops
  CFIndex i;
  for (i=0;i<screenWidth;i++){tabStop[i]=((i%TAB_WIDTH)==0);}
  // reset scrollback buffer
  CFArrayRemoveAllValues(lineBuffer);
  currentLine=[self insertLineAtIndex:0];
  for (i=1;i<screenHeight;i++){[self insertLineAtIndex:i];}
}
-(void)eraseLine:(screen_line_t*)line param:(CFIndex)param {
  CFIndex i,iend=screenWidth-1;
  switch(param){
    case 0:// erase to the end of the line
      if(cursorX>iend){return;}
      i=cursorX;
      break;
    case 1:// erase from the start of the line
      if(cursorX<iend){iend=cursorX;}
    case 2:// erase entire line
      i=0;
      break;
    default:return;
  }
  for (;i<=iend;i++){line->buf[i]=nullChar;}
  line->wrapped=NO;
//#  line->redraw=YES;
}
-(screen_line_t*)shiftLines:(CFIndex)nlines fromY:(CFIndex)fromY toY:(CFIndex)toY {
  CFIndex top=CFArrayGetCount(lineBuffer)-screenHeight;
  CFIndex fromIndex=top+fromY,toIndex=top+toY;
  CFIndex maxlines=(fromIndex>toIndex?
   fromIndex-(top=toIndex):toIndex-(top=fromIndex))+1,i;
  if(nlines>maxlines){nlines=maxlines;}
  // erase and move lines
  screen_line_t* line;
  for (i=0;i<nlines;i++){
    line=screen_line_retain(NULL,(screen_line_t*)
     CFArrayGetValueAtIndex(lineBuffer,fromIndex));
    CFArrayRemoveValueAtIndex(lineBuffer,fromIndex);
    [self eraseLine:line param:2];
    CFArrayInsertValueAtIndex(lineBuffer,toIndex,line);
    screen_line_release(NULL,line);
  }
  // line before fromIndex is not wrapped anymore
  ((screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,
   fromIndex-(fromIndex>toIndex?0:1)))->wrapped=NO;
  // line before toIndex is not wrapped anymore
  ((screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,
   toIndex-1))->wrapped=NO;
  // redraw all lines in between
//#  for (maxlines-=nlines;i<maxlines;i++){
//#    ((screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,top+i))->redraw=YES;
//#  }
  return line;
}
-(void)updateCurrentLine {
  currentLine=(screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,
   CFArrayGetCount(lineBuffer)-screenHeight+cursorY);
}
-(void)nextLine {
  if(cursorY==windowBottom || cursorY==screenHeight-1){
    if(windowTop==0 && windowBottom==screenHeight-1){
      // append a new line
      CFIndex i=CFArrayGetCount(lineBuffer);
      currentLine=[self insertLineAtIndex:i];
      // redraw the entire screen
//#      for (i=iend-screenHeight;i<iend;i++){
//#        ((screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,i))->redraw=YES;
//#      }
    }
    else {
      // scroll up
      currentLine=[self shiftLines:1 fromY:windowTop toY:cursorY];
    }
  }
  else {
    // advance cursor to next line
    cursorY++;
    [self updateCurrentLine];
  }
}
-(void)processInput:(NSData*)input output:(NSMutableData*)output bell:(BOOL*)bell {
  const unsigned char* inputptr=input.bytes;
  const unsigned char* inputend=inputptr+input.length;
  for (;inputptr<inputend;inputptr++){
    switch(*inputptr){
      case 0x00:continue;
      case 0x05:continue;//! Transmit answerback message
      case 0x07:*bell=YES;continue;
      case 0x08:
        if(cursorX>0){cursorX--;}
        continue;
      case 0x09:
        cursorX++;// ensure that we go to the next tab
        while(cursorX<screenWidth && !tabStop[cursorX]){cursorX++;}
        if(cursorX>screenWidth-1){cursorX=screenWidth-1;}
        continue;
      case 0x0A:case 0x0B:case 0x0C:
        [self nextLine];
        continue;
      case 0x0D:cursorX=0;continue;
      case 0x0E:// LS1 (Locking shift 1)
        CHARSET=1;continue;
      case 0x0F:// LS0 (Locking shift 0)
        CHARSET=0;continue;
      case 0x11:continue;//! XON
      case 0x13:continue;//! XOFF
      case 0x18:case 0x1a:goto __endSequence;
      case 0x1b:sequence=kSequenceESC;continue;
    }
    CFIndex i,j;
    if(sequence==kSequenceESC){
      switch(*inputptr){
        case '[':sequence=kSequenceCSI;continue;
        case '#':sequence=kSequenceDEC;continue;
        case '=':break;//! DECKPAM (Keypad Application Mode)
        case '>':break;//! DECKPNM (Keypad Numeric Mode)
        case '<':break;//! VT52=>ANSI mode
        case '(':sequence=kSequenceSCS;SCSIndex=0;continue;
        case ')':sequence=kSequenceSCS;SCSIndex=1;continue;
        case '*':sequence=kSequenceSCS;SCSIndex=2;continue;
        case '+':sequence=kSequenceSCS;SCSIndex=3;continue;
        case '7':// DECSC (Save Cursor)
          saveCursorX=cursorX;
          saveCursorY=cursorY;
          saveNullChar=nullChar;
          saveCHARSET=CHARSET;
          for (i=0;i<4;i++){saveCharset[i]=charset[i];}
          break;
        case '8':// DECRC (Restore Cursor)
          cursorX=saveCursorX;
          cursorY=saveCursorY;
          nullChar=saveNullChar;
          CHARSET=saveCHARSET;
          for (i=0;i<4;i++){charset[i]=saveCharset[i];}
          break;
        case 'E':// NEL (Next Line)
          cursorX=0;
        case 'D':// IND (Index)
          if(cursorY==windowBottom){
//#            currentLine->redraw=YES;
            currentLine=[self shiftLines:1 fromY:windowTop toY:cursorY];
          }
          else if(cursorY<screenHeight-1){
            cursorY++;
            [self updateCurrentLine];
          }
          break;
        case 'H':// HTS (Horizontal Tabulation Set)
          if(cursorX<screenWidth){tabStop[cursorX]=YES;}
          break;
        case 'M':// RI (Reverse Index)
          if(cursorY==windowTop){
//#            currentLine->redraw=YES;
            currentLine=[self shiftLines:1 fromY:windowBottom toY:cursorY];
          }
          else if(cursorY>0){
            cursorY--;
            [self updateCurrentLine];
          }
          break;
        case 'Z':// DECID (Identify Terminal)
          [output appendBytes:VT100_DA length:strlen(VT100_DA)];
          break;
        case 'c':// RIS (Reset To Initial State)
          [self resetTerminal];
          break;
        case 'n':// LS2 (Locking Shift 2)
          CHARSET=2;break;
        case 'o':// LS3 (Locking shift 3)
          CHARSET=3;break;
      }
      goto __endSequence;
    }
    else if(sequence==kSequenceCSI){
      if(CSIModifier==kCSIModifierUndef){
        switch(*inputptr){
          case '>':CSIModifier=kCSIModifierGT;continue;
          case '?':CSIModifier=kCSIModifierQM;continue;
          default:CSIModifier=kCSIModifierNone;
        }
      }
      if(*inputptr>='0' && *inputptr<='9'){
        CSIParam=CSIParam*10+*inputptr-'0';
        continue;
      }
      if(*inputptr==';' || CSIParam>0){
        CFArrayAppendValue(CSIParams,(void*)CSIParam);
        CSIParam=0;
        if(*inputptr==';'){continue;}
      }
      sequence=kSequenceNone;
      CFIndex nparams=CFArrayGetCount(CSIParams);
      CFIndex* params=malloc(nparams*sizeof(CFIndex));
      CFArrayGetValues(CSIParams,CFRangeMake(0,nparams),(const void**)params);
      CFArrayRemoveAllValues(CSIParams);
      BOOL setMode=NO;
      if(CSIModifier==kCSIModifierGT){
        switch(*inputptr){
          case 'c':// DA2 (Secondary Device Attributes)
            if(nparams==0 || params[0]==0){
              [output appendBytes:VT100_DA2 length:strlen(VT100_DA2)];
            }
            break;
        }
      }
      else if(CSIModifier==kCSIModifierQM){
        enum {
          ////bDECCKM=1,
          ////bDECANM=2,
          ////bDECCOLM=3,
          ////bDECSCLM=4,
          ////bDECSCNM=5,
          kDECOM=6,
          kDECAWM=7,
          ///kDECARM=8,
          ////kDECINLM=9,
          ////kDECTCEM=25,
          ////kAllowDECCOLM=40,
        };
        switch(*inputptr){
          case 'h':// DECSET (DEC Private Mode Set)
            setMode=YES;
          case 'l':// DECRST (DEC Private Mode Reset)
            for (i=0;i<nparams;i++){
              switch(params[i]){
                case kDECOM:bDECOM=setMode;break;
                case kDECAWM:bDECAWM=setMode;break;
                case 47:
                  if(setMode){
                    if(!swapLineBuffer){
                      swapLineBuffer=CFArrayCreateCopy(NULL,lineBuffer);
                      swapScreenWidth=screenWidth;
                      swapScreenHeight=screenHeight;
                      swapWindowTop=windowTop;
                      swapWindowBottom=windowBottom;
                      swapCursorX=cursorX;
                      swapCursorY=cursorY;
                    }
                    [self resetTerminal];
                  }
                  else if(swapLineBuffer){
                    CFIndex count=CFArrayGetCount(swapLineBuffer);
                    const void** values=malloc(count*sizeof(screen_line_t*));
                    CFArrayGetValues(swapLineBuffer,CFRangeMake(0,count),values);
                    CFArrayReplaceValues(lineBuffer,CFRangeMake(0,
                     CFArrayGetCount(lineBuffer)),values,count);
                    free(values);
                    CFRelease(swapLineBuffer);
                    swapLineBuffer=NULL;
                    CFIndex width=screenWidth,height=screenHeight;
                    screenWidth=swapScreenWidth;
                    screenHeight=swapScreenHeight;
                    windowTop=swapWindowTop;
                    windowBottom=swapWindowBottom;
                    cursorX=swapCursorX;
                    cursorY=swapCursorY;
                    [self updateCurrentLine];
                    [self setWidth:width height:height];
                  }
                  break;
              }
            }
            break;
          case 'r':// Restore DEC Private Mode value
            for (i=0;i<nparams;i++){
              switch(params[i]){
                case kDECOM:bDECOM=saveDECOM;break;
                case kDECAWM:bDECAWM=saveDECAWM;break;
              }
            }
            break;
          case 's':// Save DEC Private Mode value
            for (i=0;i<nparams;i++){
              switch(params[i]){
                case kDECOM:saveDECOM=bDECOM;break;
                case kDECAWM:saveDECAWM=bDECAWM;break;
              }
            }
            break;
        }
      }
      else if(CSIModifier==kCSIModifierNone){
        switch(*inputptr){
          case '@':// ICH (Insert Character)
            if(cursorX<screenWidth){
              j=(0<params && (i=params[0])>1)?i:1;
              CFIndex maxlen=screenWidth-cursorX;
              if(j>maxlen){j=maxlen;}
              screen_char_t* ptr=currentLine->buf+cursorX;
              screen_char_t* end=ptr+j;
              memmove(end,ptr,(maxlen-j)*sizeof(screen_char_t));
              while(ptr<end){*(ptr++)=nullChar;}
//#              currentLine->redraw=YES;
            }
            break;
          case 'A':// CUU (Cursor Up)
            j=cursorY-((0<nparams && (i=params[0])>1)?i:1);
            if(j<0){j=0;}
            else if(cursorY>=windowTop && j<windowTop){j=windowTop;}
            __setCursorY:if(cursorY!=j){
              cursorY=j;
              [self updateCurrentLine];
            }
            break;
          case 'B':// CUD (Cursor Down)
            j=cursorY+((0<nparams && (i=params[0])>1)?i:1);
            if(j>screenHeight-1){j=screenHeight-1;}
            else if(cursorY<=windowBottom && j>windowBottom){j=windowBottom;}
            goto __setCursorY;
          case 'C':// CUF (Cursor Forward)
            if(cursorX<screenWidth){
              j=cursorX+((0<nparams && (i=params[0])>1)?i:1);
              if(j>screenWidth-1){j=screenWidth-1;}
              __setCursorX:if(cursorX!=j){
                cursorX=j;
//#                currentLine->redraw=YES;
              }
            }
            break;
          case 'D':// CUB (Cursor Backward)
            j=cursorX-((0<nparams && (i=params[0])>1)?i:1);
            if(j<0){j=0;}
            goto __setCursorX;
          case 'G':// CHA (Cursor Horizontal Absolute)
          case '`':// HPA (Horizontal Position Absolute)
            j=(0<nparams && (i=params[0])>1)?i-1:0;
            if(j>screenWidth-1){j=screenWidth-1;}
            goto __setCursorX;
          case 'H':// CUP (Cursor Position)
          case 'f':// HVP (Horizontal and Vertical Position)
            j=(0<nparams && (i=params[0])>1)?i-1:0;
            if(bDECOM){j+=windowTop;}
            if(j>screenHeight-1){j=screenHeight-1;}
            if(cursorY!=j){
              cursorY=j;
              [self updateCurrentLine];
            }
            j=(1<nparams && (i=params[1])>1)?i-1:0;
            if(j>screenWidth-1){j=screenWidth-1;}
            if(cursorX!=j){
              cursorX=j;
//#              currentLine->redraw=YES;
            }
            break;
          case 'J':// ED (Erase In Display)
            switch((0<nparams)?params[0]:0){
              case 0:// erase to end of screen
                [self eraseLine:currentLine param:0];
                i=cursorY+1;
                j=screenHeight;
                __eraseLines:if(i<j){
                  CFIndex top=CFArrayGetCount(lineBuffer)-screenHeight;
                  if(top+i>0){
                    // previous line is not wrapped anymore
                    ((screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,
                     top+i-1))->wrapped=NO;
                  }
                  for (;i<j;i++){
                    [self eraseLine:(screen_line_t*)
                     CFArrayGetValueAtIndex(lineBuffer,top+i) param:2];
                  }
                }
                break;
              case 1:// erase from start of screen
                [self eraseLine:currentLine param:1];
                i=0;
                j=cursorY;
                goto __eraseLines;
              case 2:// erase entire screen
                i=0;
                j=screenHeight;
                goto __eraseLines;
            }
            break;
          case 'K':// EL (Erase In Line)
            [self eraseLine:currentLine param:(0<nparams)?params[0]:0];
            break;
          case 'L':// IL (Insert Line)
            if(cursorY>=windowTop && cursorY<=windowBottom){
              currentLine=[self shiftLines:(0<nparams && params[0]>1)?params[0]:1
               fromY:windowBottom toY:cursorY];
            }
            break;
          case 'M':// DL (Delete Line)
            if(cursorY>=windowTop && cursorY<=windowBottom){
              [self shiftLines:(0<nparams && params[0]>1)?params[0]:1
               fromY:cursorY toY:windowBottom];
              [self updateCurrentLine];
            }
            break;
          case 'P':// DCH (Delete Character)
            if(cursorX<screenWidth){
              j=(0<params && (i=params[0])>1)?i:1;
              CFIndex maxlen=screenWidth-cursorX;
              if(j>maxlen){j=maxlen;}
              screen_char_t* ptr=currentLine->buf+cursorX;
              memmove(ptr,ptr+j,(maxlen-j)*sizeof(screen_char_t));
              screen_char_t* end=ptr+maxlen;
              ptr=end-j;
              while(ptr<end){*(ptr++)=nullChar;}
//#              currentLine->redraw=YES;
            }
            break;
          case 'S':// SU (Scroll Up)
            [self shiftLines:(0<nparams && params[0]>1)?params[0]:1
             fromY:windowTop toY:windowBottom];
            [self updateCurrentLine];
            break;
          case 'T':// SD (Scroll Down)
            [self shiftLines:(0<nparams && params[0]>1)?params[0]:1
             fromY:windowBottom toY:windowTop];
            [self updateCurrentLine];
            break;
          case 'X':// ECH (Erase Character)
            if(cursorX<screenWidth){
              j=cursorX+((0<nparams && params[0]>1)?params[0]:1);
              if(j>screenWidth){j=screenWidth;}
              for (i=cursorX;i<j;i++){currentLine->buf[i]=nullChar;}
//#              currentLine->redraw=YES;
            }
            break;
          case 'a':// HPR (Horizontal Position Relative)
            j=cursorX+((0<nparams && (i=params[0])>1)?i:1);
            if(j>screenWidth-1){j=screenWidth-1;}
            goto __setCursorX;
          case 'c':// DA (Device Attributes)
            [output appendBytes:VT100_DA length:strlen(VT100_DA)];
            break;
          case 'd':// VPA (Vertical Position Absolute)
            j=(0<nparams && (i=params[0])>1)?i-1:0;
            if(bDECOM){j+=windowTop;}
            if(j>screenHeight-1){j=screenHeight-1;}
            goto __setCursorY;
          case 'e':// VPR (Vertical Position Relative)
            j=cursorY+((0<nparams && (i=params[0])>1)?i:1);
            if(j>screenHeight-1){j=screenHeight-1;}
            goto __setCursorY;
          case 'g':// TBC (Tabulation Clear)
            switch((0<nparams)?params[0]:0){
              case 0:// clear tab stop at current position
                if(cursorX<screenWidth){tabStop[cursorX]=NO;}
                break;
              case 3:// clear all tab stops
                for (i=0;i<screenWidth;i++){tabStop[i]=NO;}
                break;
            }
            break;
          case 'h':// SM (Set Mode)
            setMode=YES;
          case 'l':// RM (Reset Mode)
            for (i=0;i<nparams;i++){
              switch(params[i]){
                case 4:bIRM=setMode;break;
                case 20:bLNM=setMode;break;
              }
            }
            break;
          case 'i':break;//! MC (Media Copy)
          case 'm':// SGR (Select Graphic Rendition)
            for (i=0;i<nparams;i++){
              CFIndex arg=params[i];
              switch(arg){
                case 0:__defaultSGR:
                  // all attributes off
                  memset(&nullChar,0,sizeof(nullChar));
                  break;
                case 1:nullChar.bold=1;break;
                case 2:nullChar.bold=-1;break;
                case 3:nullChar.italicize=YES;break;
                case 4:nullChar.underline=1;break;
                case 5:nullChar.blink=YES;break;
                case 7:nullChar.inverse=YES;break;
                case 8:nullChar.hidden=YES;break;
                case 9:nullChar.strikethrough=YES;break;
                case 21:nullChar.underline=2;break;
                case 22:nullChar.bold=0;break;
                case 23:nullChar.italicize=NO;break;
                case 24:nullChar.underline=0;break;
                case 25:nullChar.blink=NO;break;
                case 27:nullChar.inverse=NO;break;
                case 28:nullChar.hidden=NO;break;
                case 29:nullChar.strikethrough=NO;break;
                case 38:
                  if(i+1<nparams){
                    switch(params[++i]){
                      case 2:
                        if(i+3<nparams){i+=3;}//! RGB
                        break;
                      case 5:
                        if(i+1<nparams){
                          nullChar.fgcolor_isset=YES;
                          nullChar.fgcolor=params[++i];
                        }
                        break;
                    }
                  }
                  break;
                case 39:nullChar.fgcolor_isset=NO;break;
                case 48:
                  if(i+1<nparams){
                    switch(params[++i]){
                      case 2:
                        if(i+3<nparams){i+=3;}//! RGB
                        break;
                      case 5:
                        if(i+1<nparams){
                          nullChar.bgcolor_isset=YES;
                          nullChar.bgcolor=params[++i];
                        }
                        break;
                    }
                  }
                  break;
                case 49:nullChar.bgcolor_isset=NO;break;
                default:
                  if(arg>=30 && arg<=37){
                    nullChar.fgcolor_isset=YES;
                    nullChar.fgcolor=arg-30;
                  }
                  else if(arg>=40 && arg<=47){
                    nullChar.bgcolor_isset=YES;
                    nullChar.bgcolor=arg-40;
                  }
                  else if(arg>=90 && arg<=97){
                    nullChar.fgcolor_isset=YES;
                    nullChar.fgcolor=arg-90+8;
                  }
                  else if(arg>=100 && arg<=107){
                    nullChar.bgcolor_isset=YES;
                    nullChar.bgcolor=arg-100+8;
                  }
              }
            }
            if(!i){goto __defaultSGR;}
            break;
          case 'n':// DSR (Device Status Report)
            switch((0<nparams)?params[0]:0){
              case 5:
                [output appendBytes:VT100_DSR length:strlen(VT100_DSR)];
                break;
              case 6:{
                char* msg=NULL;
                if(asprintf(&msg,VT100_CPR,cursorY+1-(bDECOM?windowTop:0),
                 (cursorX<screenWidth)?cursorX+1:screenWidth)!=-1){
                  [output appendBytes:msg length:strlen(msg)];
                }
                if(msg){free(msg);}
                break;}
            }
            break;
          case 'q':break;//! DECLL (Load LEDs)
          case 'r':// DECSTBM (Set Top and Bottom Margins)
            if((i=(0<nparams)?params[0]:0)){i--;}
            if((j=(1<nparams)?params[1]:0)){j--;}
            else {j=screenHeight-1;}
            if(i<j && j<screenHeight){
              windowTop=i;
              windowBottom=j;
              cursorX=0;
              cursorY=bDECOM?windowTop:0;
              [self updateCurrentLine];
            }
            break;
          case 't':break;//! Manipulate window
          case 'x':// DECREQTPARM (Request Terminal Parameters)
            if(nparams==0 || params[0]==0){
              [output appendBytes:VT100_DECREPTPARM0
               length:strlen(VT100_DECREPTPARM0)];
            }
            else if(params[0]==1){
              [output appendBytes:VT100_DECREPTPARM1
               length:strlen(VT100_DECREPTPARM1)];
            }
            break;
          case 'y':break;//! DECTST (Invoke Confidence Test)
          case '$':case '&':case '\'':sequence=kSequenceSkipEnd;
        }
      }
      free(params);
      CSIModifier=kCSIModifierUndef;
      continue;
    }
    else if(sequence==kSequenceDEC){
      switch(*inputptr){
        case '3':break;//! DECDHL (Double Height Line, top half)
        case '4':break;//! DECDHL (Double Height Line, bottom half)
        case '5':break;//! DECSWL (Single Width Line)
        case '6':break;//! DECDWL (Double Width Line)
        case '8':{// DECALN (Screen Alignment Test)
          CFIndex count=CFArrayGetCount(lineBuffer);
          for (i=count-screenHeight;i<count;i++){
            screen_line_t* line=(screen_line_t*)
             CFArrayGetValueAtIndex(lineBuffer,i);
            for (j=0;j<screenWidth;j++){
              line->buf[j]=nullChar;
              line->buf[j].c='E';
            }
            line->wrapped=NO;
//#            line->redraw=YES;
          }
          break;}
      }
      goto __endSequence;
    }
    else if(sequence==kSequenceSCS){
      charset[SCSIndex]=*inputptr;
      goto __endSequence;
    }
    else if(sequence==kSequenceSkipEnd) __endSequence:{
      sequence=kSequenceNone;
      continue;
    }
    unichar uc;
    if(*inputptr<0x80){
      uc=(charset[CHARSET]=='0')?charmap_graphics[*inputptr]:*inputptr;
    }
    else {
      mbbuf[mbbuf_index++]=*inputptr;
      CFStringRef mbstr=CFStringCreateWithBytesNoCopy(NULL,
       mbbuf,mbbuf_index,encoding,false,kCFAllocatorNull);
      if(mbbuf_index==mbbuf_size){mbbuf_index=0;}
      if(!mbstr){continue;}
      uc=CFStringGetCharacterAtIndex(mbstr,0);
      CFRelease(mbstr);
      // skip zero-width characters
      if(uc==0x200b || uc==0x200c || uc==0x200d || uc==0xfeff){continue;}
    }
    if(cursorX==screenWidth){
      // we are past the end of the line
      if(bDECAWM){
        // autowrap mode: go to next line
        cursorX=0;
        currentLine->wrapped=YES;
        [self nextLine];
      }
      else {cursorX--;}
    }
    else if(bIRM && cursorX<screenWidth-1){
      // insert mode: shift characters to the right
      screen_char_t* ptr=currentLine->buf+cursorX;
      memmove(ptr+1,ptr,(screenWidth-cursorX)*sizeof(screen_char_t));
    }
    currentLine->buf[cursorX]=nullChar;
    currentLine->buf[cursorX].c=uc;
    cursorX++;
//#    currentLine->redraw=YES;
  }
}
-(NSData*)returnKey {
  return bLNM?kReturnCRLF:kReturnCR;
}
-(void)setWidth:(CFIndex)newWidth height:(CFIndex)newHeight {
  if((newWidth==screenWidth && newHeight==screenHeight)
   || newWidth<2 || newHeight<4){return;}
  // resize tab stop array
  tabStop=realloc(tabStop,newWidth);
  CFIndex i;
  for (i=screenWidth;i<newWidth;i++){tabStop[i]=((i%TAB_WIDTH)==0);}
  // delete trailing blank lines
  CFIndex count=CFArrayGetCount(lineBuffer);
  CFIndex cindex=count-screenHeight+cursorY;
  while(count>0){
    screen_line_t* line=(screen_line_t*)
     CFArrayGetValueAtIndex(lineBuffer,count-1);
    CFIndex j;
    for (j=0;j<screenWidth;j++){
      if(line->buf[j].c){goto __afterDeletion;}
    }
    CFArrayRemoveValueAtIndex(lineBuffer,--count);
  }
  __afterDeletion:
  if(newHeight!=screenHeight){
    if(cursorY>newHeight-1){cursorY=newHeight-1;}
    saveCursorY=0;
    windowTop=0;
    windowBottom=newHeight-1;
  }
  // resize lines and wrap as necessary
  if(newWidth!=screenWidth){
    cursorX=saveCursorX=0;
    CFMutableDataRef wrapbuf=CFDataCreateMutable(NULL,0);
    for (i=0;i<count;i++){
      screen_line_t* line=(screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,i);
      BOOL wrapped=line->wrapped;
      // collect all wrapped lines into one buffer
      while(1){
        if(line==currentLine){cindex=i;}
        CFIndex cpwidth=screenWidth;
        if(!wrapped){
          // find the right-trimmed width of this line
          while(cpwidth>0 && line->buf[cpwidth-1].c==0){cpwidth--;}
        }
        CFDataAppendBytes(wrapbuf,(const UInt8*)line->buf,
         cpwidth*sizeof(screen_char_t));
        CFArrayRemoveValueAtIndex(lineBuffer,i);
        if(--count==i || !wrapped){break;}
        line=(screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,i);
        wrapped=line->wrapped;
      }
      // redistribute characters across new lines
      line=NULL;
      screen_char_t* src=(screen_char_t*)CFDataGetBytePtr(wrapbuf);
      CFIndex width=CFDataGetLength(wrapbuf)/sizeof(screen_char_t);
      do {
        if(line){
          // previous line was wrapped
          line->wrapped=YES;
          i++;
        }
        line=screen_line_create(newWidth);
        CFArrayInsertValueAtIndex(lineBuffer,i,(const void*)line);
        screen_line_release(NULL,line);
        count++;
        CFIndex cpwidth;
        if(width<newWidth){
          // wrapping ends on this line
          cpwidth=width;
          memset(line->buf+width,0,(newWidth-width)*sizeof(screen_char_t));
        }
        else {cpwidth=newWidth;}
        memcpy(line->buf,src,cpwidth*sizeof(screen_char_t));
        src+=cpwidth;
        width-=cpwidth;
      } while(width>0);
      // reset the buffer
      CFDataSetLength(wrapbuf,0);
    }
    CFRelease(wrapbuf);
  }
  screenWidth=newWidth;
  screenHeight=newHeight;
  CFIndex nlines=cindex-cursorY+newHeight;
  // append blank lines to maintain cursorY
  for (;count<nlines;count++){[self insertLineAtIndex:count];}
  [self updateCurrentLine];
}
-(void)dealloc {
  [kReturnCR release];
  [kReturnCRLF release];
  CFRelease(CSIParams);
  if(mbbuf){free(mbbuf);}
  free(tabStop);
  CFRelease(lineBuffer);
  if(swapLineBuffer){CFRelease(swapLineBuffer);}
  [super dealloc];
}
@end

#include "VT100.h"
#include "vttext.h"
#include <libkern/OSAtomic.h>

#define TAB_WIDTH 8

#define VT100_DA "\033[?1;2c"
#define VT100_DA2 "\033[>61;20;1c"
#define VT100_DSR "\033[0n"
#define VT100_CPR "\033[%ld;%ldR"
#define VT100_DECREPTPARM0 "\033[2;1;1;120;120;1;0x"
#define VT100_DECREPTPARM1 "\033[3x"

//#define DEBUG_CHANGES
#ifdef DEBUG_CHANGES
static NSString* $_dSet(CFSetRef set) {
  CFIndex count=CFSetGetCount(set),i;
  CFIndex* items=malloc(count*sizeof(CFIndex));
  CFSetGetValues(set,(const void**)items);
  NSMutableString* str=[NSMutableString string];
  for (i=0;i<count;i++){[str appendFormat:@"%s%ld",i?",":"",items[i]];}
  free(items);
  return str;
}
static NSString* $_dArray(CFArrayRef array) {
  CFIndex count=CFArrayGetCount(array),i;
  NSMutableString* str=[NSMutableString string];
  for (i=0;i<count;i++){
    [str appendFormat:@"%s%ld:%ld",i?",":"",i,
     (CFIndex)CFArrayGetValueAtIndex(array,i)];
  }
  return str;
}
#endif

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

static screen_line_t* screen_line_create(size_t size) {
  screen_line_t* line=calloc(1,sizeof(screen_line_t)+size);
  line->retain_count=1;
  line->size=size;
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
@synthesize bDECBKM,bDECCKM,bLNM;
-(id)initWithWidth:(CFIndex)_screenWidth height:(CFIndex)_screenHeight {
  if((self=[super init])){
    CSIParams=CFArrayCreateMutable(NULL,0,NULL);
    encoding=kCFStringEncodingASCII;
    screenWidth=_screenWidth;
    screenHeight=_screenHeight;
    tabstops=malloc(tabstops_size=screenWidth);
    lineBuffer=CFArrayCreateMutable(NULL,0,&(CFArrayCallBacks){
     .retain=(CFArrayRetainCallBack)screen_line_retain,
     .release=(CFArrayReleaseCallBack)screen_line_release});
    indexMap=CFArrayCreateMutable(NULL,0,NULL);
    linesChanged=CFSetCreateMutable(NULL,0,NULL);
    [self resetTerminal];
  }
  return self;
}
-(void)resetTerminal {
  bDECBKM=false;// send delete on backarrow
  bDECCKM=false;// send normal cursor keys
  bDECOM=false;// disable origin mode
  bDECAWM=true;// enable auto-wrapping
  bDECTCEM=true;// show the cursor
  bIRM=false;// disable insert mode
  bLNM=false;// send CR on enter
  bPastEOL=false;// cursor is not past end of line
  currentIndex=cursorX=cursorY=0;
  windowTop=0;
  windowBottom=screenHeight-1;
  memset(&nullChar,0,sizeof(nullChar));
  CFIndex i;
  // reset tab stops
  for (i=0;i<screenWidth;i++){tabstops[i]=((i%TAB_WIDTH)==0);}
  // reset line buffer
  bRedrawAll=true;
  CFArrayRemoveAllValues(lineBuffer);
  size_t size=screenWidth*sizeof(screen_char_t);
  for (i=0;i<screenHeight;i++){
    screen_line_t* newline=screen_line_create(size);
    if(i==cursorY){currentLine=newline;}
    CFArrayAppendValue(lineBuffer,newline);
    screen_line_release(NULL,newline);
  }
}
-(Boolean)copyChanges:(CFSetRef*)changes deletions:(CFSetRef*)deletions insertions:(CFSetRef*)insertions {
  Boolean didcopy;
  CFIndex count=CFArrayGetCount(indexMap),i;
  if(bRedrawAll){bRedrawAll=didcopy=false;}
  else {
#ifdef DEBUG_CHANGES
    NSLog(@"START linesChanged=(%@) prevIndex=%ld currentIndex=%ld\n"
     "screenHeight=%ld indexTop=%ld indexMap=[%@]\n",
     $_dSet(linesChanged),prevIndex,currentIndex,
     screenHeight,indexTop,$_dArray(indexMap));
#endif
    CFMutableSetRef mdeletions=CFSetCreateMutable(NULL,count,NULL);
    CFMutableSetRef minsertions=CFSetCreateMutable(NULL,count,NULL);
    CFIndex index=indexTop,lastindex=index,cindex=-1,newspan=0;
    for (i=0;i<=count;i++,index++){
      CFIndex j=(i==count)?screenHeight:
       (CFIndex)CFArrayGetValueAtIndex(indexMap,i);
      if(j==-1){
        CFSetAddValue(minsertions,(void*)index);
        newspan++;
      }
      else {
        CFIndex newindex=index-i+j;
        while(lastindex<newindex){
          if(newspan>0){
            CFSetRemoveValue(minsertions,(void*)lastindex);
            CFSetAddValue(linesChanged,(void*)lastindex);
            newspan--;
          }
          else {
            CFSetRemoveValue(linesChanged,(void*)lastindex);
            CFSetAddValue(mdeletions,(void*)lastindex);
          }
          lastindex++;
        }
        if(prevIndex==lastindex
         && ((cindex=index)!=currentIndex || prevColumn!=cursorX)){
          // erase cursor at previous position
          CFSetAddValue(linesChanged,(void*)lastindex);
        }
        lastindex++;
        newspan=0;
      }
    }
    if(bDECTCEM && (cindex!=currentIndex || prevColumn!=cursorX)){
      // redraw cursor at current position
      [self changedLineAtIndex:currentIndex];
    }
    prevIndex=bDECTCEM?currentIndex:-1;
    prevColumn=bDECTCEM?cursorX:-1;
#ifdef DEBUG_CHANGES
    NSLog(@"END linesChanged=(%@) mdeletions=(%@) minsertions=(%@)",
     $_dSet(linesChanged),$_dSet(mdeletions),$_dSet(minsertions));
#endif
    *changes=CFSetCreateCopy(NULL,linesChanged);
    *deletions=mdeletions;
    *insertions=minsertions;
    didcopy=true;
  }
  // reset change tracking state
  CFSetRemoveAllValues(linesChanged);
  indexTop=CFArrayGetCount(lineBuffer)-screenHeight;
  CFIndex* list=malloc(screenHeight*sizeof(CFIndex));
  for (i=0;i<screenHeight;i++){list[i]=i;}
  CFArrayReplaceValues(indexMap,CFRangeMake(0,count),
   (const void**)list,screenHeight);
  free(list);
  return didcopy;
}
-(screen_char_t*)charactersAtLineIndex:(CFIndex)index length:(CFIndex*)length cursorColumn:(CFIndex*)cursorColumn {
  if(index<0 || index>=CFArrayGetCount(lineBuffer)){return NULL;}
  screen_line_t* line=(screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,index);
  *length=screenWidth;
  if(cursorColumn){*cursorColumn=(bDECTCEM && line==currentLine)?cursorX:-1;}
  return line->buf;
}
-(CFIndex)numberOfLines {
  return CFArrayGetCount(lineBuffer);
}
-(void)shiftLines:(CFIndex)nlines fromY:(CFIndex)fromY toY:(CFIndex)toY {
  CFIndex top=CFArrayGetCount(lineBuffer)-screenHeight;
  CFIndex fromIndex=top+fromY,toIndex=top+toY;
  CFIndex maxlines=(fromIndex<toIndex?toIndex-fromIndex:fromIndex-toIndex)+1,i;
  if(nlines>maxlines){nlines=maxlines;}
  size_t size=screenWidth*sizeof(screen_char_t);
  for (i=0;i<nlines;i++){
    CFArrayRemoveValueAtIndex(lineBuffer,fromIndex);
    screen_line_t* newline=screen_line_create(size);
    CFIndex j;
    for (j=0;j<screenWidth;j++){newline->buf[j]=nullChar;}
    CFArrayInsertValueAtIndex(lineBuffer,toIndex,newline);
    screen_line_release(NULL,newline);
  }
  currentLine=(screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,currentIndex);
  if(!bRedrawAll){
    fromIndex-=indexTop;
    toIndex-=indexTop;
    for (i=0;i<nlines;i++){
      CFArrayRemoveValueAtIndex(indexMap,fromIndex);
      CFArrayInsertValueAtIndex(indexMap,toIndex,(void*)-1);
    }
  }
}
-(void)updateCurrentLine {
  currentLine=(screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,
   currentIndex=CFArrayGetCount(lineBuffer)-screenHeight+cursorY);
}
-(void)nextLine {
  if(cursorY==windowBottom || cursorY==screenHeight-1){
    if(windowTop==0 && windowBottom==screenHeight-1){
      currentLine=screen_line_create(screenWidth*sizeof(screen_char_t));
      CFArrayAppendValue(lineBuffer,currentLine);
      screen_line_release(NULL,currentLine);
      currentIndex=CFArrayGetCount(lineBuffer)-1;
      if(!bRedrawAll){CFArrayAppendValue(indexMap,(void*)-1);}
    }
    else {[self shiftLines:1 fromY:windowTop toY:cursorY];}
  }
  else {
    cursorY++;
    [self updateCurrentLine];
  }
}
-(void)changedLineAtIndex:(CFIndex)index {
  if(!bRedrawAll){
    index=(CFIndex)CFArrayGetValueAtIndex(indexMap,index-indexTop);
    if(index!=-1){CFSetAddValue(linesChanged,(void*)(index+indexTop));}
  }
}
-(void)processInput:(NSData*)input output:(NSMutableData*)output bell:(BOOL*)bell {
  const unsigned char* inputptr=input.bytes;
  const unsigned char* inputend=inputptr+input.length;
  for (;inputptr<inputend;inputptr++){
    CFIndex i,j;
    if(*inputptr<0x20){// this is a control character
      switch(*inputptr){
        case 0x05:break;//! ENQ
        case 0x07:*bell=YES;break;
        case 0x08:
          bPastEOL=false;
          if(cursorX>0){cursorX--;}
          break;
        case 0x09:
          while(cursorX<screenWidth-1 && !tabstops[++cursorX]);
          break;
        case 0x0A:case 0x0B:case 0x0C:
          if(!bPastEOL){[self nextLine];}
          break;
        case 0x0D:
          bPastEOL=false;
          cursorX=0;
          break;
        case 0x0E:glCharset=1;break;
        case 0x0F:glCharset=0;break;
        case 0x11:break;//! XON
        case 0x13:break;//! XOFF
        case 0x18:case 0x1a:sequence=kSequenceNone;break;
        case 0x1b:sequence=kSequenceESC;break;
      }
    }
    else if(sequence==kSequenceESC){
      sequence=kSequenceNone;
      switch(*inputptr){
        case '[':sequence=kSequenceCSI;break;
        case '#':sequence=kSequenceDEC;break;
        case '=':break;//! DECKPAM (Keypad Application Mode)
        case '>':break;//! DECKPNM (Keypad Numeric Mode)
        case '<':break;//! VT52=>ANSI mode
        case '(':sequence=kSequenceSCS;SCSIndex=0;break;
        case ')':sequence=kSequenceSCS;SCSIndex=1;break;
        case '*':sequence=kSequenceSCS;SCSIndex=2;break;
        case '+':sequence=kSequenceSCS;SCSIndex=3;break;
        case '7':// DECSC (Save Cursor)
          saveCursorX=cursorX;
          saveCursorY=cursorY;
          saveNullChar=nullChar;
          saveGLCharset=glCharset;
          memcpy(saveCharsets,charsets,sizeof(charsets));
          break;
        case '8':// DECRC (Restore Cursor)
          bPastEOL=false;
          cursorX=saveCursorX;
          cursorY=saveCursorY;
          [self updateCurrentLine];
          nullChar=saveNullChar;
          glCharset=saveGLCharset;
          memcpy(charsets,saveCharsets,sizeof(charsets));
          break;
        case 'E':// NEL (Next Line)
          bPastEOL=false;
          cursorX=0;
        case 'D':// IND (Index)
          if(cursorY==windowBottom){
            [self shiftLines:1 fromY:windowTop toY:windowBottom];
          }
          else if(cursorY<screenHeight-1){
            cursorY++;
            [self updateCurrentLine];
          }
          break;
        case 'H':// HTS (Horizontal Tabulation Set)
          tabstops[cursorX]=true;
          break;
        case 'M':// RI (Reverse Index)
          if(cursorY==windowTop){
            [self shiftLines:1 fromY:windowBottom toY:windowTop];
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
        case 'n':glCharset=2;break;
        case 'o':glCharset=3;break;
      }
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
      unsigned char opt=0;
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
          kDECCKM=1,
          kDECOM=6,
          kDECAWM=7,
          kDECTCEM=25,
          kDECBKM=67,
        };
        switch(*inputptr){
          case 'h':// DECSET (DEC Private Mode Set)
            opt=1;
          case 'l':// DECRST (DEC Private Mode Reset)
            __DECRST:for (i=0;i<nparams;i++){
              switch(params[i]){
                case kDECBKM:bDECBKM=(opt==2)?mDECBKM:opt;break;
                case kDECCKM:bDECCKM=(opt==2)?mDECCKM:opt;break;
                case kDECOM:bDECOM=(opt==2)?mDECOM:opt;break;
                case kDECAWM:bDECAWM=(opt==2)?mDECAWM:opt;break;
                case kDECTCEM:bDECTCEM=(opt==2)?mDECTCEM:opt;break;
                case 3:{// DECCOLM (132-column mode)
                  // reset the screen but do not actually resize
                  CFIndex count=CFArrayGetCount(lineBuffer);
                  for (i=count-screenHeight;i<count;i++){
                    screen_line_t* line=(screen_line_t*)
                     CFArrayGetValueAtIndex(lineBuffer,i);
                    memset(line->buf,0,line->size);
                    [self changedLineAtIndex:i];
                  }
                  bPastEOL=false;
                  cursorX=cursorY=0;
                  windowTop=0;
                  windowBottom=screenHeight-1;
                  [self updateCurrentLine];
                  break;
                }
                case 47:
                case 1047:
                case 1049:
                  if(opt==1){
                    // Use alternate line buffer
                    if(!swapLineBuffer){
                      swapLineBuffer=CFArrayCreateCopy(NULL,lineBuffer);
                      swapDECOM=bDECOM;
                      swapDECAWM=bDECAWM;
                      swapScreenWidth=screenWidth;
                      swapScreenHeight=screenHeight;
                      swapWindowTop=windowTop;
                      swapWindowBottom=windowBottom;
                      swapCursorX=cursorX;
                      swapCursorY=cursorY;
                      swapNullChar=nullChar;
                      swapGLCharset=glCharset;
                      memcpy(swapCharsets,charsets,sizeof(charsets));
                    }
                    [self resetTerminal];
                  }
                  else if(swapLineBuffer){
                    // Restore default line buffer
                    CFIndex count=CFArrayGetCount(swapLineBuffer);
                    const void** values=malloc(count*sizeof(screen_line_t*));
                    CFArrayGetValues(swapLineBuffer,CFRangeMake(0,count),values);
                    CFArrayReplaceValues(lineBuffer,CFRangeMake(0,
                     CFArrayGetCount(lineBuffer)),values,count);
                    free(values);
                    CFRelease(swapLineBuffer);
                    swapLineBuffer=NULL;
                    bDECOM=swapDECOM;
                    bDECAWM=swapDECAWM;
                    CFIndex width=screenWidth,height=screenHeight;
                    screenWidth=swapScreenWidth;
                    screenHeight=swapScreenHeight;
                    windowTop=swapWindowTop;
                    windowBottom=swapWindowBottom;
                    bPastEOL=false;
                    bRedrawAll=true;
                    cursorX=swapCursorX;
                    cursorY=swapCursorY;
                    [self updateCurrentLine];
                    [self setWidth:width height:height];
                    nullChar=swapNullChar;
                    glCharset=swapGLCharset;
                    memcpy(charsets,swapCharsets,sizeof(charsets));
                  }
                  break;
              }
            }
            break;
          case 'r':// Restore DEC Private Mode value
            opt=2;
            goto __DECRST;
          case 's':// Save DEC Private Mode value
            for (i=0;i<nparams;i++){
              switch(params[i]){
                case kDECBKM:mDECBKM=bDECBKM;break;
                case kDECCKM:mDECCKM=bDECCKM;break;
                case kDECOM:mDECOM=bDECOM;break;
                case kDECAWM:mDECAWM=bDECAWM;break;
                case kDECTCEM:mDECTCEM=bDECTCEM;break;
              }
            }
            break;
        }
      }
      else if(CSIModifier==kCSIModifierNone){
        switch(*inputptr){
          case 'F':// CPL (Cursor Previous Line)
            bPastEOL=false;
            cursorX=0;
          case 'A':// CUU (Cursor Up)
            j=cursorY-((0<nparams && (i=params[0])>1)?i:1);
            if(cursorY>=windowTop && j<windowTop){j=windowTop;}
            else if(j<0){j=0;}
            if(cursorY!=j){
              cursorY=j;
              [self updateCurrentLine];
            }
            break;
          case 'E':// CNL (Cursor Next Line)
            bPastEOL=false;
            cursorX=0;
          case 'B':// CUD (Cursor Down)
          case 'e':// VPR (Vertical Position Relative)
            j=cursorY+((0<nparams && (i=params[0])>1)?i:1);
            if(cursorY<=windowBottom && j>windowBottom){j=windowBottom;}
            else if(j>screenHeight-1){j=screenHeight-1;}
            if(cursorY!=j){
              cursorY=j;
              [self updateCurrentLine];
            }
            break;
          case 'C':// CUF (Cursor Forward)
          case 'a':// HPR (Horizontal Position Relative)
            bPastEOL=false;
            cursorX+=((0<nparams && (i=params[0])>1)?i:1);
            if(cursorX>screenWidth-1){cursorX=screenWidth-1;}
            break;
          case 'D':// CUB (Cursor Backward)
            bPastEOL=false;
            cursorX-=((0<nparams && (i=params[0])>1)?i:1);
            if(cursorX<0){cursorX=0;}
            break;
          case 'G':// CHA (Cursor Horizontal Absolute)
          case '`':// HPA (Horizontal Position Absolute)
            bPastEOL=false;
            cursorX=(0<nparams && (i=params[0])>1)?i-1:0;
            if(cursorX>screenWidth-1){cursorX=screenWidth-1;}
            break;
          case 'H':// CUP (Cursor Position)
          case 'f':// HVP (Horizontal and Vertical Position)
            bPastEOL=false;
            cursorX=(1<nparams && (i=params[1])>1)?i-1:0;
            if(cursorX>screenWidth-1){cursorX=screenWidth-1;}
          case 'd':// VPA (Vertical Position Absolute)
            j=(0<nparams && (i=params[0])>1)?i-1:0;
            if(bDECOM){j+=windowTop;}
            if(j>screenHeight-1){j=screenHeight-1;}
            if(cursorY!=j){
              cursorY=j;
              [self updateCurrentLine];
            }
            break;
          case 'I':// CHT (Cursor Horizontal Forward Tabulation)
            j=(0<nparams && params[0]>1)?params[0]:1;
            while(cursorX<screenWidth-1 && (!tabstops[++cursorX] || --j>0));
            break;
          case 'J':// ED (Erase In Display)
            i=(j=CFArrayGetCount(lineBuffer))-screenHeight;
            switch((0<nparams)?params[0]:0){
              case 0:// erase to end of screen
                i+=cursorY+1;
                opt=1;// fall through to EL
                bPastEOL=false;
                break;
              case 1:// erase from start of screen
                j=i+cursorY;
                opt=1;// fall through to EL
              case 2:// erase entire screen
                bPastEOL=false;
                break;
            }
            for (;i<j;i++){
              screen_char_t* ptr=((screen_line_t*)
               CFArrayGetValueAtIndex(lineBuffer,i))->buf;
              screen_char_t* end=ptr+screenWidth;
              while(ptr<end){*(ptr++)=nullChar;}
              [self changedLineAtIndex:i];
            }
            if(!opt){break;}
          case 'K':// EL (Erase In Line)
            i=j=screenWidth-1;
            switch((0<nparams)?params[0]:0){
              case 0:// erase to end of line
                if(cursorX<i){i=cursorX;}
                bPastEOL=false;
                break;
              case 1:// erase from start of line
                if(cursorX<j){j=cursorX;}
              case 2:// erase entire line
                i=0;
                bPastEOL=false;
                break;
            }
            for (;i<=j;i++){currentLine->buf[i]=nullChar;}
            [self changedLineAtIndex:currentIndex];
            break;
          case 'L':// IL (Insert Line)
            bPastEOL=false;
            cursorX=0;
            if(cursorY>=windowTop && cursorY<=windowBottom){
              [self shiftLines:(0<nparams && params[0]>1)?params[0]:1
               fromY:windowBottom toY:cursorY];
            }
            break;
          case 'M':// DL (Delete Line)
            bPastEOL=false;
            cursorX=0;
            if(cursorY>=windowTop && cursorY<=windowBottom){
              [self shiftLines:(0<nparams && params[0]>1)?params[0]:1
               fromY:cursorY toY:windowBottom];
            }
            break;
          case '@':// ICH (Insert Character)
            opt=1;
          case 'P':{// DCH (Delete Character)
            bPastEOL=false;
            j=(0<params && (i=params[0])>1)?i:1;
            i=screenWidth-cursorX;
            if(j>i){j=i;}
            screen_char_t* ptr=currentLine->buf+cursorX;
            memmove(opt?ptr+j:ptr,opt?ptr:ptr+j,(i-j)*sizeof(screen_char_t));
            if(!opt){ptr+=i-j;}
            screen_char_t* end=ptr+j;
            while(ptr<end){*(ptr++)=nullChar;}
            [self changedLineAtIndex:currentIndex];
            break;
          }
          case 'S':// SU (Scroll Up)
            [self shiftLines:(0<nparams && params[0]>1)?params[0]:1
             fromY:windowTop toY:windowBottom];
            break;
          case 'T':// SD (Scroll Down)
            [self shiftLines:(0<nparams && params[0]>1)?params[0]:1
             fromY:windowBottom toY:windowTop];
            break;
          case 'X':// ECH (Erase Character)
            bPastEOL=false;
            j=cursorX+((0<nparams && params[0]>1)?params[0]:1);
            if(j>screenWidth){j=screenWidth;}
            for (i=cursorX;i<j;i++){currentLine->buf[i]=nullChar;}
            [self changedLineAtIndex:currentIndex];
            break;
          case 'Z':// CBT (Cursor Backward Tabulation)
            bPastEOL=false;
            j=(0<nparams && params[0]>1)?params[0]:1;
            while(cursorX>0 && (!tabstops[--cursorX] || --j>0));
            break;
          case 'c':// DA (Device Attributes)
            [output appendBytes:VT100_DA length:strlen(VT100_DA)];
            break;
          case 'g':// TBC (Tabulation Clear)
            switch((0<nparams)?params[0]:0){
              case 0:// clear tab stop at current position
                tabstops[cursorX]=false;
                break;
              case 3:// clear all tab stops
                memset(tabstops,false,tabstops_size);
                break;
            }
            break;
          case 'h':// SM (Set Mode)
            opt=1;
          case 'l':// RM (Reset Mode)
            for (i=0;i<nparams;i++){
              switch(params[i]){
                case 4:bIRM=opt;break;
                case 20:bLNM=opt;break;
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
                case 1:nullChar.weight=kFontWeightBold;break;
                case 2:nullChar.weight=kFontWeightFaint;break;
                case 3:nullChar.italicize=true;break;
                case 4:nullChar.underline=kUnderlineSingle;break;
                case 5:nullChar.blink=true;break;
                case 7:nullChar.inverse=true;break;
                case 8:nullChar.hidden=true;break;
                case 9:nullChar.strikethrough=true;break;
                case 21:nullChar.underline=kUnderlineDouble;break;
                case 22:nullChar.weight=kFontWeightNormal;break;
                case 23:nullChar.italicize=false;break;
                case 24:nullChar.underline=kUnderlineNone;break;
                case 25:nullChar.blink=false;break;
                case 27:nullChar.inverse=false;break;
                case 28:nullChar.hidden=false;break;
                case 29:nullChar.strikethrough=false;break;
                case 38:
                  if(i+1<nparams){
                    switch(params[++i]){
                      case 2:
                        if(i+3<nparams){i+=3;}//! RGB
                        break;
                      case 5:
                        if(i+1<nparams){
                          nullChar.fgcolor_isset=true;
                          nullChar.fgcolor=params[++i];
                        }
                        break;
                    }
                  }
                  break;
                case 39:nullChar.fgcolor_isset=false;break;
                case 48:
                  if(i+1<nparams){
                    switch(params[++i]){
                      case 2:
                        if(i+3<nparams){i+=3;}//! RGB
                        break;
                      case 5:
                        if(i+1<nparams){
                          nullChar.bgcolor_isset=true;
                          nullChar.bgcolor=params[++i];
                        }
                        break;
                    }
                  }
                  break;
                case 49:nullChar.bgcolor_isset=false;break;
                default:
                  if(arg>=30 && arg<=37){
                    nullChar.fgcolor_isset=true;
                    nullChar.fgcolor=arg-30;
                  }
                  else if(arg>=40 && arg<=47){
                    nullChar.bgcolor_isset=true;
                    nullChar.bgcolor=arg-40;
                  }
                  else if(arg>=90 && arg<=97){
                    nullChar.fgcolor_isset=true;
                    nullChar.fgcolor=arg-90+8;
                  }
                  else if(arg>=100 && arg<=107){
                    nullChar.bgcolor_isset=true;
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
                char* msg;
                int len=asprintf(&msg,VT100_CPR,
                 cursorY+1-(bDECOM?windowTop:0),cursorX+1);
                if(len>0){[output appendBytes:msg length:len];}
                if(len!=-1){free(msg);}
                break;
              }
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
              bPastEOL=false;
              cursorX=0;
              j=bDECOM?windowTop:0;
              if(cursorY!=j){
                cursorY=j;
                [self updateCurrentLine];
              }
            }
            break;
          case 't':break;//! Manipulate window
          case 'x':// DECREQTPARM (Request Terminal Parameters)
            switch((0<nparams)?params[0]:0){
              case 0:
                [output appendBytes:VT100_DECREPTPARM0
                 length:strlen(VT100_DECREPTPARM0)];
                break;
              case 1:
                [output appendBytes:VT100_DECREPTPARM1
                 length:strlen(VT100_DECREPTPARM1)];
                break;
            }
            break;
          case 'y':break;//! DECTST (Invoke Confidence Test)
          case '$':case '&':case '\'':sequence=kSequenceSkipEnd;
        }
      }
      free(params);
      CSIModifier=kCSIModifierUndef;
    }
    else if(sequence==kSequenceDEC){
      sequence=kSequenceNone;
      switch(*inputptr){
        case '3':break;//! DECDHL (Double Height Line, top half)
        case '4':break;//! DECDHL (Double Height Line, bottom half)
        case '5':break;//! DECSWL (Single Width Line)
        case '6':break;//! DECDWL (Double Width Line)
        case '8':{// DECALN (Screen Alignment Test)
          CFIndex count=CFArrayGetCount(lineBuffer);
          screen_char_t E={.c='E'};
          for (i=count-screenHeight;i<count;i++){
            screen_line_t* line=(screen_line_t*)
             CFArrayGetValueAtIndex(lineBuffer,i);
            for (j=0;j<screenWidth;j++){line->buf[j]=E;}
            [self changedLineAtIndex:i];
          }
          bPastEOL=false;
          cursorX=cursorY=0;
          [self updateCurrentLine];
          break;
        }
      }
    }
    else if(sequence==kSequenceSCS){
      sequence=kSequenceNone;
      charsets[SCSIndex]=*inputptr;
    }
    else if(sequence==kSequenceSkipEnd){
      sequence=kSequenceNone;
    }
    else {// this is a printable character
      unichar uc;
      if(*inputptr<0x80){
        switch(charsets[glCharset]){
          case '0':uc=charmap_graphics[*inputptr];break;
          default:uc=*inputptr;break;
        }
      }
      else {
        CFStringRef str;
        if(encbuf){
          encbuf[encbuf_index++]=*inputptr;
          str=CFStringCreateWithBytesNoCopy(NULL,
           encbuf,encbuf_index,encoding,false,kCFAllocatorNull);
          if(str || encbuf_index==encbuf_size){encbuf_index=0;}
        }
        else {
          str=CFStringCreateWithBytesNoCopy(NULL,
           inputptr,1,encoding,false,kCFAllocatorNull);
        }
        if(!str){continue;}
        uc=CFStringGetCharacterAtIndex(str,0);
        CFRelease(str);
        // skip zero-width characters
        if(uc==0x200b || uc==0x200c || uc==0x200d || uc==0xfeff){continue;}
      }
      Boolean wrapped=false;
      if(bPastEOL){
        // either auto-wrap or discard this character
        if(!bDECAWM){continue;}
        [self changedLineAtIndex:currentIndex];
        [self nextLine];
        bPastEOL=false;
        cursorX=0;
        wrapped=true;
      }
      else if(bIRM && cursorX<screenWidth-1){
        // insert mode: shift characters to the right
        screen_char_t* ptr=currentLine->buf+cursorX;
        memmove(ptr+1,ptr,(screenWidth-cursorX)*sizeof(screen_char_t));
      }
      currentLine->buf[cursorX]=nullChar;
      currentLine->buf[cursorX].c=uc;
      if(wrapped){currentLine->buf[cursorX].wrapped=true;}
      [self changedLineAtIndex:currentIndex];
      if(cursorX<screenWidth-1){cursorX++;}
      else {bPastEOL=true;}
    }
  }
}
-(void)setEncoding:(CFStringEncoding)_encoding {
  if(encoding!=_encoding){
    encoding=_encoding;
    // allocate a backlog for multi-byte characters
    if(encbuf){free(encbuf);}
    CFIndex size=CFStringGetMaximumSizeForEncoding(1,encoding);
    if((encbuf=(size>1)?malloc(size):NULL)){
      encbuf_size=size;
      encbuf_index=0;
    }
  }
}
-(void)setWidth:(CFIndex)newWidth height:(CFIndex)newHeight {
  if(newWidth==screenWidth && newHeight==screenHeight){return;}
  if(newWidth<4){newWidth=4;}
  if(newHeight<2){newHeight=2;}
  CFIndex count=CFArrayGetCount(lineBuffer),i;
  // remove lines from the bottom if newHeight<screenHeight
  CFIndex iend=(cursorY>newHeight-1)?cursorY:newHeight-1;
  for (i=screenHeight-1;i>iend;i--){
    CFArrayRemoveValueAtIndex(lineBuffer,--count);
  }
  size_t newlinesize=newWidth*sizeof(screen_char_t);
  if(newWidth>screenWidth){
    // resize tab stop array
    if(newWidth>tabstops_size){
      tabstops=realloc(tabstops,newWidth);
      for (i=tabstops_size;i<newWidth;i++){tabstops[i]=((i%TAB_WIDTH)==0);}
      tabstops_size=newWidth;
    }
    // resize lines to at least newWidth
    for (i=0;i<count;i++){
      screen_line_t* line=(screen_line_t*)CFArrayGetValueAtIndex(lineBuffer,i);
      if(line->size<newlinesize){
        screen_line_t* newline=screen_line_create(newlinesize);
        memcpy(newline->buf,line->buf,line->size);
        CFArraySetValueAtIndex(lineBuffer,i,newline);
        screen_line_release(NULL,newline);
      }
    }
  }
  if(newHeight>screenHeight){
    CFIndex nlines=(count<newHeight)?newHeight-count:0;
    cursorY+=newHeight-screenHeight-nlines;
    for (i=0;i<nlines;i++){
      screen_line_t* newline=screen_line_create(newlinesize);
      CFArrayAppendValue(lineBuffer,newline);
      screen_line_release(NULL,newline);
    }
  }
  bPastEOL=false;
  bRedrawAll=true;
  if(cursorX>newWidth-1){cursorX=newWidth-1;}
  if(cursorY>newHeight-1){cursorY=newHeight-1;}
  if(windowTop>newHeight-1){windowTop=newHeight-1;}
  if(windowBottom==screenHeight-1 || windowBottom>newHeight-1)
    windowBottom=newHeight-1;
  screenWidth=newWidth;
  screenHeight=newHeight;
  [self updateCurrentLine];
}
-(void)dealloc {
  CFRelease(CSIParams);
  if(encbuf){free(encbuf);}
  CFRelease(lineBuffer);
  if(swapLineBuffer){CFRelease(swapLineBuffer);}
  free(tabstops);
  CFRelease(indexMap);
  CFRelease(linesChanged);
  [super dealloc];
}
@end

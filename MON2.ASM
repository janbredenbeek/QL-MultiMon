*MULTIMON
*DISASSEMBLY ROUTINES

          SECTION   MON_CODE

          XREF.S    BASE_PNT
          XREF.S    TOP_PNT
          XREF.S    DISBUFLEN
          XREF.S    DISMOD
          XREF.S    WRKSPOV
          XREF.S    RELMOD
          XREF.S    DATATBL
          XREF.S    LBL_TBL
          XREF.S    WRKSPTR
          XREF.S    WRK_END
          XREF.S    DISFRST
          XREF.S    DISLAST
          XREF.S    DISBUF
          XREF.S    LBL_FLD
          XREF.S    MNFIELD
          XREF.S    OPR_FLD

          XDEF      DISASSEM
          XDEF      CN_ADDR
          XDEF      CN_HEXB
          XDEF      CN_HEXL
          XDEF      ADD_WRK

          DATA      0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
ADD_WRK   MOVE.L    WRKSPTR(A6),A1
          CMPA.L    WRK_END(A6),A1
          BGE.S     WRKSP_ERR
          MOVE.L    D1,(A1)+
          MOVE.L    A1,WRKSPTR(A6)
          RTS

WRKSP_ERR ST        WRKSPOV(A6)
          RTS

*--------------------------------------------------------------------
* Signed byte to Hexadecimal.
*--------------------------------------------------------------------
BTOHEXS   TST.B     D1              ; Test sign
          BPL.S     BTOHEX          ; Skip  if positive
          MOVE.B    #'-',(A0)+      ; Must be negative
          NEG.B     D1              ; ABS(D1)
BTOHEX    MOVE.B    #'$',(A0)+      ; Indicate Hexadecimal
          BRA.S     CN_HEXB         ; Convert Byte to Hexadecimal

*--------------------------------------------------------------------
* Signed word to Hexadecimal.
*--------------------------------------------------------------------
WTOHEXS   TST.W     D1              ; Test sign
          BPL.S     WTOHEX          ; Skip if positive
          MOVE.B    #'-',(A0)+      ; Must be negative
          NEG.W     D1              ; ABS(D1)
WTOHEX    MOVE.B    #'$',(A0)+      ; Indicate Hexadecimal
          BRA.S     CN_HEXW         ; Convert word to Hexadecimal

*--------------------------------------------------------------------
* Long to Hexadecimal - assumed always positive?
*--------------------------------------------------------------------
LTOHEX    MOVE.B    #'$',(A0)+      ; Indicate Hexadecimal
          BRA.S     CN_HEXL         ; Convert long word to Hexadecimal

*--------------------------------------------------------------------
* Convert an address to 5, yes 5, Hexadecimal digits. See readme file
* for why this is, and how it might be updated to cover modern QL
* memory sizes, emulators etc.
*--------------------------------------------------------------------
CN_ADDR   MOVEQ     #5,D0           ; Only 5 digits permitted
          TST.B     RELMOD(A6)      ; Relative mode?
          BEQ.S     CN_HEX          ; No, just do the Hexadecimal address
          CMP.L     BASE_PNT(A6),D1 ; Yes, Adjust to a relative offset
          BCS.S     CN_HEX          ; but only if within the range of
          CMP.L     TOP_PNT(A6),D1  ; BASE_PNT to TOP_PNT.
          BCC.S     CN_HEX
          SUB.L     BASE_PNT(A6),D1 ; Make relative to BASE_PNT
          BRA.S     CN_HEX          ; Print 5 Hexadecimal digits

*--------------------------------------------------------------------
* Positive byte to Hexadecimal.
*--------------------------------------------------------------------
CN_HEXB   MOVEQ     #2,D0           ; Only 2 hex digits in a byte
          BRA.S     CN_HEX          ; Convert them

*--------------------------------------------------------------------
* Positive word to Hexadecimal.
*--------------------------------------------------------------------
CN_HEXW   MOVEQ     #4,D0           ; There are 4 hex digits in a word
          BRA.S     CN_HEX          ; Convert them

*--------------------------------------------------------------------
* Positive long word to Hexadecimal.
*--------------------------------------------------------------------
CN_HEXL   MOVEQ     #8,D0           ; There are 8 hex digits in a long


*--------------------------------------------------------------------
* Routine to convert D1.B.W.L to D0 Hexadecimal characters. For byte,
* word or long this is 2, 4 or 8 characters. For an address, only the
* lower 5 digits are converted. See the readme file & CN_ADDR above.
* The converted digits are stored in a buffer at (A0).
*--------------------------------------------------------------------
CN_HEX    MOVEM.L   D1-D3,-(A7)     ; Save workers
          MOVE.B    D0,D3           ; Counter of digits in D3.B
          ADDA.W    D0,A0           ; Point to END of buffer

*--------------------------------------------------------------------
* Work backwards in the buffer, converting the lowest byte of D1 as
* we go. Only D3.B characters are converted, or D3.B/2 bytes of the
* value in D1.B.W.L.
*--------------------------------------------------------------------
CN_LOOP   MOVEQ     #$0F,D2         ; Mask of one nibble
          AND.B     D1,D2           ; D2.B = Lowest nibble
          CMPI.B    #10,D2          ; Still a digit?
          BLT.S     CN_STORE        ; Yes, store the digit
          ADDQ.B    #7,D2           ; No, add offset to letters

CN_STORE  ADDI.B    #'0',D2         ; ASCIIfy the digit/letter
          MOVE.B    D2,-(A0)        ; And store in the buffer
          LSR.L     #4,D1           ; Ready the next highest nibble
          SUBQ.B    #1,D3           ; One less digit to convert
          BNE.S     CN_LOOP         ; Do another if more to do
          ADDA.W    D0,A0           ; A0 points to the final hex char
          MOVEM.L   (A7)+,D1-D3     ; Restore the workers
          RTS                       ; Done

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DEST_EA   MOVEQ     #7,D0
          MOVE.W    D7,D5
          ROL.W     D0,D5
          AND.W     D0,D5
          MOVE.W    D7,D6
          ROR.W     #6,D6
          AND.W     D0,D6
          TST.B     D4
          BNE.S     DEST_CMP
          CMPI.B    #1,D6
          BEQ.S     EA_ERROR
DEST_CMP  CMP.B     D0,D6
          BNE.S     EA_DEC_1
          ADD.B     D5,D6
          CMPI.B    #$09,D6
          BLT.S     EA_DEC_1
EA_ERROR  MOVE.B    #'?',(A0)+
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
GET_MR    MOVEQ     #$07,D5
          MOVEQ     #$38,D6
          AND.B     D7,D5
          AND.B     D7,D6
          LSR.B     #3,D6
          CMPI.B    #$07,D6
          BNE.S     L702DE
          ADD.B     D5,D6
L702DE    RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_DATA   BSR.S     GET_MR
          CMPI.B    #$01,D6
          BEQ.S     EA_ERROR
          BRA.S     EA_DEC_1

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_MALT   BSR.S     GET_MR
          CMPI.B    #$08,D6
          BGT.S     EA_ERROR
EA_MEM    BSR.S     GET_MR
          CMPI.B    #$02,D6
          BLT.S     EA_ERROR
          BRA.S     EA_DEC_1

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_CTRL   BSR.S     GET_MR
          CMPI.B    #$02,D6
          BEQ.S     EA_DEC_1
          CMPI.B    #$05,D6
          BLT.S     EA_ERROR
          CMPI.B    #$0A,D6
          BGT.S     EA_ERROR
          BRA.S     EA_DEC_1

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_DALT   BSR.S     GET_MR
          CMPI.B    #1,D6
          BEQ.S     EA_ERROR
EA_ALT    BSR.S     GET_MR
          CMPI.B    #8,D6
          BGT.S     EA_ERROR
          BRA.S     EA_DEC_1

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_DECODE BSR.S     GET_MR
EA_DEC_1  CMPI.B    #11,D6
          BHI.S     EA_ERROR
          LSL.W     #1,D6
          MOVE.W    EA_TABLE(PC,D6.W),A1
          JMP       EA_TABLE(PC,A1.W)

*--------------------------------------------------------------------
* Table of pointers to Effective Address decoding routines based on
* the mode of the Effective Address itself.
*--------------------------------------------------------------------
EA_TABLE  DC.W      EA_0-EA_TABLE
          DC.W      EA_1-EA_TABLE
          DC.W      EA_2-EA_TABLE
          DC.W      EA_3-EA_TABLE
          DC.W      EA_4-EA_TABLE
          DC.W      EA_5-EA_TABLE
          DC.W      EA_6-EA_TABLE
          DC.W      EA_7-EA_TABLE
          DC.W      EA_8-EA_TABLE
          DC.W      EA_9-EA_TABLE
          DC.W      EA_A-EA_TABLE
          DC.W      EA_B-EA_TABLE

*--------------------------------------------------------------------
* Decodes the size for the instruction and adds it to the buffer at
* (A0). D4.W holds the size to be converted.
*--------------------------------------------------------------------
GT_SIZE   MOVE.B    #'.',(A0)+      ; Buffer the dot
          MOVE.B    SIZETAB(PC,D4.W),(A0)+  ; Buffer the size letter
          LEA       OPR_FLD(A6),A0  ; Reset the buffer pointer
          RTS                       ; Done

*--------------------------------------------------------------------
* Table of instruction sizes indexed by D4.W from GT_SIZE above. 
*--------------------------------------------------------------------
SIZETAB   DC.B      'BWL',0

*--------------------------------------------------------------------
* Some instructions are not byte sized, so this deals with those that
* are only permitted to be word or long. The destination buffer is
* at (A0) and bit 6 of D7 holds the size indicator - 0 = Word, 1 =
* long.
*--------------------------------------------------------------------
SIZE_WL   MOVE.B    #'.',(A0)+      ; Buffer the dot
          MOVEQ     #'W',D0         ; Assume Word
          BTST      #6,D7           ; But check anyway
          BEQ.S     SWL_2           ; Yes, word skip
          MOVEQ     #'L',D0         ; Bad guess, must be long
SWL_2     MOVE.B    D0,(A0)+        ; Buffer the size letter
          LEA       OPR_FLD(A6),A0  ; Reset buffer pointer
          RTS                       ; Done

*--------------------------------------------------------------------
* Sets D5.B to be the register number for an Effective Address. This
* is done when there are two Effective Addresses to be worked out. 
* Bits 11-9 have the desired register number and this is rotated into
* bits 2-0 then masked to get the desired register number.
*--------------------------------------------------------------------
SECNDREG  MOVE.W    D7,D5           ; Copy instruction word to D5
          ROL.W     #7,D5           ; Shift bits 987 -> 210
          ANDI.B    #7,D5           ; Mask out register number

*--------------------------------------------------------------------
* EA Mode 0 - Data Register Direct.                                Dn
*--------------------------------------------------------------------
EA_0      MOVE.B    #'D',(A0)+      ; D for Data Register Direct
          BRA.S     ENTREGNR        ; Do the register number

*--------------------------------------------------------------------
* EA Mode 1 - Address Register Direct.                             An
*--------------------------------------------------------------------
EA_1      MOVE.B    #'A',(A0)+      ; A for Address Register Direct

*--------------------------------------------------------------------
* Add the register number which is held in D5.B.
*--------------------------------------------------------------------
ENTREGNR  ADDI.B    #'0',D5         ; ASCIIfy the register number
          MOVE.B    D5,(A0)+        ; Buffer it
          RTS                       ; Done

*--------------------------------------------------------------------
* EA Mode 4 - Address Register Indirect with Predecrement.      -(An)
*--------------------------------------------------------------------
EA_4      MOVE.B    #'-',(A0)+      ; Buffer the predecrement sign

*--------------------------------------------------------------------
* EA Mode 2 - Address Register Indirect.                         (An)
*--------------------------------------------------------------------
EA_2      MOVE.B    #'(',(A0)+      ; Buffer the bracket
          BSR.S     EA_1            ; Buffer the Address Register
          MOVE.B    #')',(A0)+      ; Close the bracket
          RTS                       ; Done

*--------------------------------------------------------------------
* EA Mode 3 - Address Register Indirect with Postincrement.     (An)+
*--------------------------------------------------------------------
EA_3      BSR.S     EA_2            ; Buffer the (An) register
          MOVE.B    #'+',(A0)+      ; Buffer the postincrement sign
          RTS                       ; Done

*--------------------------------------------------------------------
* EA Mode 5 - Address Register Indirect with Displacement.     nn(An)
*--------------------------------------------------------------------
EA_5      JSR       ADV_W           ; Get the displacement word
          JSR       WTOHEXS         ; Buffer signed hexadecimal word
          BRA.S     EA_2            ; And the indirect address register

*--------------------------------------------------------------------
* EA Mode 6 - Address Register Indirect with Index.         nn(An,Rn)
*--------------------------------------------------------------------
EA_6      JSR       ADV_W           ; Get the displacement word
          JSR       BTOHEXS         ; Buffer signed hexadecimal byte 
          MOVE.B    #'(',(A0)+      ; Buffer the opening bracket
          BSR.S     EA_1            ; Buffer the Address register
          MOVE.B    #',',(A0)+      ; The comma
          BRA.S     EA_INDEX        ; The index register

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_7      JSR       ADV_W           ; Get the displacement word
          EXT.L     D1              ; Make it long, sign extended
          BRA.S     EA_ADDR         ; Skip

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_8      JSR       ADV_L           ; Get the displacement long word
          BRA.S     EA_ADDR         ; Skip

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_9      MOVE.L    A4,A1           ; ????
          JSR       ADV_W           ; Get the displacement word

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_9A     EXT.L     D1              ; Sign extended to long word
          ADD.L     A1,D1

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_ADDR   MOVEQ     #'$',D0
          TST.B     DISMOD(A6)
          BLT.S     EA_BP
          CMP.L     DISFRST(A6),D1
          BCS.S     ST_LABEL
          CMP.L     DISLAST(A6),D1
          BHI.S     ST_LABEL
          MOVEQ     #'L',D0
          TST.B     DISMOD(A6)
          BGT.S     ST_LABEL
          MOVE.L    LBL_TBL(A6),A1
EA_A_LP   CMPA.L    WRKSPTR(A6),A1
          BGE.S     NEW_LABEL
          CMP.L     (A1)+,D1
          BNE.S     EA_A_LP
          BRA.S     ST_LABEL
NEW_LABEL JSR       ADD_WRK
ST_LABEL  MOVE.B    D0,(A0)+
          JMP       CN_ADDR

*--------------------------------------------------------------------
* Bad parameter in working out an effective address. Oops!
*--------------------------------------------------------------------
EA_BP     MOVE.L    D1,D2
          BSR.S     ST_LABEL
          CMP.L     D1,D2
          BEQ.S     EA_BP_EN
          LEA       BPMSG,A1
          JSR       COPY_LP
EA_BP_EN  RTS

*--------------------------------------------------------------------
* Message to display when disassembling an instruction which has a
* dubious effective address.
*--------------------------------------------------------------------
BPMSG     DC.B      '(BP)',0,0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_A      JSR       ADV_W           ; Get the displacement word
          MOVE.W    D1,-(A7)        ; Save worker
          EXT.W     D1              ; Sign extend D1 to word
          EXT.L     D1              ; Then to long word
          ADD.L     A4,D1           ; ????
          SUBQ.L    #2,D1           
          BSR.S     EA_ADDR
          MOVE.W    (A7)+,D1        ; Restore worker
          MOVE.B    #'(',(A0)+      ; Buffer a bracket

*--------------------------------------------------------------------
* Buffers the index register in those Effective Addresses that have
* one - for example, called from EA Mode 6 above.
*--------------------------------------------------------------------
EA_INDEX  MOVEQ     #'D',D0         ; Assumes a Data index register
          TST.W     D1              ; Correct?
          BPL.S     INDEXREG        ; Yes, skip
          MOVEQ     #'A',D0         ; Bad guess, it was an address

INDEXREG  MOVE.B    D0,(A0)+        ; Buffer the index register type
          ROL.W     #4,D1           ; Get the register number
          ANDI.B    #7,D1           ; Mask it out
          ADDI.B    #'0',D1         ; ASCIIIfy it
          MOVE.B    D1,(A0)+        ; Buffer the index register number
          MOVE.B    #'.',(A0)+      ; And a dot
          MOVEQ     #'W',D0         ; Assume Word sized index register
          TST.W     D1              ; Check anyway
          BPL.S     INDXSIZE        ; Correct, skip
          MOVEQ     #'L',D0         ; Bad guess, it was long sized
INDXSIZE  MOVE.B    D0,(A0)+        ; Buffer the size letter
          MOVE.B    #')',(A0)+      ; And close the brackets
          RTS                       ; Done.

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EA_B      BSR.S     ADVANCE
          MOVE.B    #'#',(A0)+
          MOVE.B    D4,D0
          BEQ       BTOHEX
          SUBQ.B    #1,D0
          BEQ       WTOHEX
          BRA       LTOHEX

*--------------------------------------------------------------------
*--------------------------------------------------------------------
ALIGN     MOVE.L    A4,D0
          ADDQ.L    #1,D0
          BCLR      #0,D0
          MOVE.L    D0,A4
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
ADVANCE   CMPI.B    #2,D4
          BEQ.S     ADV_L
          MOVEQ     #0,D1
ADV_W     BSR       ALIGN
          MOVE.W    (A4)+,D1
          MOVEQ     #4,D0
          BRA.S     ADV_2
ADV_L     BSR       ALIGN
          MOVE.L    (A4)+,D1
          MOVEQ     #8,D0
ADV_2     EXG       A0,A5
          JSR       CN_HEX
          EXG       A0,A5
COPY_END  RTS

*--------------------------------------------------------------------
* Code to scan through the current (list of) instructions at (A1)
* Looking for the entry in the list following the next CHR$(0).
* All entries are zero terminated.
* D1.W Holds the actual entry in the list that we want to extract.
*--------------------------------------------------------------------
NXTENTRY  TST.B     (A1)+
          BNE.S     NXTENTRY
DIS_INDEX DBF       D1,NXTENTRY

*--------------------------------------------------------------------
* Copy an entry from a list of zero terminated strings to the buffer
* in (A0). The list is at (A1). 
*--------------------------------------------------------------------
COPY_LP   MOVE.B    (A1)+,D0
          BEQ.S     COPY_END
          MOVE.B    D0,(A0)+
          BRA.S     COPY_LP

*--------------------------------------------------------------------
*--------------------------------------------------------------------
CONDITION MOVE.W    D7,D1
          ANDI.W    #$0F00,D1
          LSR.W     #7,D1
          MOVE.B    0(A1,D1.W),(A0)+
          MOVE.B    1(A1,D1.W),(A0)+
          RTS

*--------------------------------------------------------------------
* Condition codes table. Two bytes for each condition code. DBRA is
* actually DBF in this table.
*--------------------------------------------------------------------
CONDTAB1  DC.B      'T F HILSCCCSNEEQVCVSPLMIGELTGTLE'

*--------------------------------------------------------------------
* More condition codes. These are for BRA, BSR and the rest are the 
* Bcc codes.
*--------------------------------------------------------------------
CONDTAB2  DC.B      'RASRHILSCCCSNEEQVCVSPLMIGELTGTLE'

*--------------------------------------------------------------------
*--------------------------------------------------------------------
FIND_LBL  MOVE.L    LBL_TBL(A6),A1
FINDLBL2  CMPA.L    WRKSPTR(A6),A1
          BGE.S     LBL_NOTF
          CMPA.L    (A1)+,A4
          BNE.S     FINDLBL2
          RTS

*--------------------------------------------------------------------
* NOT FOUND (-7) Error return.
*--------------------------------------------------------------------
LBL_NOTF  MOVEQ     #-7,D0
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DISASSEM  LEA       DISBUF(A6),A0
          MOVE.L    A0,A1
          MOVEQ     #$20,D1
          MOVEQ     #DISBUFLEN-1,D0
CLRDISBUF MOVE.B    D1,(A1)+
          DBF       D0,CLRDISBUF
          MOVE.L    A4,D1
          JSR       CN_ADDR
          LEA       1(A0),A5
          TST.B     DISMOD(A6)
          BLE.S     TAB_MNEM
          BSR.S     FIND_LBL
          BNE.S     TAB_MNEM
          LEA       LBL_FLD(A6),A0
          MOVE.B    #'L',(A0)+
          MOVE.L    A4,D1
          JSR       CN_ADDR
TAB_MNEM  LEA       MNFIELD(A6),A0
          TST.B     DISMOD(A6)
          BLT       DIS_INST
          MOVE.L    DATATBL(A6),A1
DATA_LOOP CMPA.L    LBL_TBL(A6),A1
          BGE       DIS_INST
          MOVE.L    (A1)+,D6
          MOVE.L    (A1)+,D7
          MOVE.L    D6,D1
          ANDI.L    #$00FFFFFF,D1
          CMPA.L    D1,A4
          BCS.S     DATA_LOOP
          CMPA.L    D7,A4
          BHI.S     DATA_LOOP
          MOVE.B    #'D',(A0)+
          MOVE.B    #'C',(A0)+
          ROL.L     #8,D6
          MOVE.B    D6,D4
          EXT.W     D4
          ADDQ.W    #1,D4
          JSR       GT_SIZE
          TST.B     D6
          BEQ.S     DATA_WORD
          BGT.S     DATA_LONG
          MOVEQ     #3,D5
          BRA.S     BYTE_ENT
BYTE_LOOP MOVE.B    #',',(A0)+
BYTE_ENT  MOVE.B    (A4)+,D1
          EXG       A0,A5
          JSR       CN_HEXB
          EXG       A0,A5
          CMPI.B    #$20,D1
          BCS.S     B_HEX
          CMPI.B    #$7F,D1
          BCC.S     B_HEX
          MOVEQ     #$27,D0
          MOVE.B    D0,(A0)+
          MOVE.B    D1,(A0)+
          MOVE.B    D0,(A0)+
          BRA.S     B_NEXT
B_HEX     JSR       BTOHEX
B_NEXT    CMPA.L    D7,A4
          BHI.S     B_END
          BSR       FIND_LBL
          DBEQ      D5,BYTE_LOOP
B_END     RTS

DATA_WORD JSR       ADV_W
          JSR       WTOHEX
          CMPA.L    D7,A4
          BHI.S     B_END
          BSR       FIND_LBL
          BEQ.S     B_END
          MOVEQ     #0,D7
          MOVE.B    #',',(A0)+
          BRA.S     DATA_WORD
DATA_LONG JSR       ADV_L
          JMP       LTOHEX

DIS_INST  JSR       ADV_W
          MOVE.W    D1,D7
          MOVEQ     #0,D4
          MOVE.B    D1,D4
          LSR.B     #6,D4
          ANDI.W    #$F000,D1
          ROL.W     #5,D1
          MOVE.W    LINETAB(PC,D1.W),D1
          JMP       LINETAB(PC,D1.W)

LINETAB   DC.W      LINE0-LINETAB
          DC.W      LINE1-LINETAB
          DC.W      LINE2-LINETAB
          DC.W      LINE3-LINETAB
          DC.W      LINE4-LINETAB
          DC.W      LINE5-LINETAB
          DC.W      LINE6-LINETAB
          DC.W      LINE7-LINETAB
          DC.W      LINE8-LINETAB
          DC.W      LINE9-LINETAB
          DC.W      ILL_INST-LINETAB
          DC.W      LINEB-LINETAB
          DC.W      LINEC-LINETAB
          DC.W      LINED-LINETAB
          DC.W      LINEE-LINETAB
          DC.W      ILL_INST-LINETAB

ILL_INST  LEA       MN_ILL,A1
          JMP       COPY_LP

LINE0     LEA       MN_LINE0,A1
          MOVE.W    D7,D1
          ANDI.W    #$0E00,D1
          ROL.W     #7,D1
          BTST      #$08,D7
          BNE.S     TST_MOVEP
          CMPI.B    #$04,D1
          BEQ.S     BIT_MAN
          CMPI.B    #$07,D1
          BEQ.S     ILL_INST
          CMPI.B    #$03,D4
          BEQ.S     ILL_INST
          MOVE.W    D1,D2
          JSR       DIS_INDEX
          MOVEQ     #$3F,D1
          AND.B     D7,D1
          CMPI.B    #$3C,D1
          BNE.S     L0_IMM
          SUBQ.B    #2,D2
          BMI.S     L70672
          SUBQ.B    #3,D2
          BNE.S     L0_IMM
L70672    LEA       OPR_FLD(A6),A0
          JSR       EA_B
          MOVE.B    #$2C,(A0)+
          MOVE.W    D4,D1
          LEA       MN_SRCCR,A1
          JMP       DIS_INDEX

L0_IMM    JSR       GT_SIZE
          JSR       EA_B
          MOVE.B    #',',(A0)+
          JMP       EA_DALT

TST_MOVEP JSR       GET_MR
          SUBQ.B    #1,D6
          BEQ.S     D_MOVEP
BIT_MAN   MOVE.W    D4,D1
          LEA       MN_BIT,A1
          JSR       DIS_INDEX
          LEA       OPR_FLD(A6),A0
          BTST      #8,D7
          BEQ.S     BIT_IMM
          JSR       SECNDREG
          BRA.S     L0_COMMA
BIT_IMM   MOVE.B    #'#',(A0)+
          JSR       ADV_W
          JSR       BTOHEX
L0_COMMA  MOVE.B    #',',(A0)+
          TST.B     D4
          BEQ       EA_DATA
          JMP       EA_DALT

D_MOVEP   LEA       MN_MOVEP,A1
          JSR       COPY_LP
          JSR       SIZE_WL
          TST.B     D7
          BMI.S     MOVEP_2
          JSR       EA_5
          MOVE.B    #',',(A0)+
          JMP       SECNDREG

MOVEP_2   JSR       SECNDREG
          MOVE.B    #',',(A0)+
          MOVEQ     #7,D5
          AND.B     D7,D5
          JMP       EA_5

LINE1     MOVEQ     #0,D4
          BRA.S     D_MOVE
LINE2     MOVEQ     #2,D4
          BRA.S     D_MOVE
LINE3     MOVEQ     #1,D4
D_MOVE    LEA       MN_MOVE,A1
          JSR       COPY_LP
          JSR       GT_SIZE
          TST.B     D4
          BNE.S     MOVE_WL
          JSR       EA_DATA
          BRA.S     MOVE_2
MOVE_WL   JSR       EA_DECODE
MOVE_2    MOVE.B    #',',(A0)+
          JMP       DEST_EA

LINE4     BTST      #8,D7
          BEQ.S     L4_MISC
          TST.B     D7
          BPL       ILL_INST
          MOVEQ     #1,D1
          AND.B     D4,D1
          LEA       MN_CHKLEA,A1
          JSR       DIS_INDEX
          LEA       OPR_FLD(A6),A0
          LSR.B     #1,D4
          BCS.S     D_LEA
          JSR       EA_DATA
          MOVE.B    #',',(A0)+
          JMP       SECNDREG

D_LEA     JSR       EA_CTRL
          BRA       SECND_ADD
L4_MISC   MOVE.W    D7,D1
          ANDI.W    #$0600,D1
          ROL.W     #7,D1
          BTST      #11,D7
          BNE.S     L4_2
          CMPI.B    #3,D4
          BEQ.S     MOVE_SR
          LEA       MN_4_1,A1
          JSR       DIS_INDEX
          JSR       GT_SIZE
          JMP       EA_DALT

MOVE_SR   SUBQ.B    #1,D1
          BEQ       ILL_INST
          LEA       MN_MOVE,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          SUBQ.B    #1,D1
          BPL.S     TO_SR
          LEA       MN_SRCCR,A1
          MOVEQ     #1,D1
          JSR       DIS_INDEX
          MOVE.B    #',',(A0)+
          JMP       EA_DALT

TO_SR     MOVE.W    D1,D4
          JSR       EA_DATA
          MOVE.B    #',',(A0)+
          MOVE.W    D4,D1
          LEA       MN_SRCCR,A1
          JMP       DIS_INDEX

L4_2      SUBQ.B    #1,D1
          BEQ       D_TST
          BGT       D_MOVEM2
          SUBQ.B    #1,D4
          BEQ.S     SWAP_PEA
          BGT.S     EXT_MOVEM
          LEA       MN_NBCD,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          JMP       EA_DALT

SWAP_PEA  MOVEQ     #$38,D0
          AND.B     D7,D0
          BNE.S     D_PEA
          LEA       MN_SWAP,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          JMP       EA_DECODE
D_PEA     LEA       MN_PEA,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          JMP       EA_CTRL

EXT_MOVEM JSR       GET_MR
          LEA       MN_EXT,A1
          TST.B     D6
          BEQ.S     D_EXT
          LEA       MN_MOVEM,A1
D_EXT     JSR       COPY_LP
          JSR       SIZE_WL
          TST.B     D6
          BEQ       EA_0
          JSR       ADV_W
          CMPI.B    #4,D6
          BNE.S     D_MOVEM1
          MOVE.W    D1,D2
          MOVEQ     #15,D0
REV_LOOP  LSR.W     #1,D2
          ROXL.W    #1,D1
REV_2     DBF       D0,REV_LOOP
D_MOVEM1  BSR       REGLIST
          MOVE.B    #',',(A0)+
          CMPI.B    #2,D6
          BEQ.S     D_MOVEM3
          CMPI.B    #4,D6
          BLT       EA_ERROR
          CMPI.B    #8,D6
          BGT       EA_ERROR
D_MOVEM3  JMP       EA_DECODE

D_TST     LEA       MN_ILLEG,A1
          CMPI.B    #$FC,D7
          BEQ       COPY_LP
          CMPI.B    #3,D4
          BEQ.S     D_TAS
          LEA       MN_TST,A1
          JSR       COPY_LP
          JSR       GT_SIZE
          JMP       EA_DALT

D_TAS     LEA       MN_TAS,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          JMP       EA_DALT

D_MOVEM2  SUBQ.B    #1,D1
          BNE       L4_E
          TST.B     D7
          BPL       ILL_INST
          LEA       MN_MOVEM,A1
          JSR       COPY_LP
          JSR       SIZE_WL
          JSR       ADV_W
          MOVE.W    D1,D4
          JSR       GET_MR
          CMPI.B    #2,D6
          BLT.S     MOVEM_ER
          CMPI.B    #4,D6
          BEQ.S     MOVEM_ER
          CMPI.B    #10,D6
          BGT.S     MOVEM_ER
          JSR       EA_DECODE
          BRA.S     D_MOVEM4
MOVEM_ER  JSR       EA_ERROR
D_MOVEM4  MOVE.B    #',',(A0)+
          MOVE.W    D4,D1
REGLIST   MOVEQ     #0,D0
          MOVEQ     #'D',D2
          TST.B     D1
          BEQ.S     RL_A
          BSR.S     REGLIST1
          TST.W     D1
          BEQ.S     RL_END
          MOVE.B    #'/',(A0)+
RL_A      MOVEQ     #'A',D2
          LSR.W     #8,D1
REGLIST1  MOVEQ     #'0',D3
RL_LP1    BTST      D0,D1
          BNE.S     RL_SET
          ADDQ.B    #1,D3
          LSR.B     #1,D1
          BNE.S     RL_LP1
RL_END    RTS

RL_SET    MOVE.B    D2,(A0)+
          MOVE.B    D3,(A0)+
          LSR.B     #1,D1
          BTST      D0,D1
          BEQ.S     RL_NEXT
          MOVE.B    #'-',(A0)+
RL_LP2    ADDQ.B    #1,D3
          LSR.B     #1,D1
          BTST      D0,D1
          BNE.S     RL_LP2
          MOVE.B    D2,(A0)+
          MOVE.B    D3,(A0)+
RL_NEXT   TST.B     D1
          BEQ.S     RL_END
          MOVE.B    #'/',(A0)+
          ADDQ.B    #1,D3
          BRA.S     RL_LP1
L4_E      MOVE.B    D7,D1
          LSR.B     #4,D1
          SUBQ.B    #4,D1
          BLT       ILL_INST
          BNE.S     D_LINK
          LEA       MN_TRAP,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          MOVE.B    #'#',(A0)+
          MOVEQ     #$0F,D1
          AND.B     D7,D1
          JMP       BTOHEX

D_LINK    SUBQ.B    #1,D1
          BNE.S     MOVE_USP
          LEA       MN_LINK,A1
          BTST      #3,D7
          BEQ.S     D_UNLK
          LEA       MN_UNLK,A1
D_UNLK    JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          BSR.S     ADDREG
          BTST      #3,D7
          BEQ.S     LINK_DSP
          RTS

LINK_DSP  MOVE.B    #',',(A0)+
          MOVE.B    #'#',(A0)+
          JSR       ADV_W
          JMP       WTOHEXS

MOVE_USP  SUBQ.B    #1,D1
          BNE.S     D_4E7X
          LEA       MN_MOVE,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          BTST      #$03,D7
          BNE.S     L709A2
          BSR.S     ADDREG
          MOVE.B    #$2C,(A0)+
COPY_USP  LEA       MN_USP,A1
          JMP       COPY_LP

L709A2    BSR.S     COPY_USP
          MOVE.B    #$2C,(A0)+
ADDREG    MOVEQ     #$07,D5
          AND.B     D7,D5
          JMP       EA_1

D_4E7X    TST.B     D7
          BMI.S     L709DA
          MOVEQ     #$0F,D1
          AND.B     D7,D1
          MOVE.B    D1,D2
          CMPI.B    #$07,D2
          BGT       ILL_INST
          CMPI.B    #$04,D2
          BEQ       ILL_INST
          LEA       MN_4E7X,A1
          JSR       DIS_INDEX
          SUBQ.B    #2,D2
          BNE.S     L709D8
          LEA       OPR_FLD(A6),A0
          MOVEQ     #$01,D4
          JSR       EA_B
L709D8    RTS

L709DA    MOVEQ     #$01,D1
          AND.B     D4,D1
          LEA       MN_JSR,A1
          JSR       DIS_INDEX
          LEA       OPR_FLD(A6),A0
          JMP       EA_CTRL

QUICKDATA MOVE.B    #$23,(A0)+
          MOVE.W    D7,D1
          ANDI.W    #$0E00,D1
          ROL.W     #7,D1
          BNE.S     L709FE
          MOVEQ     #$08,D1
L709FE    ADDI.B    #$30,D1
          MOVE.B    D1,(A0)+
          MOVE.B    #$2C,(A0)+
          RTS

LINE5     CMPI.B    #$03,D4
          BEQ.S     L70A2C
          LEA       MN_ADDQ,A1
          BTST      #$08,D7
          BEQ.S     L70A1E
          LEA       MN_SUBQ,A1
L70A1E    JSR       COPY_LP
          JSR       GT_SIZE
          BSR.S     QUICKDATA
          JMP       EA_ALT

L70A2C    LEA       CONDTAB1,A1
          JSR       GET_MR
          SUBQ.B    #1,D6
          BNE.S     D_SCC
          MOVE.B    #'D',(A0)+
          MOVE.B    #'B',(A0)+
          JSR       CONDITION
          LEA       OPR_FLD(A6),A0
          JSR       EA_0
          MOVE.B    #',',(A0)+
          JMP       EA_9

D_SCC     MOVE.B    #'S',(A0)+
          JSR       CONDITION
          LEA       OPR_FLD(A6),A0
          JMP       EA_DALT

LINE6     MOVE.B    #'B',(A0)+
          LEA       CONDTAB2,A1
          JSR       CONDITION
          MOVE.B    D7,D1
          BEQ.S     BR_LONG
          MOVE.B    #'.',(A0)+
          MOVE.B    #'S',(A0)+
          LEA       OPR_FLD(A6),A0
          MOVE.L    A4,A1
          EXT.W     D1
          JMP       EA_9A

BR_LONG   LEA       OPR_FLD(A6),A0
          JMP       EA_9

LINE7     BTST      #8,D7
          BNE       ILL_INST
          LEA       MN_MOVEQ,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          MOVE.B    #'#',(A0)+
          MOVE.B    D7,D1
          JSR       BTOHEXS
          MOVE.B    #',',(A0)+
          JMP       SECNDREG

LINEC     LEA       MN_LINEC,A1
          MOVE.W    D7,D1
          ANDI.W    #$01F8,D1
          LSR.W     #3,D1
          SUBI.B    #$28,D1
          BEQ.S     EXG_DX
          SUBQ.B    #1,D1
          BEQ.S     EXG_AX
          SUBQ.B    #8,D1
          BNE.S     D_L8
EXG_DX    MOVEQ     #'D',D1
          BRA.S     DO_EXG
EXG_AX    MOVEQ     #'A',D1
DO_EXG    LEA       MN_EXG,A1
          JSR       COPY_LP
          LEA       OPR_FLD(A6),A0
          MOVE.B    D1,(A0)+
          MOVE.W    D7,D0
          ANDI.W    #$0E00,D0
          ROL.W     #7,D0
          ADDI.B    #'0',D0
          MOVE.B    D0,(A0)+
          MOVE.B    #',',(A0)+
          JMP       EA_DECODE

LINE8     LEA       MN_LINE8,A1
D_L8      CMPI.B    #3,D4
          BEQ.S     MUL_DIV
          MOVEQ     #2,D1
          BTST      #8,D7
          BEQ.S     OR_AND
          JSR       GET_MR
          CMPI.B    #2,D6
          BGE       SUB_DX
D_SBCD    MOVEQ     #3,D1
          JSR       DIS_INDEX
          LEA       OPR_FLD(A6),A0
DX_OR_MEM LEA       EA_0,A2
          TST.B     D6
          BEQ.S     SBCD_DATA
          LEA       EA_4,A2
SBCD_DATA JSR       (A2)
          MOVE.W    D7,D5
          ANDI.W    #$0E00,D5
          ROL.W     #7,D5
          MOVE.B    #',',(A0)+
          JMP       (A2)

MUL_DIV   MOVEQ     #0,D1
          MOVEQ     #1,D4
          BTST      #8,D7
          BEQ.S     MULU_DIVU
          MOVEQ     #1,D1
MULU_DIVU JSR       DIS_INDEX
          LEA       OPR_FLD(A6),A0
          BRA.S     OR_DIV
OR_AND    JSR       DIS_INDEX
          JSR       GT_SIZE
OR_DIV    JSR       EA_DATA
          MOVE.B    #',',(A0)+
          JMP       SECNDREG

LINE9     LEA       MN_LINE9,A1
          BRA.S     D_L9
LINED     LEA       MN_LINED,A1
D_L9      CMPI.B    #3,D4
          BEQ.S     D_SUBA
          MOVEQ     #1,D1
          BTST      #8,D7
          BEQ.S     SUB_MEM
          JSR       GET_MR
          CMP.B     D1,D6
          BGT.S     SUB_DX
          MOVEQ     #2,D1
          JSR       DIS_INDEX
          JSR       GT_SIZE
          BRA.S     DX_OR_MEM
D_SUBA    MOVEQ     #0,D1
          JSR       DIS_INDEX
          MOVEQ     #1,D4
          BTST      #8,D7
          BEQ.S     SUBA_SIZE
          MOVEQ     #2,D4
SUBA_SIZE JSR       GT_SIZE
          JSR       EA_DECODE
SECND_ADD MOVE.B    #',',(A0)+
          MOVE.W    D7,D5
          ANDI.W    #$0E00,D5
          ROL.W     #7,D5
          JMP       EA_1

SUB_MEM   JSR       DIS_INDEX
          JSR       GT_SIZE
          JSR       EA_DECODE
          MOVE.B    #',',(A0)+
          JMP       SECNDREG

SUB_DX    LEA       EA_MALT,A2
SUB_DX1   JSR       DIS_INDEX
          JSR       GT_SIZE
          JSR       SECNDREG
          MOVE.B    #',',(A0)+
          JMP       (A2)

LINEB     LEA       MN_LINEB,A1
          CMPI.B    #3,D4
          BEQ.S     D_SUBA
          MOVEQ     #1,D1
          BTST      #8,D7
          BEQ.S     SUB_MEM
          JSR       GET_MR
          MOVEQ     #2,D1
          LEA       EA_DALT,A2
          SUBQ.B    #1,D6
          BNE.S     SUB_DX1
          MOVEQ     #3,D1
          JSR       DIS_INDEX
          JSR       GT_SIZE
          LEA       EA_3,A2
          BRA       SBCD_DATA

LINEE     LEA       MN_LINEE,A1
          CMPI.B    #3,D4
          BEQ.S     SH_MEM
          MOVEQ     #$18,D1
          AND.B     D7,D1
          LSR.B     #3,D1
          JSR       DIS_INDEX
          BSR.S     DIRECTION
          JSR       GT_SIZE
          BTST      #5,D7
          BEQ.S     SH_IMM
          JSR       SECNDREG
          MOVE.B    #',',(A0)+
          BRA.S     SH_REG
SH_IMM    JSR       QUICKDATA
SH_REG    MOVE.B    #'D',(A0)+
          MOVEQ     #7,D0
          AND.B     D7,D0
          ADDI.B    #'0',D0
          MOVE.B    D0,(A0)+
          RTS

SH_MEM    MOVE.W    D7,D1
          ANDI.W    #$0600,D1
          ROL.W     #7,D1
          JSR       DIS_INDEX
          BSR.S     DIRECTION
          LEA       OPR_FLD(A6),A0
          JMP       EA_MALT

DIRECTION MOVEQ     #'R',D0
          BTST      #8,D7
          BEQ.S     DIR_MOVE
          MOVEQ     #'L',D0
DIR_MOVE  MOVE.B    D0,(A0)+
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
MN_ILL    DC.B      '*ILLEGAL OPCODE*',0
MN_SRCCR  DC.B      'CCR',0,'SR',0
MN_USP    DC.B      'USP',0
MN_LINE0  DC.B      'ORI',0,'ANDI',0,'SUBI',0,'ADDI',0,0
          DC.B      'EORI',0,'CMPI',0
MN_BIT    DC.B      'BTST',0,'BCHG',0,'BCLR',0,'BSET',0
MN_MOVEP  DC.B      'MOVEP',0
MN_MOVE   DC.B      'MOVE',0
MN_4_1    DC.B      'NEGX',0,'CLR',0,'NEG',0,'NOT',0
MN_NBCD   DC.B      'NBCD',0
MN_SWAP   DC.B      'SWAP',0
MN_PEA    DC.B      'PEA',0
MN_EXT    DC.B      'EXT',0
MN_MOVEM  DC.B      'MOVEM',0
MN_TST    DC.B      'TST',0
MN_TAS    DC.B      'TAS',0
MN_ILLEG  DC.B      'ILLEGAL',0
MN_TRAP   DC.B      'TRAP',0
MN_LINK   DC.B      'LINK',0
MN_UNLK   DC.B      'UNLK',0
MN_4E7X   DC.B      'RESET',0,'NOP',0,'STOP',0,'RTE',0,0,'RTS',0
          DC.B      'TRAPV',0,'RTR',0
MN_JSR    DC.B      'JSR',0,'JMP',0
MN_CHKLEA DC.B      'CHK',0,'LEA',0
MN_ADDQ   DC.B      'ADDQ',0
MN_SUBQ   DC.B      'SUBQ',0
MN_MOVEQ  DC.B      'MOVEQ',0
MN_LINE8  DC.B      'DIVU',0,'DIVS',0,'OR',0,'SBCD',0
MN_LINE9  DC.B      'SUBA',0,'SUB',0,'SUBX',0
MN_LINEB  DC.B      'CMPA',0,'CMP',0,'EOR',0,'CMPM',0
MN_LINEC  DC.B      'MULU',0,'MULS',0,'AND',0,'ABCD',0
MN_EXG    DC.B      'EXG',0
MN_LINED  DC.B      'ADDA',0,'ADD',0,'ADDX',0
MN_LINEE  DC.B      'AS',0,'LS',0,'ROX',0,'RO',0
          DC.W      0

          END

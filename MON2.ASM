* MULTIMON
* QL MONITOR/DISASSEMBLER
* DISASSEMBLY ROUTINES
* Copyright (C) 1986-1987 by Jan Bredenbeek
* Parts of the source code (C) 2017-2018 by Norman Dunbar and Jan Bredenbeek
* Released under the GPL v3 license in 2017

          INCLUDE   WIN1_QDOS_IN    QDOS Constants
          INCLUDE   MULTIMON_INC    Macros and definitions

          SECTION   MON_CODE

          XDEF      DISASSEM
          XDEF      CN_ADDR
          XDEF      CN_HEXB
          XDEF      CN_HEXL
          XDEF      ADD_WRK

          DATA      0

*--------------------------------------------------------------------
* Checks if we have room in the workspace and if so, stored D1.L at
* the current pointer which is then updated. If we have no room left
* sets WRKSPOV(A6) to $FF to show we have a problem.
*--------------------------------------------------------------------
ADD_WRK   MOVE.L    WRKSPTR(A6),A1  ; Work area current address
          CMPA.L    WRK_END(A6),A1  ; Still ok?
          BGE.S     WRKSP_ERR       ; Nope, skip to set error
          MOVE.L    D1,(A1)+        ; Store D1 in work area
          MOVE.L    A1,WRKSPTR(A6)  ; Update current address
          RTS                       ; Done

WRKSP_ERR ST        WRKSPOV(A6)     ; Flag an error $FF
          RTS                       ; Done

*--------------------------------------------------------------------
* Signed byte to Hexadecimal. Writes the hex to the buffer at (A0).
*--------------------------------------------------------------------
BTOHEXS   TST.B     D1              ; Test sign
          BPL.S     BTOHEX          ; Skip  if positive
          MOVE.B    #'-',(A0)+      ; Must be negative
          NEG.B     D1              ; ABS(D1)
BTOHEX    MOVE.B    #'$',(A0)+      ; Indicate Hexadecimal
          BRA.S     CN_HEXB         ; Convert Byte to Hexadecimal

*--------------------------------------------------------------------
* Signed word to Hexadecimal. Writes the hex to the buffer at (A0).
*--------------------------------------------------------------------
WTOHEXS   TST.W     D1              ; Test sign
          BPL.S     WTOHEX          ; Skip if positive
          MOVE.B    #'-',(A0)+      ; Must be negative
          NEG.W     D1              ; ABS(D1)
WTOHEX    MOVE.B    #'$',(A0)+      ; Indicate Hexadecimal
          BRA.S     CN_HEXW         ; Convert word to Hexadecimal

*--------------------------------------------------------------------
* Long to Hexadecimal - assumed always positive?  Writes the hex to 
* the buffer at (A0).
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
* This code works out the destination EA for numerous instructions.
* The mode is in D7 bits 6-8 and the register is D7 bits 9-11. These
* will be returned in registers D6 (mode) and D5 (register) - if the
* mode is not 7, otherwise we will have D5 = register and D6 = 7 plus
* the register.
*--------------------------------------------------------------------
DEST_EA   MOVEQ     #7,D0           ; Mask for register and ROL count
          MOVE.W    D7,D5           ; Copy opcode
          ROL.W     D0,D5           ; Rotate register to bits 0-2
          AND.W     D0,D5           ; Mask out the register
          MOVE.W    D7,D6           ; Copy opcode again
          ROR.W     #6,D6           ; Move mode to bits 0-2
          AND.W     D0,D6           ; Mask out the mode

*--------------------------------------------------------------------
* MOVE.B is not permitted with an Address register as the destination
* so test D4 for the size and zero indicates .B - the values in D4 =
* B=0, .W=1, .L=2. (JB)
*--------------------------------------------------------------------
          TST.B     D4              ; Byte Size - not allowed with An
          BNE.S     DEST_CMP
          CMPI.B    #1,D6           ; Cannot be An (EA mode 1)
          BEQ.S     EA_ERROR        ; Buffer a question mark for errors

*--------------------------------------------------------------------
* If the mode is not 7, then we are done here, skip out. Otherwise we
* are looking at the destination EA, so we only allow "registers" 0-3
* as 4 = #immediate, and that's never going to be a destination!
* Modes 9 and above are PC-relative or immediate and are not allowed 
* as destination address. (JB)
*
* This does of course, trash the register number but only for mode 7.
*--------------------------------------------------------------------
DEST_CMP  CMP.B     D0,D6           ; Mode 7?
          BNE.S     EA_DEC_1        ; No, decode the EA
          ADD.B     D5,D6           ; Register + mode (7)
          CMPI.B    #$09,D6         ; Register 3 is highest allowed        
          BLT.S     EA_DEC_1        ; Register 0-3 are ok, decode the EA

*--------------------------------------------------------------------
* Invalid mode detected. Buffer a question mark. Probably data here.
* We found either a mode 1  - An, or a mode 7 with a register > 3 and
* those are never destinations. We are probably looking at data.
*--------------------------------------------------------------------
EA_ERROR  MOVE.B    #'?',(A0)+      ; Flag an error
          RTS                       ; Done

*--------------------------------------------------------------------
* Get addressing mode from opcode in D7
* Returns: Register number in D5, addressing mode in D6
* Value of D6       Mode
* -----------       ----
*         0         Dn
*         1         An
*         2         (An)
*         3         (An)+
*         4         -(An)
*         5         n(An)
*         6         n(An,A/Dn)
*         7         addr.W
*         8         addr.L
*         9         addr(PC)
*        10         addr(PC,A/Dn)
*        11         #nn
*--------------------------------------------------------------------
GET_MR    MOVEQ     #$07,D5         ; Bits 0-2 hold register number
          MOVEQ     #$38,D6         ; Bits 3-5 are mode bits
          AND.B     D7,D5           ; D5 = register number
          AND.B     D7,D6           ; D6 = EA mode 
          LSR.B     #3,D6           ; Shift mode bits to 0-2
          CMPI.B    #$07,D6         ; If bits are 111, the register
          BNE.S     L702DE          ; bits indicate modes 7 to 11
          ADD.B     D5,D6           ; so add these to D6
L702DE    RTS                       ; Done

*--------------------------------------------------------------------
* A DATA-type Effective Address is required here.
*--------------------------------------------------------------------
EA_DATA   BSR.S     GET_MR          ; Get EA mode in D6, REG in D5
          CMPI.B    #$01,D6         ; An modes not allowed here
          BEQ.S     EA_ERROR        ; Buffer a question mark for errors
          BRA.S     EA_DEC_1        ; Decode the EA

*--------------------------------------------------------------------
* A Memory Alterable Effective Address is required here.
*--------------------------------------------------------------------
EA_MALT   BSR.S     GET_MR          ; Get EA mode in D6, REG in D5
          CMPI.B    #$08,D6         ; Mode is nnnnnn.l or less?
          BGT.S     EA_ERROR        ; Buffer a question mark for errors
EA_MEM    BSR.S     GET_MR          ; Get EA mode in D6, REG in D5
          CMPI.B    #$02,D6         ; Mode is (An) or higher?
          BLT.S     EA_ERROR        ; Buffer a question mark for errors
          BRA.S     EA_DEC_1        ; Decode the EA

*--------------------------------------------------------------------
* A Control Mode Effective Address is required here.
*--------------------------------------------------------------------
EA_CTRL   BSR.S     GET_MR          ; Get EA mode in D6, REG in D5
          CMPI.B    #$02,D6         ; Mode is (An)?
          BEQ.S     EA_DEC_1        ; Decode the EA
          CMPI.B    #$05,D6         ; Mode is n(An)?
          BLT.S     EA_ERROR        ; Buffer a question mark for errors
          CMPI.B    #$0A,D6         ; Mode is nn(PC,Rn)?
          BGT.S     EA_ERROR        ; Buffer a question mark for errors
          BRA.S     EA_DEC_1        ; Decode the EA

*--------------------------------------------------------------------
* A Data Alterable Effective Address is required here. Modes 9 and 
* above (PC-relative or immediate) are illegal here. (JB)
*--------------------------------------------------------------------
EA_DALT   BSR.S     GET_MR          ; Get EA mode in D6, REG in D5
          CMPI.B    #1,D6           ; Mode is An?
          BEQ.S     EA_ERROR        ; Buffer a question mark for errors

EA_ALT    BSR.S     GET_MR          ; Get EA mode in D6, REG in D5
          CMPI.B    #8,D6           ; Mode is nnnnnn.l or less?
          BGT.S     EA_ERROR        ; Buffer a question mark for errors
          BRA.S     EA_DEC_1        ; Decode the EA

*--------------------------------------------------------------------
* Decode the Effective Address of an instruction (opcode in D7)
*--------------------------------------------------------------------
EA_DECODE BSR.S     GET_MR          ; Get EA mode in D6, REG in D5

EA_DEC_1  CMPI.B    #11,D6          ; Any mode > 11 is an error
          BHI.S     EA_ERROR        ; (at least on 68000/8)
          LSL.W     #1,D6           ; Double the mode value
          MOVE.W    EA_TABLE(PC,D6.W),A1 ; and index into the table
          JMP       EA_TABLE(PC,A1.W)    ; Jump to appropriate handler

*--------------------------------------------------------------------
* Table of pointers to Effective Address decoding routines based on
* the mode of the Effective Address itself.
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_TABLE  DC.W      EA_0-EA_TABLE   ; Dn
          DC.W      EA_1-EA_TABLE   ; An
          DC.W      EA_2-EA_TABLE   ; (An)
          DC.W      EA_3-EA_TABLE   ; (An)+
          DC.W      EA_4-EA_TABLE   ; -(An)
          DC.W      EA_5-EA_TABLE   ; n(An)
          DC.W      EA_6-EA_TABLE   ; n(An,Rn) (Rn = An or Dn)
          DC.W      EA_7-EA_TABLE   ; nnnn.w
          DC.W      EA_8-EA_TABLE   ; nnnnnnnn.l
          DC.W      EA_9-EA_TABLE   ; nnnnn(pc)
          DC.W      EA_A-EA_TABLE   ; nnnnn(pc,Rn) (Rn = An or Dn)
          DC.W      EA_B-EA_TABLE   ; #nnnn

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
SIZETAB   DC.B      'BWL',0         ; Table of instruction sizes

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
          ROL.W     #7,D5           ; Shift bits 7-9 -> 0-2
          ANDI.B    #7,D5           ; Mask out register number

*--------------------------------------------------------------------
* EA Mode 0 - Data Register Direct.                                Dn
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_0      MOVE.B    #'D',(A0)+      ; D for Data Register Direct
          BRA.S     ENTREGNR        ; Do the register number

*--------------------------------------------------------------------
* EA Mode 1 - Address Register Direct.                             An
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
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
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_4      MOVE.B    #'-',(A0)+      ; Buffer the predecrement sign

*--------------------------------------------------------------------
* EA Mode 2 - Address Register Indirect.                         (An)
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_2      MOVE.B    #'(',(A0)+      ; Buffer the bracket
          BSR.S     EA_1            ; Buffer the Address Register
          MOVE.B    #')',(A0)+      ; Close the bracket
          RTS                       ; Done

*--------------------------------------------------------------------
* EA Mode 3 - Address Register Indirect with Postincrement.     (An)+
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_3      BSR.S     EA_2            ; Buffer the (An) register
          MOVE.B    #'+',(A0)+      ; Buffer the postincrement sign
          RTS                       ; Done

*--------------------------------------------------------------------
* EA Mode 5 - Address Register Indirect with Displacement.     nn(An)
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_5      JSR       ADV_W           ; Get the displacement word
          JSR       WTOHEXS         ; Buffer signed hexadecimal word
          BRA.S     EA_2            ; And the indirect address register

*--------------------------------------------------------------------
* EA Mode 6 - Address Register Indirect with Index.         nn(An,Rn)
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_6      JSR       ADV_W           ; Get the displacement word
          JSR       BTOHEXS         ; Buffer signed hexadecimal byte 
          MOVE.B    #'(',(A0)+      ; Buffer the opening bracket
          BSR.S     EA_1            ; Buffer the Address register
          MOVE.B    #',',(A0)+      ; The comma
          BRA.S     EA_INDEX        ; The index register and ')'

*--------------------------------------------------------------------
* EA Mode 7 - Absolute Word                                      nn.W
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_7      JSR       ADV_W           ; Get the displacement word
          EXT.L     D1              ; Make it long, sign extended
          BRA.S     EA_ADDR         ; Skip

*--------------------------------------------------------------------
* EA Mode 8 - Absolute Long                                    nnnn.L
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_8      JSR       ADV_L           ; Get the displacement long word
          BRA.S     EA_ADDR         ; Skip

*--------------------------------------------------------------------
* EA Mode 9 - PC-relative                                      nn(PC)
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_9      MOVE.L    A4,A1           ; Address being disassembled
          JSR       ADV_W           ; Get the displacement word

*--------------------------------------------------------------------
* Entry point used by Bxx.S short branches - D1 holds displacement A1
* holds a copy of the current instruction address from A4.
*--------------------------------------------------------------------
EA_9A     EXT.L     D1              ; Sign extended to long word
          ADD.L     A1,D1           ; Add the displacement

*--------------------------------------------------------------------
* Calculate effective address in hex. When disassembling in 2-pass
* mode, store the address in the label table (DISMOD=0) or write it
* to the buffer, but only if it lies within the address range of the
* disassembly (this writes Lxxxx, otherwise $xxxxx).
*--------------------------------------------------------------------
EA_ADDR   MOVEQ     #'$',D0         ; Assume literal address
          TST.B     DISMOD(A6)      ; Single pass disassembly?
          BLT.S     EA_BP           ; yes, write it
          CMP.L     DISFRST(A6),D1  ; Before start?
          BCS.S     ST_LABEL        ; yes, jump
          CMP.L     DISLAST(A6),D1  ; After end?
          BHI.S     ST_LABEL        ; yes, jump
          MOVEQ     #'L',D0         ; Make it a label
          TST.B     DISMOD(A6)      ; 0 means 1st pass (collecting)
          BGT.S     ST_LABEL        ; and 1 means 2nd pass (writing)
          MOVE.L    LBL_TBL(A6),A1  ; get start of label table
EA_A_LP   CMPA.L    WRKSPTR(A6),A1  ; end reached?
          BGE.S     NEW_LABEL       ; yes, enter label
          CMP.L     (A1)+,D1        ; Match address
          BNE.S     EA_A_LP         ; Loop back if not found
          BRA.S     ST_LABEL        ; Existing label found, skip
NEW_LABEL JSR       ADD_WRK         ; Otherwise, enter new label
ST_LABEL  MOVE.B    D0,(A0)+        ; Now write 'L' or '$'
          JMP       CN_ADDR         ; .. followed by address

*--------------------------------------------------------------------
* This writes the literal address, possibly followed by (BP) in case
* of a relative address to the base of the program
*--------------------------------------------------------------------
EA_BP     MOVE.L    D1,D2           ; Save original address
          BSR.S     ST_LABEL        ; Write address to the buffer
          CMP.L     D1,D2           ; If in relative mode, D1 will
          BEQ.S     EA_BP_EN        ; have been changed by the call
          LEA       BPMSG,A1        ; to CN_ADDR, so add a (BP)
          JSR       COPY_LP         ; suffix to indicate rel. mode
EA_BP_EN  RTS                       ; Done

*--------------------------------------------------------------------
* The (BP) suffix is added to a literal address to indicate that it's
* relative to the base of the program (only in 1-pass disassemblies)
*--------------------------------------------------------------------
BPMSG     DC.B      '(BP)',0,0

*--------------------------------------------------------------------
* EA Mode 10 - PC-relative with index                     nnnn(PC,Rn)
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_A      JSR       ADV_W           ; Get the displacement word
          MOVE.W    D1,-(A7)        ; Save worker
          EXT.W     D1              ; Extend 8 bit displacement to word
          EXT.L     D1              ; Then to long word
          ADD.L     A4,D1           ; A4 is the address being disassembled
          SUBQ.L    #2,D1           ; A4 was already incremented, adjust
          BSR.S     EA_ADDR         ; Displacement ADDRESS in hexadecimal
          MOVE.W    (A7)+,D1        ; Restore worker
          MOVE.B    #'(',(A0)+      ; Buffer a bracket

*--------------------------------------------------------------------
* Buffers the index register in those Effective Addresses that have
* one - for example, called from EA Modes 6 & A above. Also closes
* the instruction with a ')'.
*--------------------------------------------------------------------
EA_INDEX  MOVEQ     #'D',D0         ; Assumes a Data index register
          TST.W     D1              ; Correct? Uses bit 15 to check
          BPL.S     INDEXREG        ; Yes, skip (bit 15 = 0 = D)
          MOVEQ     #'A',D0         ; Bad guess, it was an address

INDEXREG  MOVE.B    D0,(A0)+        ; Buffer the index register type
          ROL.W     #4,D1           ; Get the register number
          ANDI.B    #7,D1           ; Mask it out
          ADDI.B    #'0',D1         ; ASCIIfy it
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
* EA Mode 11 - Immediate.                                       #nnnn
*
* D5 = Register
* D6 = EA Mode
* D7 = Opcode word
*--------------------------------------------------------------------
EA_B      BSR.S     ADVANCE         ; Get the B/W/L following into D1
          MOVE.B    #'#',(A0)+      ; Buffer the hash
          MOVE.B    D4,D0           ; Size .B=0, .W=1, .L=2
          BEQ       BTOHEX          ; .B - Buffer D1.B as hex
          SUBQ.B    #1,D0
          BEQ       WTOHEX          ; .W - Buffer D1.W as hex
          BRA       LTOHEX          ; .L - Buffer D1.L as hex

*--------------------------------------------------------------------
* Make sure that the address in A4 is even. A4 is the pointer to the
* instruction/address being disassembled.
*--------------------------------------------------------------------
ALIGN     MOVE.L    A4,D0           ; Copy address to D0
          ADDQ.L    #1,D0           ; Increment
          BCLR      #0,D0           ; Make even
          MOVE.L    D0,A4           ; Copy back
          RTS                       ; Done

*--------------------------------------------------------------------
* Advance A4 to the next desired address. If D4 is 2 then advance by 
* 4 bytes. Otherwise, advance by 2 bytes. Buffers the byte, word or
* long value read from the following address space at a buffer in A5
* probably for later use when dumping the instructions hex.
*--------------------------------------------------------------------
ADVANCE   CMPI.B    #2,D4           ; Long advance?
          BEQ.S     ADV_L           ; Yes.
          MOVEQ     #0,D1           ; Clear all of D1.

*--------------------------------------------------------------------
* Fetch a word sized operand, offset etc from the next address in 
* memory to be disassembled for the current instruction.
*--------------------------------------------------------------------
ADV_W     BSR       ALIGN           ; Make sure A4 is even
          MOVE.W    (A4)+,D1        ; Fetch the desired word
          MOVEQ     #4,D0           ; 4 hex characters required
          BRA.S     ADV_2           ; Skip

*--------------------------------------------------------------------
* Fetch a long sized operand, offset etc from the next address in 
* memory to be disassembled for the current instruction.
*--------------------------------------------------------------------
ADV_L     BSR       ALIGN           ; Make sure A4 is even
          MOVE.L    (A4)+,D1        ; Fetch the long word
          MOVEQ     #8,D0           ; 8 hex characters required

*--------------------------------------------------------------------
* Convert the word or long in D1 to a sequence of hex characters as
* defined by the value in D0.B in the buffer at A5 using A0 in a temp
* manner.
*--------------------------------------------------------------------
ADV_2     EXG       A0,A5           ; A5 is the output buffer pointer
          JSR       CN_HEX          ; Convert D1 to D0.B hex chars
          EXG       A0,A5           ; Restore new buffer pointer
COPY_END  RTS                       ; Done

*--------------------------------------------------------------------
* Code to scan through the current (list of) instructions at (A1)
* Looking for the entry in the list following the next CHR$(0).
* All entries are zero terminated.
* D1.W Holds the actual entry in the list that we want to extract.
*--------------------------------------------------------------------
NXTENTRY  TST.B     (A1)+           ; Found the terminating zero?
          BNE.S     NXTENTRY        ; No, keep looking
DIS_INDEX DBF       D1,NXTENTRY     ; Yes, find the next one(s)

*--------------------------------------------------------------------
* Copy an entry from a list of zero terminated strings to the buffer
* at (A0). The list is at (A1). 
*--------------------------------------------------------------------
COPY_LP   MOVE.B    (A1)+,D0        ; Grab a byte
          BEQ.S     COPY_END        ; We are done on a zero byte
          MOVE.B    D0,(A0)+        ; Otherwise, copy it
          BRA.S     COPY_LP         ; And keep going

*--------------------------------------------------------------------
* Extract a two byte condition code from the table at (A1) into the
* buffer at (A0). D7 holds the op-code word.The condition code is in
* bits 8-11.
*--------------------------------------------------------------------
CONDITION MOVE.W    D7,D1           ; Copy op-code
          ANDI.W    #$0F00,D1       ; Keep only condition code bits
          LSR.W     #7,D1           ; Shift down bit 8-> bit 1 (CC*2)
          MOVE.B    0(A1,D1.W),(A0)+    ; First byte of CC
          MOVE.B    1(A1,D1.W),(A0)+    ; Second byte of CC
          RTS                       ; Done

*--------------------------------------------------------------------
* Condition codes table. Two bytes for each condition code. 'DBRA' is
* actually 'DBF ' in this table.
*--------------------------------------------------------------------
CONDTAB1  DC.B      'T F HILSCCCSNEEQVCVSPLMIGELTGTLE'

*--------------------------------------------------------------------
* More condition codes. These are for BRA, BSR and the rest are the 
* Bcc codes.
*--------------------------------------------------------------------
CONDTAB2  DC.B      'RASRHILSCCCSNEEQVCVSPLMIGELTGTLE'

*--------------------------------------------------------------------
* Checks if the current address in A4 is an address in the label 
* table. Returns -7 if not found, otherwise Z is set if found.
*--------------------------------------------------------------------
FIND_LBL  MOVE.L    LBL_TBL(A6),A1  ; Start of label table

FINDLBL2  CMPA.L    WRKSPTR(A6),A1  ; Are we done yet?
          BGE.S     LBL_NOTF        ; Yes, A4 is not a label
          CMPA.L    (A1)+,A4        ; Check if A4 is a label
          BNE.S     FINDLBL2        ; Loop around
          RTS                       ; Done. Z set if A4 is in the table

*--------------------------------------------------------------------
* NOT FOUND (-7) Error return.
*--------------------------------------------------------------------
LBL_NOTF  MOVEQ     #-7,D0          ; Z is unset if A4 is not  a label
          RTS                       ; Done

*--------------------------------------------------------------------
* Disassemble memory - helper routine.
* Enter here with:
*
* A4 = Address to disassemble.
*--------------------------------------------------------------------
* Start by space filling the entire disassembly buffer.
*--------------------------------------------------------------------
DISASSEM  LEA       DISBUF(A6),A0   ; Dissassembly buffer
          MOVE.L    A0,A1           ; Copy
          MOVEQ     #$20,D1         ; Space character
          MOVEQ     #DISBUFLEN-1,D0 ; Byte counter

CLRDISBUF MOVE.B    D1,(A1)+        ; Clear a byte
          DBF       D0,CLRDISBUF    ; Do the rest

*--------------------------------------------------------------------
* Convert the current address to hex first as a label - L######## but
* only if A4 is in the labels table and we are on a multi-pass 
* disassemble.
*--------------------------------------------------------------------
          MOVE.L    A4,D1           ; Current instruction address
          JSR       CN_ADDR         ; Convert to 8 hex characters
          LEA       1(A0),A5        ; Temporary buffer? TODO => ????
          TST.B     DISMOD(A6)      ; -ve = 1 pass, +ve = 2 pass, 0 = pass 1 of 2
          BLE.S     TAB_MNEM        ; Single pass disassembly, no labels
          BSR.S     FIND_LBL        ; Is A4 a label?
          BNE.S     TAB_MNEM        ; No. Skip
          LEA       LBL_FLD(A6),A0  ; Label position in output buffer
          MOVE.B    #'L',(A0)+      ; Buffer the 'L'
          MOVE.L    A4,D1           ; Label's address
          JSR       CN_ADDR         ; Buffer address

*--------------------------------------------------------------------
* Now work out if we are decoding a data area as defined by the user
* if, and only if, we are running a multi-pass disassembly.
*--------------------------------------------------------------------
TAB_MNEM  LEA       MNFIELD(A6),A0  ; Advance buffer pointer
          TST.B     DISMOD(A6)      ; Single pass disassembly?
          BLT       DIS_INST        ; Yes, skip
          MOVE.L    DATATBL(A6),A1  ; User supplied data areas

*--------------------------------------------------------------------
* Checks if the current address in A4 is part of a data area. Uses D6
* as the start and D7 as the end of this particular data area. The
* start address has the high byte flagging the data size:
* $FF = DC.B, $00 = DC.W and $01 = DC.L.
*--------------------------------------------------------------------
DATA_LOOP CMPA.L    LBL_TBL(A6),A1  ; Reached end yet?
          BGE       DIS_INST        ; Yes, skip
          MOVE.L    (A1)+,D6        ; Start of data area
          MOVE.L    (A1)+,D7        ; End of data area
          MOVE.L    D6,D1           ; Copy start address
          ANDI.L    #$00FFFFFF,D1   ; But assume 24 bit start addresses
          CMPA.L    D1,A4           ; Check address is in this area
          BCS.S     DATA_LOOP       ; Nope. Skip this one
          CMPA.L    D7,A4           ; Check if we are still in the area
          BHI.S     DATA_LOOP       ; Nope, skip this one
          MOVE.B    #'D',(A0)+      ; It's data - buffer a 'D'
          MOVE.B    #'C',(A0)+      ; And buffer a 'C'
          ROL.L     #8,D6           ; Get the size byte from D6
          MOVE.B    D6,D4           ; Copy to D4
          EXT.W     D4
          ADDQ.W    #1,D4           ; .B = 0, .W = 1, .L = 2
          JSR       GT_SIZE         ; Buffer the dot and the size
          TST.B     D6              ; .B = $FF, .W = $00, .L = $01
          BEQ.S     DATA_WORD       ; Do word sized data
          BGT.S     DATA_LONG       ; Do long sized data
          MOVEQ     #3,D5           ; Do byte sized data 4 at a time
          BRA.S     BYTE_ENT        ; Don't need a comma, yet

*--------------------------------------------------------------------
* Buffers a comma prior to the next data byte.
*--------------------------------------------------------------------
BYTE_LOOP MOVE.B    #',',(A0)+      ; Buffer a comma

*--------------------------------------------------------------------
* Buffers out the DC.B data bytes. D5 controls how many will be done.
* Also buffers each data byte to the buffer in A5 for later use. Data
* bytes less than a space, or higher than CHR(127) (Copyright) are 
* output in hex. Printable characters in between are output in ASCII.
*--------------------------------------------------------------------
BYTE_ENT  MOVE.B    (A4)+,D1        ; Grab next byte
          EXG       A0,A5           ; Use temp buffer at A5
          JSR       CN_HEXB         ; Buffer a byte
          EXG       A0,A5           ; Restore normal buffer
          CMPI.B    #$20,D1         ; Lower than a space?
          BCS.S     B_HEX           ; Yes, do it in hex
          CMPI.B    #$7F,D1         ; Higher than $7F?
          BCC.S     B_HEX           ; Yes, do it in hex too
          MOVEQ     #$27,D0         ; Single quote
          MOVE.B    D0,(A0)+        ; Buffer quote
          MOVE.B    D1,(A0)+        ; Buffer character byte
          MOVE.B    D0,(A0)+        ; Buffer quote
          BRA.S     B_NEXT

*--------------------------------------------------------------------
* Output a data byte in hex.
*--------------------------------------------------------------------
B_HEX     JSR       BTOHEX          ; Buffer '$' and a hex byte

*--------------------------------------------------------------------
* Are we done yet? D7 holds the last address of this data area. If we
* have more to do, buffer a comma prior to the next data byte 
* processing.
* If A4 happens to be a label, then stop processing as we will need a
* label in the output for it.
*--------------------------------------------------------------------
B_NEXT    CMPA.L    D7,A4           ; Done yet?
          BHI.S     B_END           ; Yes
          BSR       FIND_LBL        ; Is A4 in the labels table?
          DBEQ      D5,BYTE_LOOP    ; Go around, unless A4 is a label
B_END     RTS                       ; Finished

*--------------------------------------------------------------------
* Buffers Word sized data. Loops around until D7 reaches the end 
* address of this data area. Each word is read and buffered in hex.
* If A4 happens to be a label, then stop processing as we will need a
* label in the output for it.
*--------------------------------------------------------------------
DATA_WORD JSR       ADV_W           ; Grab next word of data
          JSR       WTOHEX          ; Convert to hex & buffer
          CMPA.L    D7,A4           ; Done yet?
          BHI.S     B_END           ; Yes, exit
          BSR       FIND_LBL        ; Is A4 in the labels table?
          BEQ.S     B_END           ; Yes, stop processing words
          MOVEQ     #0,D7           ; No. Trashes end address ????
          MOVE.B    #',',(A0)+      ; Buffer a comma
          BRA.S     DATA_WORD       ; Do next word

*--------------------------------------------------------------------
* Buffers long sized data.
*--------------------------------------------------------------------
DATA_LONG JSR       ADV_L           ; Grab the next long word of data
          JMP       LTOHEX          ; Convert to hex and buffer

*--------------------------------------------------------------------
* Disassemble an instruction word.
*
* A4 = where from address.
* D1 will be the "line" or the high nibble of the opcode.
* D4 will be the size of the instruction. .B=0, .W=1, .L=2 at least
* for most instructions. MOVEP and Bxxx etc are different.
* D7 will be set to the opcode.
* 
* The high nibble of the instruction is used to index the linetable
* and from there, a jump is made to the decoding code itself.
*--------------------------------------------------------------------
DIS_INST  JSR       ADV_W           ; Get next opcode in D1, A4 += 2
          MOVE.W    D1,D7           ; Copy opcode to D7
          MOVEQ     #0,D4           ; Clear out worker
          MOVE.B    D1,D4           ; Low byte. Bits 6-7 = size.
          LSR.B     #6,D4           ; D4.B = Instruction size
          ANDI.W    #$F000,D1       ; Isolate high nibble
          ROL.W     #5,D1           ; High nibble * 2
          MOVE.W    LINETAB(PC,D1.W),D1 ; Table start
          JMP       LINETAB(PC,D1.W)    ; Decode instruction type

*--------------------------------------------------------------------
* The high nibble tells us how to decode the instruction word. This
* is a table of offsets to the decoding code.
* There are no legal instructions with $A or $F as the high nibble -
* well, $F instructions are for the co-processor or 68040 only. They
* are ignored here.
*--------------------------------------------------------------------
LINETAB   DC.W      LINE0-LINETAB   ; ORI, Bxxx, MOVEP, ANDI, SUBI,
;                                   ; ADDI, EORI, CMPI
          DC.W      LINE1-LINETAB   ; MOVES (68010), MOVE.B
          DC.W      LINE2-LINETAB   ; MOVE.L, MOVEA.L
          DC.W      LINE3-LINETAB   ; MOVEA.W, MOVE.W
          DC.W      LINE4-LINETAB   ; Everything not seen elsewhere!
          DC.W      LINE5-LINETAB   ; ADDQ, Scc, DBcc, SUBQ
          DC.W      LINE6-LINETAB   ; Bcc, BRA, BSR
          DC.W      LINE7-LINETAB   ; MOVEQ
          DC.W      LINE8-LINETAB   ; OR, DIVU, SBCD, DIVS
          DC.W      LINE9-LINETAB   ; SUB, SUBA, SUBX
          DC.W      ILL_INST-LINETAB  ; Nothing here
          DC.W      LINEB-LINETAB   ; CMP, CMPA, CMPM, EOR
          DC.W      LINEC-LINETAB   ; AND, MULU, ABCD, EXG, MULS
          DC.W      LINED-LINETAB   ; ADD, ADDA, ADDX
          DC.W      LINEE-LINETAB   ; Shift/rotate
          DC.W      ILL_INST-LINETAB  ; Nothing here

*--------------------------------------------------------------------
* LineA or any other illegal instruction.
*--------------------------------------------------------------------
ILL_INST  LEA       MN_ILL,A1       ; Illegal instruction message
          JMP       COPY_LP         ; Copy to buffer

*--------------------------------------------------------------------
* Line0 - ORI, Bxxx, MOVEP, ANDI, SUBI, ADDI, EORI, CMPI.
*--------------------------------------------------------------------
LINE0     LEA       MN_LINE0,A1     ; Instruction list for Line0
          MOVE.W    D7,D1           ; Opcode copied
          ANDI.W    #$0E00,D1       ; Keep only bits 9-11
          ROL.W     #7,D1           ; Bits 9-11 into bits 0-2
          BTST      #$08,D7         ; MOVEP?
          BNE.S     TST_MOVEP       ; Yes, probably
          CMPI.B    #$04,D1         ; Static Bxxx?
          BEQ.S     BIT_MAN         ; Yes
          CMPI.B    #$07,D1         ; Can't possibly be 7
          BEQ.S     ILL_INST        ; Illegal Instruction
          CMPI.B    #$03,D4         ; Check size, 3 is bad
          BEQ.S     ILL_INST        ; Illegal instruction
          MOVE.W    D1,D2           ; Copy D1

*--------------------------------------------------------------------
* The outliers are filtered out so D1 is one of the following:
*
* 0 = ORI, 1 = ANDI, 2 = SUBI, 3 = ADDI, 5 = EORI, 6 = CMPI
*--------------------------------------------------------------------
          JSR       DIS_INDEX       ; Buffer D1th instruction
          MOVEQ     #$3F,D1         ; 0011 1111
          AND.B     D7,D1           ; D1 = Effective Address
          CMPI.B    #$3C,D1         ; ORI/ANDI/EORI CCR?
          BNE.S     L0_IMM          ; No, skip
          SUBQ.B    #2,D2           ; Look for CCR/SR opcodes
          BMI.S     L70672          ; ORI or ANDI
          SUBQ.B    #3,D2           ; Look again
          BNE.S     L0_IMM          ; Not EORI

*--------------------------------------------------------------------
* Here we find ORI/ANDI/EORI CCR/SR instructions. Fill in the CCR or
* SR part of the instruction.
*--------------------------------------------------------------------
L70672    LEA       OPR_FLD(A6),A0  ; Operand position in output buffer
          JSR       EA_B            ; #immediate data
          MOVE.B    #$2C,(A0)+      ; Buffer a comma
          MOVE.W    D4,D1           ; Size is 00 or 01 for byte and word
          LEA       MN_SRCCR,A1     ; CCR (byte) or SR (word)
          JMP       DIS_INDEX       ; Buffer CCR or SR

*--------------------------------------------------------------------
* Here we find ORI/ANDI/SUBI/ADDI/EORI/CMPI instructions not affecting
* the CCR or SR.
*--------------------------------------------------------------------
L0_IMM    JSR       GT_SIZE         ; Buffer the dot and the size
          JSR       EA_B            ; #immediate data
          MOVE.B    #',',(A0)+      ; Add a comma
          JMP       EA_DALT         ; Data alterable address

*--------------------------------------------------------------------
* This should be MOVEP as it's the only line0 with bit 8 set. If it
* isn't MOVEP, then drop into a test for bit manipulation opcodes.
*--------------------------------------------------------------------
TST_MOVEP JSR       GET_MR          ; Get EA mode in D6, REG in D5
          SUBQ.B    #1,D6           ; MOVEP has mode 1
          BEQ.S     D_MOVEP         ; Definitely MOVEP

*--------------------------------------------------------------------
* Dynamic & Static bit manipulations here.
* Bits 6-7 hold the actual operation. 00 = BTST, 01 = BCHG, 10 = BCLR,
* 11 = BSET.
* Bit 8 says Dynamic (1) or Static (0).
*--------------------------------------------------------------------
BIT_MAN   MOVE.W    D4,D1           ; Get the size (= type) from D4
          LEA       MN_BIT,A1       ; Start of instructions buffer
          JSR       DIS_INDEX       ; Buffer D1th Instruction
          LEA       OPR_FLD(A6),A0  ; Output buffer operand position
          BTST      #8,D7           ; Static?
          BEQ.S     BIT_IMM         ; Yes, skip

*--------------------------------------------------------------------
* Dynamic Bxxx operations.                                 Bxxx Dn,EA
*--------------------------------------------------------------------
          JSR       SECNDREG        ; Dymanic - buffer the Dn register
          BRA.S     L0_COMMA        ; Join up with statics

*--------------------------------------------------------------------
* Static Bxxx operations.                                  Bxxx #n,EA
*--------------------------------------------------------------------
BIT_IMM   MOVE.B    #'#',(A0)+      ; Buffer the hash
          JSR       ADV_W           ; Get the next word
          JSR       BTOHEX          ; Low byte is the bit number

*--------------------------------------------------------------------
* Dynamic & Staic Bxxx join up here again.
*--------------------------------------------------------------------
L0_COMMA  MOVE.B    #',',(A0)+      ; Buffer the comma
          TST.B     D4              ; 00 = BTST
          BEQ       EA_DATA         ; Data register only
          JMP       EA_DALT         ; The rest are data alterable

*--------------------------------------------------------------------
* MOVEP only. Memory to register.                      MOVEP d(Ay),Dx
*--------------------------------------------------------------------
D_MOVEP   LEA       MN_MOVEP,A1     ; 'MOVEP' opcode
          JSR       COPY_LP         ; Buffer it
          JSR       SIZE_WL         ; .W or .L into buffer
          TST.B     D7              ; Bit 7 says direction
          BMI.S     MOVEP_2         ; 1 = register to memory
          JSR       EA_5            ; Do d(Ay) part of opcode
          MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       SECNDREG        ; Buffer the Dx part

*--------------------------------------------------------------------
* MOVEP only. Register to memory.                      MOVEP Dx,d(Ay)
*--------------------------------------------------------------------
MOVEP_2   JSR       SECNDREG        ; Buffer the Dx part
          MOVE.B    #',',(A0)+      ; Buffer a comma
          MOVEQ     #7,D5           ; Mask for register
          AND.B     D7,D5           ; D5 = register number
          JMP       EA_5            ; Do d(Ay) part of opcode

*--------------------------------------------------------------------
* Line1 - MOVES (68010), MOVE.B.
*--------------------------------------------------------------------
LINE1     MOVEQ     #0,D4           ; Flag = byte size
          BRA.S     D_MOVE          ; Do all MOVEs

*--------------------------------------------------------------------
* Line2 - MOVEA.L, MOVE.L.
*--------------------------------------------------------------------
LINE2     MOVEQ     #2,D4           ; Flag = long size
          BRA.S     D_MOVE          ; Do all MOVEs

*--------------------------------------------------------------------
* Line3 - MOVEA.W, MOVE.W.
*--------------------------------------------------------------------
LINE3     MOVEQ     #1,D4           ; Flag = word size

*--------------------------------------------------------------------
* D4 = size for MOVE instructions - .B=0, .W=1, .L=2
*--------------------------------------------------------------------
D_MOVE    LEA       MN_MOVE,A1      ; 'MOVE'
          JSR       COPY_LP         ; Copy to buffer
          JSR       GT_SIZE         ; Copy size to buffer
          TST.B     D4              ; Check size flag
          BNE.S     MOVE_WL         ; Not byte, skip
          JSR       EA_DATA         ; Get EA mode and register
          BRA.S     MOVE_2          ; Skip

*--------------------------------------------------------------------
* Word and long MOVEs come here.
*--------------------------------------------------------------------
MOVE_WL   JSR       EA_DECODE       ; Decode the source EA

*--------------------------------------------------------------------
* Byte, Word and long MOVEs end up here eventually.
*--------------------------------------------------------------------
MOVE_2    MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       DEST_EA         ; Decode the destination EA

*--------------------------------------------------------------------
* Line4 - NEGX, MOVE (SR), CHK, LEA, CLR, MOVE (CCR), NEG, NOT, NBCD,
*         SWAP, PEA, EXT.W, MOVEM, EXT.L, TST, TAS, ILLEGAL, TRAP,
*         LINK, UNLK, MOVE (USP), RESET, NOP, STOP, RTE, RTD (68010),
*         RTS, TRAPV, RTR, MOVEC (68010), JSR, JMP.
*--------------------------------------------------------------------
LINE4     BTST      #8,D7           ; Try to identify the opcode
          BEQ.S     L4_MISC         ; CHK and LEA have a 1, only

*--------------------------------------------------------------------
* Must be CHK or LEA here as bit 8 was set. 
*--------------------------------------------------------------------
          TST.B     D7              ; Check bit 7 of opcode
          BPL       ILL_INST        ; Not set is illegal, skip
          MOVEQ     #1,D1           ; Assume CHK first
          AND.B     D4,D1           ; CHK = 2, LEA = 3, so then 0 & 1
          LEA       MN_CHKLEA,A1    ; 'CHK', 'LEA'
          JSR       DIS_INDEX       ; Buffer D1th instruction
          LEA       OPR_FLD(A6),A0  ; Adjust output buffer pointer
          LSR.B     #1,D4           ; LEA has bit 0 set
          BCS.S     D_LEA           ; It's LEA

*--------------------------------------------------------------------
* We do CHK here.                                           CHK EA,Dn
*--------------------------------------------------------------------
          JSR       EA_DATA         ; Get EA mode and register
          MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       SECNDREG        ; Do the D register

*--------------------------------------------------------------------
* We do LEA here.                                           LEA EA,An
*--------------------------------------------------------------------
D_LEA     JSR       EA_CTRL         ; Do Control Mode EA
          BRA       SECND_ADD       ; Do the A register 

*--------------------------------------------------------------------
* Attempt to do every type 4 that is not CHK or LEA here!
*--------------------------------------------------------------------
L4_MISC   MOVE.W    D7,D1           ; Copy the opcode word
          ANDI.W    #$0600,D1       ; 0000 0110 0000 0000 = bits 9-10
          ROL.W     #7,D1           ; Move to bits 0-1
          BTST      #11,D7          ; Filter out some opcodes
          BNE.S     L4_2            ; Skip
          CMPI.B    #3,D4           ; Size = 3 = MOVE from SR/CCR
          BEQ.S     MOVE_SR         ; MOVE SR/CCR - skip

*--------------------------------------------------------------------
* NEGX, CLR, NEG, NOT at this point.
*--------------------------------------------------------------------
          LEA       MN_4_1,A1       ; 'NEGX', 'CLR', 'NEG', 'NOT'
          JSR       DIS_INDEX       ; Buffer D1th instruction
          JSR       GT_SIZE         ; Buffer the dot and the size
          JMP       EA_DALT         ; Do the data alterable address

*--------------------------------------------------------------------
* MOVE to/from SR/CCR here.
* D1 = 00 = MOVE from SR
*      01 = MOVE from CCR (MC68010 only)
*      10 = MOVE to CCR
*      11 = MOVE to SR
*--------------------------------------------------------------------
MOVE_SR   SUBQ.B    #1,D1           ; MOVE from CCR?
          BEQ       ILL_INST        ; Yes, illegal, MC68010 only
          LEA       MN_MOVE,A1      ; 'MOVE'
          JSR       COPY_LP         ; Buffer the opcode
          LEA       OPR_FLD(A6),A0  ; Adjust output buffer position
          SUBQ.B    #1,D1           ; Move to SR/CCR?
          BPL.S     TO_SR           ; Yes, skip

*--------------------------------------------------------------------
* MOVE from SR only here.
*--------------------------------------------------------------------
          LEA       MN_SRCCR,A1     ; 'CCR', 'SR'
          MOVEQ     #1,D1           ; Force SR
          JSR       DIS_INDEX       ; Buffer instruction
          MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       EA_DALT         ; And the data alterable EA

*--------------------------------------------------------------------
* MOVE to SR/CCR here.
*--------------------------------------------------------------------
TO_SR     MOVE.W    D1,D4           ; Save D1 (0 = CCR, 1 = SR)
          JSR       EA_DATA         ; Get EA mode and register
          MOVE.B    #',',(A0)+      ; Buffer the comma
          MOVE.W    D4,D1           ; Restore D1
          LEA       MN_SRCCR,A1     ; 'CCR', 'SR'
          JMP       DIS_INDEX       ; Buffer D1th instruction

*--------------------------------------------------------------------
* Lots more mode 4's here.
* D1 = bits 9-10 of the opcode moved into bits 0-1.
*--------------------------------------------------------------------
L4_2      SUBQ.B    #1,D1           ; More filtering
          BEQ       D_TST           ; TST, TAS or ILLEGAL maybe
          BGT       D_MOVEM2        ; Others go here
          SUBQ.B    #1,D4           ; Size 1 = SWAP or PEA
          BEQ.S     SWAP_PEA        ; Skip to SWAP or PEA
          BGT.S     EXT_MOVEM       ; EXT or MOVEM

*--------------------------------------------------------------------
* NBCD here.
*--------------------------------------------------------------------
          LEA       MN_NBCD,A1      ; 'NBCD'
          JSR       COPY_LP         ; Buffer the opcode
          LEA       OPR_FLD(A6),A0  ; Update buffer position
          JMP       EA_DALT         ; And do the data alterable EA

*--------------------------------------------------------------------
* SWAP or PEA arrive here.
*--------------------------------------------------------------------
SWAP_PEA  MOVEQ     #$38,D0         ; 0011 1000 = bits 3-5
          AND.B     D7,D0           ; Mask off the EA mode
          BNE.S     D_PEA           ; PEA cannot be mode 0

*--------------------------------------------------------------------
* SWAP here.
*--------------------------------------------------------------------
          LEA       MN_SWAP,A1      ; 'SWAP'
          JSR       COPY_LP         ; Buffer it
          LEA       OPR_FLD(A6),A0  ; Adjust buffer position
          JMP       EA_DECODE       ; Decode EA

*--------------------------------------------------------------------
* PEA here.
*--------------------------------------------------------------------
D_PEA     LEA       MN_PEA,A1       ; 'PEA'
          JSR       COPY_LP         ; Buffer it
          LEA       OPR_FLD(A6),A0  ; Adjust buffer position
          JMP       EA_CTRL         ; Decode control mode EA

*--------------------------------------------------------------------
* EXT or MOVEM here.
*--------------------------------------------------------------------
EXT_MOVEM JSR       GET_MR          ; Get EA mode in D6, REG in D5
          LEA       MN_EXT,A1       ; 'EXT'
          TST.B     D6              ; Test anyway mode 0 = EXT
          BEQ.S     D_EXT           ; It's EXT

*--------------------------------------------------------------------
* MOVEM here.
*--------------------------------------------------------------------
          LEA       MN_MOVEM,A1     ; Must be 'MOVEM'

*--------------------------------------------------------------------
* EXT here.
*--------------------------------------------------------------------
D_EXT     JSR       COPY_LP         ; Buffer the opcode
          JSR       SIZE_WL         ; Buffer the size
          TST.B     D6              ; EXT?
          BEQ       EA_0            ; Yes, do the Dn EA for EXT

*--------------------------------------------------------------------
* MOVEM continues here.                              MOVEM reglist,EA
*--------------------------------------------------------------------
          JSR       ADV_W           ; Get following word
          CMPI.B    #4,D6           ; -(An)?
          BNE.S     D_MOVEM1        ; No, skip

*--------------------------------------------------------------------
* MOVEM to/from -(An). We need to reverse the bits in the register
* list word that follows the opcode for this variation.
*--------------------------------------------------------------------
          MOVE.W    D1,D2           ; Copy register list word
          MOVEQ     #15,D0          ; 16 bits to reverse

REV_LOOP  LSR.W     #1,D2           ; Reverse a single bit         
          ROXL.W    #1,D1

REV_2     DBF       D0,REV_LOOP     ; Do the rest

*--------------------------------------------------------------------
* MOVEM all together again.
*--------------------------------------------------------------------
D_MOVEM1  BSR       REGLIST         ; Buffer the register list
          MOVE.B    #',',(A0)+      ; And a comma
          CMPI.B    #2,D6           ; (An) mode?
          BEQ.S     D_MOVEM3        ; Yes, skip
          CMPI.B    #4,D6           ; -(An) mode?
          BLT       EA_ERROR        ; Illegal modes detected
          CMPI.B    #8,D6           ; Mode 7.1 = Absolute Long
          BGT       EA_ERROR        ; Buffer a question mark for errors

D_MOVEM3  JMP       EA_DECODE       ; Decode the EA

*--------------------------------------------------------------------
* TST, TAS or ILLEGAL here.
*--------------------------------------------------------------------
D_TST     LEA       MN_ILLEG,A1     ; Try 'ILLEGAL'
          CMPI.B    #$FC,D7         ; Check anyway
          BEQ       COPY_LP         ; Good guess, ILLEGAL.
          CMPI.B    #3,D4           ; Size 3 = TAS
          BEQ.S     D_TAS           ; Skip to TAS

*--------------------------------------------------------------------
* TST here.
*--------------------------------------------------------------------
          LEA       MN_TST,A1       ; 'TST'
          JSR       COPY_LP         ; Buffer the opcode
          JSR       GT_SIZE         ; Buffer the dot and the size
          JMP       EA_DALT         ; Buffer the EA

*--------------------------------------------------------------------
* TAS here.
*--------------------------------------------------------------------
D_TAS     LEA       MN_TAS,A1       ; 'TAS'
          JSR       COPY_LP         ; Buffer the opcode
          LEA       OPR_FLD(A6),A0  ; Adjust buffer position
          JMP       EA_DALT         ; Buffer the EA

*--------------------------------------------------------------------
* More MOVEM stuff here.                       MOVEM EA,register_list
*--------------------------------------------------------------------
D_MOVEM2  SUBQ.B    #1,D1           ; Are we doing MOVEM?
          BNE       L4_E            ; It appears not, skip
          TST.B     D7              ; Bit 7 should be set at least
          BPL       ILL_INST        ; Unset, illegal line 4
          LEA       MN_MOVEM,A1     ; 'MOVEM'
          JSR       COPY_LP         ; Buffer opcode
          JSR       SIZE_WL         ; Buffer size
          JSR       ADV_W           ; Get register list word into D1
          MOVE.W    D1,D4           ; Save register list for now
          JSR       GET_MR          ; Get EA mode in D6, REG in D5
          CMPI.B    #2,D6           ; Mode 0 and 1 are illegal
          BLT.S     MOVEM_ER        ; Mode 0 and 1
          CMPI.B    #4,D6           ; -(An) mode?
          BEQ.S     MOVEM_ER        ; Yes, not allowed either
          CMPI.B    #10,D6          ; Immediate mode?
          BGT.S     MOVEM_ER        ; That's illegal too
          JSR       EA_DECODE       ; Decode EA
          BRA.S     D_MOVEM4        ; Go do the register list    

*--------------------------------------------------------------------
* Illegal MOVEM addressing modes turn up here.
*--------------------------------------------------------------------
MOVEM_ER  JSR       EA_ERROR        ; Buffer a question mark for errors

*--------------------------------------------------------------------
* Buffer the comma and the following register list
*--------------------------------------------------------------------
D_MOVEM4  MOVE.B    #',',(A0)+      ; Buffer a comma
          MOVE.W    D4,D1           ; Restore register list

*--------------------------------------------------------------------
* Buffer the register list for a MOVEM opcode. D1.W is the list. D2.B
* is the register type and A0 is the buffer address for output. D0 is
* the bit counter and marks the bit we are testing in the list - it's
* always bit zero! D2 is the register type and D3 is the current 
* register number.
*
* Start with the Data registers.
*--------------------------------------------------------------------
REGLIST   MOVEQ     #0,D0           ; Bit counter
          MOVEQ     #'D',D2         ; Start with Data registers
          TST.B     D1              ; Low byte is the data register list
          BEQ.S     RL_A            ; Nothing to do for data registers
          BSR.S     REGLIST1        ; Do data registers
          TST.W     D1              ; Are we done yet?
          BEQ.S     RL_END          ; Yes, finished
          MOVE.B    #'/',(A0)+      ; Buffer a '/' between D and A registers


*--------------------------------------------------------------------
* Address registers next.
*--------------------------------------------------------------------
RL_A      MOVEQ     #'A',D2         ; Doing A registers now
          LSR.W     #8,D1           ; Shift the A byte into the low byte

*--------------------------------------------------------------------
* Process the D and the A registers in turn.
*--------------------------------------------------------------------
REGLIST1  MOVEQ     #'0',D3         ; Assume first register

RL_LP1    BTST      D0,D1           ; Test this bit (bit zero)
          BNE.S     RL_SET          ; It is a register
          ADDQ.B    #1,D3           ; Next register number
          LSR.B     #1,D1           ; Shift next register bit into bit 0
          BNE.S     RL_LP1          ; Test again

RL_END    RTS                       ; We are done here

*--------------------------------------------------------------------
* We have found a set bit in the register list. D2 is the register
* type, D3 is the register number, in ASCII.
* If the next bit is set too, we need a hyphen in the buffer
*--------------------------------------------------------------------
RL_SET    MOVE.B    D2,(A0)+        ; Buffer 'D' or 'A'
          MOVE.B    D3,(A0)+        ; Buffer register number
          LSR.B     #1,D1           ; Next register into bit zero
          BTST      D0,D1           ; Is it set too?
          BEQ.S     RL_NEXT         ; No, skip
          MOVE.B    #'-',(A0)+      ; Yes, add a hyphen to the buffer

*--------------------------------------------------------------------
* Loop around until we find the first unset register bit.
*--------------------------------------------------------------------
RL_LP2    ADDQ.B    #1,D3           ; Next Register number
          LSR.B     #1,D1           ; Next register bit into bit 0
          BTST      D0,D1           ; Is it set?
          BNE.S     RL_LP2          ; Yes, keep looking
          MOVE.B    D2,(A0)+        ; Not set, buffer register type
          MOVE.B    D3,(A0)+        ; And register number.

*--------------------------------------------------------------------
* No, or the end of, consecutive bits set. Buffer a '/' to separate
* non consecutive register numbers. Then loop again if not finished.
*--------------------------------------------------------------------
RL_NEXT   TST.B     D1              ; Are we done yet?
          BEQ.S     RL_END          ; Yes, exit
          MOVE.B    #'/',(A0)+      ; No, add a '/' to the buffer
          ADDQ.B    #1,D3           ; Next register number
          BRA.S     RL_LP1          ; Look for the next set register bit

*--------------------------------------------------------------------
* More filtering of line 4 opcodes here.
*--------------------------------------------------------------------
L4_E      MOVE.B    D7,D1           ; Copy opcode word
          LSR.B     #4,D1           ; Lose lowest 4 bits
          SUBQ.B    #4,D1           ; Subtract
          BLT       ILL_INST        ; -ve = Illegal line 4
          BNE.S     D_LINK          ; Suspect LINK

*--------------------------------------------------------------------
* TRAP #n here.
*--------------------------------------------------------------------
          LEA       MN_TRAP,A1      ; 'TRAP'
          JSR       COPY_LP         ; Buffer the opcode
          LEA       OPR_FLD(A6),A0  ; Adjust buffer pointer
          MOVE.B    #'#',(A0)+      ; Buffer the hash (#)
          MOVEQ     #$0F,D1         ; Mask for vector
          AND.B     D7,D1           ; D1 is the vector now
          JMP       BTOHEX          ; Buffer the vector

*--------------------------------------------------------------------
* Testing for LINK or UNLK here.
*--------------------------------------------------------------------
D_LINK    SUBQ.B    #1,D1           ; LINK or UNLK?
          BNE.S     MOVE_USP        ; No, skip

*--------------------------------------------------------------------
* LINK An,#d here.
*--------------------------------------------------------------------
          LEA       MN_LINK,A1      ; 'LINK' assumed
          BTST      #3,D7           ; TEst anyway
          BEQ.S     D_UNLK          ; 0 = UNLK, 1 = LINK
          LEA       MN_UNLK,A1      ; 'UNLK'

*--------------------------------------------------------------------
* UNLK An here.
*--------------------------------------------------------------------
D_UNLK    JSR       COPY_LP         ; Buffer LINK or UNLK
          LEA       OPR_FLD(A6),A0  ; Adjust buffer pointer
          BSR.S     ADDREG          ; Buffer the A register
          BTST      #3,D7           ; Link?
          BEQ.S     LINK_DSP        ; Yes, do the rest of LINK
          RTS                       ; UNLK - done

*--------------------------------------------------------------------
* Do the LINK displacement here.
*--------------------------------------------------------------------
LINK_DSP  MOVE.B    #',',(A0)+      ; Buffer a comma
          MOVE.B    #'#',(A0)+      ; And a hash
          JSR       ADV_W           ; Fetch the following word
          JMP       WTOHEXS         ; Do the displacement

*--------------------------------------------------------------------
* Testing for MOVE to/from USP here.
*--------------------------------------------------------------------
MOVE_USP  SUBQ.B    #1,D1           ; MOVE USP?
          BNE.S     D_4E7X          ; No, try the $4E7x opcodes next
          LEA       MN_MOVE,A1      ; 'MOVE'
          JSR       COPY_LP         ; Buffer the opcode
          LEA       OPR_FLD(A6),A0  ; Adjust the pointer
          BTST      #$03,D7         ; Direction bit
          BNE.S     L709A2          ; Skip if MOVE from USP

*--------------------------------------------------------------------
* MOVE An,USP here.
*--------------------------------------------------------------------
          BSR.S     ADDREG          ; Buffer the address register    
          MOVE.B    #$2C,(A0)+      ; Buffer a comma

*--------------------------------------------------------------------
* Buffer 'USP' and exit if we have done MOVE An,USP.
*--------------------------------------------------------------------
COPY_USP  LEA       MN_USP,A1       ; 'USP'
          JMP       COPY_LP         ; Buffer USP & exit for MOVE to USP

*--------------------------------------------------------------------
* MOVE USP,An here.
*--------------------------------------------------------------------
L709A2    BSR.S     COPY_USP        ; Buffer 'USP'
          MOVE.B    #$2C,(A0)+      ; Buffer a comma

*--------------------------------------------------------------------
* Buffer address register.
*--------------------------------------------------------------------
ADDREG    MOVEQ     #$07,D5         ; Make for the register number
          AND.B     D7,D5           ; D5 = register number
          JMP       EA_1            ; Buffer it

*--------------------------------------------------------------------
* Decode opcodes $4E70 (RESET) through $4E77 (MOVEC - MC68010) here.
*--------------------------------------------------------------------
D_4E7X    TST.B     D7              ; Bit 7 set in opcode?
          BMI.S     L709DA          ; Yes, skip to JSR or JMP opcodes
          MOVEQ     #$0F,D1         ; Lower 4 bits kept
          AND.B     D7,D1           ; Apply mask
          MOVE.B    D1,D2           ; Copy result
          CMPI.B    #$07,D2         ; MOVEC? MC68010 only
          BGT       ILL_INST        ; Yes, illegal line 4 opcode
          CMPI.B    #$04,D2         ; RTD? MC68010 only
          BEQ       ILL_INST        ; Yes, illegal line 4 opcode

*--------------------------------------------------------------------
* RESET, NOP, STOP, RTE, RTS, TRAPV, RTR opcodes here.
*--------------------------------------------------------------------
          LEA       MN_4E7X,A1      ; RESET, NOP, STOP, RTE, RTS, TRAPV, RTR
          JSR       DIS_INDEX       ; Buffer D1th instruction
          SUBQ.B    #2,D2           ; Only STOP has an operand
          BNE.S     L709D8          ; Not STOP, skip
          LEA       OPR_FLD(A6),A0  ; Adjust buffer pointer
          MOVEQ     #$01,D4         ; Force word size
          JSR       EA_B            ; Immediate Data EA

L709D8    RTS                       ; Done

*--------------------------------------------------------------------
* JSR and JMP here.
*--------------------------------------------------------------------
L709DA    MOVEQ     #$01,D1         ; Mask for size
          AND.B     D4,D1           ; Bit 6 determines opcode
          LEA       MN_JSR,A1       ; 0 = 'JSR', 1 = 'JMP'
          JSR       DIS_INDEX       ; Buffer D1th instruction
          LEA       OPR_FLD(A6),A0  ; Adjust buffer pointer
          JMP       EA_CTRL         ; Buffer control mode EA

*--------------------------------------------------------------------
* Deal with the data part for the various xxxQ instructions.
*--------------------------------------------------------------------
QUICKDATA MOVE.B    #$23,(A0)+      ; Hash (#) character
          MOVE.W    D7,D1           ; Copy opcode word
          ANDI.W    #$0E00,D1       ; Mask off bits 9-11
          ROL.W     #7,D1           ; Rotate into bits 0-2
          BNE.S     L709FE          ; Data is 1 to 7 only
          MOVEQ     #$08,D1         ; Data is zero, so actually 8

L709FE    ADDI.B    #$30,D1         ; ASCIIfy the data
          MOVE.B    D1,(A0)+        ; Buffer the data
          MOVE.B    #$2C,(A0)+      ; Buffer a comma
          RTS                       ; Done

*--------------------------------------------------------------------
* Line5 - ADDQ, Scc, DBcc, SUBQ.
*--------------------------------------------------------------------
LINE5     CMPI.B    #$03,D4         ; If size = 3, then Scc or DBcc
          BEQ.S     L70A2C          ; Scc and DBcc so skip
          LEA       MN_ADDQ,A1      ; 'ADDQ' is assumed
          BTST      #$08,D7         ; Test anyway
          BEQ.S     L70A1E          ; Correct assumption, it's ADDQ
          LEA       MN_SUBQ,A1      ; 'SUBQ' after all

L70A1E    JSR       COPY_LP         ; Buffer the opcode
          JSR       GT_SIZE         ; Buffer the dot and the size
          BSR.S     QUICKDATA       ; Buffer the 'Quick' data value
          JMP       EA_ALT          ; Do the alterable effaective address

*--------------------------------------------------------------------
* Scc and DBcc arrive here.                             DBcc Dn,label
* DBcc is dealt with here.
*--------------------------------------------------------------------
L70A2C    LEA       CONDTAB1,A1     ; Table of condition codes
          JSR       GET_MR          ; Get EA mode in D6, REG in D5
          SUBQ.B    #1,D6           ; Mode is an address register?
          BNE.S     D_SCC           ; No, it's Scc then.
          MOVE.B    #'D',(A0)+      ; DBcc, so buffer a 'D'
          MOVE.B    #'B',(A0)+      ; And a 'C'
          JSR       CONDITION       ; Then the cc part
          LEA       OPR_FLD(A6),A0  ; Position in the output buffer
          JSR       EA_0            ; Do the data register
          MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       EA_9            ; do nn(PC) finally

*--------------------------------------------------------------------
* Must be Scc.                                  Scc effective_address
*--------------------------------------------------------------------
D_SCC     MOVE.B    #'S',(A0)+      ; Buffer the 'S'
          JSR       CONDITION       ; Buffer the condition
          LEA       OPR_FLD(A6),A0  ; Position the output buffer
          JMP       EA_DALT         ; Do the effective address

*--------------------------------------------------------------------
* Line6 - Bcc, BRA, BSR.                                  Bxx.S label
* Short branches are dealt with first.
*--------------------------------------------------------------------
LINE6     MOVE.B    #'B',(A0)+      ; Buffer the 'B'
          LEA       CONDTAB2,A1     ; Condition code table
          JSR       CONDITION       ; Buffer the condition
          MOVE.B    D7,D1           ; Copy opcode word
          BEQ.S     BR_LONG         ; Zero = not short branch
          MOVE.B    #'.',(A0)+      ; Short branch, buffer the dot
          MOVE.B    #'S',(A0)+      ; And the 'S'
          LEA       OPR_FLD(A6),A0  ; Position the output buffer
          MOVE.L    A4,A1           ; Current address
          EXT.W     D1              ; Extend the displacement to word
          JMP       EA_9A           ; Work out short branch destination

*--------------------------------------------------------------------
* Bcc, BRA, BSR                                             Bxx label
*--------------------------------------------------------------------
BR_LONG   LEA       OPR_FLD(A6),A0  ; Position the output buffer
          JMP       EA_9            ; Work out nn(PC)

*--------------------------------------------------------------------
* Line7 - MOVEQ.
*--------------------------------------------------------------------
LINE7     BTST      #8,D7           ; Bit 8 must be a zero for MOVEQ
          BNE       ILL_INST        ; No, skip, illegal opcode
          LEA       MN_MOVEQ,A1     ; 'MOVEQ'
          JSR       COPY_LP         ; Buffer it
          LEA       OPR_FLD(A6),A0  ; Position the output buffer
          MOVE.B    #'#',(A0)+      ; Buffer a hash (#)
          MOVE.B    D7,D1           ; Copy opcode word
          JSR       BTOHEXS         ; Buffer a byte of data
          MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       SECNDREG        ; Buffer the destination Dn

*--------------------------------------------------------------------
* LineC - AND, MULU, ABCD, EXG, MULS.
*--------------------------------------------------------------------
LINEC     LEA       MN_LINEC,A1     ; 'MULU', 'MULS', 'AND', 'ABCD'
          MOVE.W    D7,D1           ; Copy opcode word
          ANDI.W    #$01F8,D1       ; 0000 0001 1111 1000 = bits 3-8
          LSR.W     #3,D1           ; Move to bits 0-5
          SUBI.B    #$28,D1         ; 0010 1000 = EXG Dx,Dy
          BEQ.S     EXG_DX          ; Skip
          SUBQ.B    #1,D1           ; 0010 1001 = EXG Ax,Ay
          BEQ.S     EXG_AX          ; Skip
          SUBQ.B    #8,D1           ; 0011 0001 = EXG Dx,Ay
          BNE.S     D_L8            ; But it's not, so skip.

*--------------------------------------------------------------------
* EXG Dx,Dy or EXG Dx,Ay here.
*--------------------------------------------------------------------
EXG_DX    MOVEQ     #'D',D1         ; First register is always 'D'
          BRA.S     DO_EXG          

*--------------------------------------------------------------------
* EXG Ax,Ay here.
*--------------------------------------------------------------------
EXG_AX    MOVEQ     #'A',D1         ; First register is an 'A'

*--------------------------------------------------------------------
* EXG Dx,Dy, EXG Dx,Ay or EXG Dx,Ay here.
*--------------------------------------------------------------------
DO_EXG    LEA       MN_EXG,A1       ; 'EXG'
          JSR       COPY_LP         ; Buffer the opcode
          LEA       OPR_FLD(A6),A0  ; Adjust output buffer pointer
          MOVE.B    D1,(A0)+        ; Buffer the first register 'D' or 'A'
          MOVE.W    D7,D0           ; Copy opcode word
          ANDI.W    #$0E00,D0       ; 0000 1110 0000 0000 = bits 9-11
          ROL.W     #7,D0           ; Move to bits 0-2
          ADDI.B    #'0',D0         ; ASCIIfy the register
          MOVE.B    D0,(A0)+        ; Buffer the rugister
          MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       EA_DECODE       ; Decode the destination

*--------------------------------------------------------------------
* Line8 - OR, DIVU, SBCD, DIVS.
*--------------------------------------------------------------------
LINE8     LEA       MN_LINE8,A1     ; 'DIVU', 'DIVS', 'OR', 'SBCD'
D_L8      CMPI.B    #3,D4           ; Size 3 = DIVx
          BEQ.S     MUL_DIV         ; Skip to DIVx
          MOVEQ     #2,D1           ; Assume 'OR' now
          BTST      #8,D7           ; Check anyway

*--------------------------------------------------------------------
* I'm not convinced yet. OR and SBCD come here. Bit 8 is only 0 (OR)
* if it's OR EA,Dn if it's OR DN,EA then bit 8 is a 1. Bit 8 is a 1
* always for SBCD and sometimes for an OR. Hmmm.  TODO => ????
*--------------------------------------------------------------------
          BEQ.S     OR_AND          ; It's OR if it's zero TODO => ????
          JSR       GET_MR          ; Get EA mode in D6, REG in D5
          CMPI.B    #2,D6           ; TODO => ????
          BGE       SUB_DX

*--------------------------------------------------------------------
* Must be SBCD here.                                       
*--------------------------------------------------------------------
D_SBCD    MOVEQ     #3,D1           ; Must be 'SBCD'
          JSR       DIS_INDEX       ; Buffer D1th instruction
          LEA       OPR_FLD(A6),A0  ; Adjust output buffer pointer

DX_OR_MEM LEA       EA_0,A2         ; Assume Dx,Dy
          TST.B     D6              ; Check anyway
          BEQ.S     SBCD_DATA       ; Mode 0 = SBCD Dx,Dy
          LEA       EA_4,A2         ; Must be -(Ax),-(Ay)

*--------------------------------------------------------------------
* SBCD data here is either Dx,Dy or -(Ax),Ay). Other opcodes come 
* here for the same reason.
*--------------------------------------------------------------------
SBCD_DATA JSR       (A2)            ; Do first operand
          MOVE.W    D7,D5           ; Copy opcode word
          ANDI.W    #$0E00,D5       ; 0000 1110 0000 0000 = bits 9-11
          ROL.W     #7,D5           ; Shift to bits 0-2
          MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       (A2)            ; Do second operand

*--------------------------------------------------------------------
* MULU, MULS, DIVU, DIVS here.
*--------------------------------------------------------------------
MUL_DIV   MOVEQ     #0,D1           ; Assume MULU/DIVU
          MOVEQ     #1,D4           ; Size is word, always
          BTST      #8,D7           ; xxxU = 0, xxxS = 1
          BEQ.S     MULU_DIVU       ; Must be Unsigned
          MOVEQ     #1,D1           ; Assume MULS/DIVS

*--------------------------------------------------------------------
* Buffer the MULx or DIVx opcode.
*--------------------------------------------------------------------
MULU_DIVU JSR       DIS_INDEX       ; Buffer D1th instruction
          LEA       OPR_FLD(A6),A0  ; Adjust output buffer position
          BRA.S     OR_DIV          ; Skip

*--------------------------------------------------------------------
* OR and AND come here.
*--------------------------------------------------------------------
OR_AND    JSR       DIS_INDEX       ; Buffer D1th instruction
          JSR       GT_SIZE         ; Buffer the dot and the size

*--------------------------------------------------------------------
* Common code for MULx, DIVx, OR, AND.
*--------------------------------------------------------------------
OR_DIV    JSR       EA_DATA         ; Get EA mode and register
          MOVE.B    #',',(A0)+      ; Buffer a comma
          JMP       SECNDREG        ; Do the destination

*--------------------------------------------------------------------
* Line9 - SUBA, SUB, SUBX.
*--------------------------------------------------------------------
LINE9     LEA       MN_LINE9,A1     ; 'SUBA', 'SUB', 'SUBX'
          BRA.S     D_L9            ; Skip to common code

*--------------------------------------------------------------------
* LineD - ADDA, ADD, ADDX.
*--------------------------------------------------------------------
LINED     LEA       MN_LINED,A1     ; 'ADDA', 'ADD', 'ADDX'

*--------------------------------------------------------------------
* Common code for:
*
* Line9 - SUBA, SUB, SUBX.
* LineD - ADDA, ADD, ADDX.
*--------------------------------------------------------------------
D_L9      CMPI.B    #3,D4           ; Size 3 = SUBA or ADDA only
          BEQ.S     D_SUBA          ; Yes, skip
          MOVEQ     #1,D1           ; Assume SUB/ADD
          BTST      #8,D7           ; Check anyway
          BEQ.S     SUB_MEM         ; Good guess, 0 = SUB/ADD

*--------------------------------------------------------------------
* Must be SUBX or ADDX only here.                          SUBX Dy,Dx
*                                                     SUBX -(Ay),-(Ax)
*                                                          ADDX Dy,Dx
*                                                     ADDX -(Ay),-(Ax)
*--------------------------------------------------------------------
          JSR       GET_MR          ; Get EA mode in D6, REG in D5
          CMP.B     D1,D6           ; SUBX/ADDX memory to memory
          BGT.S     SUB_DX          ; Skip to SUBX/ADDX
          MOVEQ     #2,D1           ; Must be SUBX/ADDX
          JSR       DIS_INDEX       ; Buffer SUBX/ADDX instruction
          JSR       GT_SIZE         ; Buffer the dot and the size
          BRA.S     DX_OR_MEM       ; Do the operands

*--------------------------------------------------------------------
* Must be SUBA, ADDA or CMPA only here.                    SUBA EA,An
*                                                          ADDA EA,An
*                                                          CMPA EA,An
*--------------------------------------------------------------------
D_SUBA    MOVEQ     #0,D1           ; Get first opcode
          JSR       DIS_INDEX       ; Buffer D1th instruction
          MOVEQ     #1,D4           ; Assume .W
          BTST      #8,D7           ; Test size bit, 0 = W, 1 = L
          BEQ.S     SUBA_SIZE       ; Good guess, it's word
          MOVEQ     #2,D4           ; Bad guess, it's long

SUBA_SIZE JSR       GT_SIZE         ; Buffer the dot and the size
          JSR       EA_DECODE       ; Do the Effective address

SECND_ADD MOVE.B    #',',(A0)+      ; Buffer the comma
          MOVE.W    D7,D5           ; Copy opcode word
          ANDI.W    #$0E00,D5       ; Mask out register bits 9-11
          ROL.W     #7,D5           ; Rotate into bits 0-2
          JMP       EA_1            ; Buffer the address register

*--------------------------------------------------------------------
* Must be SUB, ADD or CMP here.                             SUB EA,Dn
*                                                           SUB Dn,EA
*                                                           ADD EA,Dn
*                                                           ADD Dn,EA
*                                                           CMP EA,Dn
*--------------------------------------------------------------------
SUB_MEM   JSR       DIS_INDEX       ; Buffer D1th instruction
          JSR       GT_SIZE         ; Buffer the dot and the size
          JSR       EA_DECODE       ; Do the source operand
          MOVE.B    #',',(A0)+      ; Then the comma is buffered
          JMP       SECNDREG        ; Then the destination operand

*--------------------------------------------------------------------
* Must be SUBX or ADDX only here.                          SUBX Dy,Dx
*                                                     SUBX -(Ay),-(Ax)
*                                                          ADDX Dy,Dx
*                                                     ADDX -(Ay),-(Ax)
*--------------------------------------------------------------------
SUB_DX    LEA       EA_MALT,A2      ; Do a memory alterable address

SUB_DX1   JSR       DIS_INDEX       ; Buffer D1th instruction
          JSR       GT_SIZE         ; Buffer the dot and the size
          JSR       SECNDREG        ; Do the source
          MOVE.B    #',',(A0)+      ; Buffer the comma
          JMP       (A2)            ; Do the destination 

*--------------------------------------------------------------------
* LineB - CMP, CMPA, EOR, CMPM.
*--------------------------------------------------------------------
LINEB     LEA       MN_LINEB,A1     ; 'CMPA', 'CMP', 'EOR', 'CMPM'
          CMPI.B    #3,D4           ; Size 3 = CMPA
          BEQ.S     D_SUBA          ; Common code for SUBA, ADDA, CMPA
          MOVEQ     #1,D1           ; Assume 'CMP' now CMPA has gone
          BTST      #8,D7           ; Only CMP has a zero here
          BEQ.S     SUB_MEM         ; It's CMP, skip to common code
          JSR       GET_MR          ; Get EA mode in D6, REG in D5
          MOVEQ     #2,D1           ; Assume EOR now CMPx have gone
          LEA       EA_DALT,A2      ; Do a data alterable address, later
          SUBQ.B    #1,D6           ; CMPM has mode 1
          BNE.S     SUB_DX1         ; It's not CMPM, must be EOR
          MOVEQ     #3,D1           ; Must be CMPM then
          JSR       DIS_INDEX       ; Buffer D1th instruction
          JSR       GT_SIZE         ; Buffer the dot and size
          LEA       EA_3,A2         ; Destination decode routine
          BRA       SBCD_DATA       ; Go do it

*--------------------------------------------------------------------
* LineE - Shift/Rotate instructions.
*--------------------------------------------------------------------
LINEE     LEA       MN_LINEE,A1     ; 'AS', 'LS', 'ROX', 'RO'
          CMPI.B    #3,D4           ; Size 3 = Memory shifts
          BEQ.S     SH_MEM          ; Do shift memory
          MOVEQ     #$18,D1         ; 0001 1000
          AND.B     D7,D1           ; Keep bits 3-4 of D1
          LSR.B     #3,D1           ; Shift into bits 0-1

*--------------------------------------------------------------------
* We know that D1 now has the correct opcode for a register shift:
* 00 = AS, 01 = LS, 10 = ROX, 11 = RO.             
*                                                           ASx Dx,Dy
*                                                           ASx #d,Dx
*                                                           LSx Dx,Dy
*                                                           LSx #d,Dx
*                                                          ROXx Dx,Dy
*                                                          ROXx #d,Dx
*                                                           ROx Dx,Dy
*                                                           ROx #d,Dx
*--------------------------------------------------------------------
          JSR       DIS_INDEX       ; Buffer D1th instruction
          BSR.S     DIRECTION       ; Buffer the direction
          JSR       GT_SIZE         ; Buffer the dot and the size
          BTST      #5,D7           ; Check method
          BEQ.S     SH_IMM          ; Shift by immediate data
          JSR       SECNDREG        ; Shifting by register
          MOVE.B    #',',(A0)+      ; Buffer a comma
          BRA.S     SH_REG          ; And the shifted register

*--------------------------------------------------------------------
* We are doing a shift by immediate data to define the count.
*--------------------------------------------------------------------
SH_IMM    JSR       QUICKDATA       ; Buffer the 'Quick' data value

*--------------------------------------------------------------------
* Deal with the register being shifted here.
*--------------------------------------------------------------------
SH_REG    MOVE.B    #'D',(A0)+      ; Buffer a 'D' 
          MOVEQ     #7,D0           ; Mask lower three bits
          AND.B     D7,D0           ; Get the register number
          ADDI.B    #'0',D0         ; ASCIIfy it
          MOVE.B    D0,(A0)+        ; Buffer it
          RTS                       ' Done

*--------------------------------------------------------------------
* Memory shifts are one bit only.
*                                                              ASx EA
*                                                              LSx EA
*                                                             ROXx EA
*                                                               RO EA
*--------------------------------------------------------------------
SH_MEM    MOVE.W    D7,D1           ; Copy opcode word
          ANDI.W    #$0600,D1       ; 0000 0110 0000 0000 = bits 9-10
          ROL.W     #7,D1           ; Bits 9-10 to bits 0-1
          JSR       DIS_INDEX       ; Buffer D1th instruction
          BSR.S     DIRECTION       ; Buffer the direction
          LEA       OPR_FLD(A6),A0  ; Adjust output buffer position
          JMP       EA_MALT         ; Buffer the effective address

*--------------------------------------------------------------------
* Adds the direction to the opcode in the buffer.
*--------------------------------------------------------------------
DIRECTION MOVEQ     #'R',D0         ; Assume right
          BTST      #8,D7           ; Check
          BEQ.S     DIR_MOVE        ; Correct guess, it's right
          MOVEQ     #'L',D0         ; Wrong, it's left

DIR_MOVE  MOVE.B    D0,(A0)+        ; Buffer the direction
          RTS                       ; Done

*--------------------------------------------------------------------
* The following table of zero terminated opcodes is used to copy the
* instruction text, or part thereof, into the output buffer when the
* instruction has been decoded enough to allow the instruction text
* to be determined. 
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

* MULTIMON
* QL MONITOR/DISASSEMBLER
* V1.0 - JANUARY 24, 1986

          INCLUDE   FDK1_QDOS_IN

DATASPACE EQU       512
IM_D0     EQU       0    IMAGE STORAGE FOR D0-A7
IM_USP    EQU       60
IM_SSP    EQU       78
IM_PC     EQU       64
IM_SR     EQU       76
BASE_PNT  EQU       68
TOP_PNT   EQU       72
JBPNT     EQU       186
OWN_JB    EQU       182
EXTAB     EQU       82   EXCEPTION TABLE
EXTABEND  EQU       158
PROMPTWND EQU       158  CHANNEL ID'S FOR WND'S
REGWND    EQU       162
MEMWND    EQU       166
CMDWND    EQU       170
DISWND    EQU       174
AUXWND    EQU       178
MATHSTK   EQU       194
MEMPTR    EQU       190
REGPTR    EQU       198
BRKPTAB   EQU       200
RELMOD    EQU       BRKPTAB+60
DISMOD    EQU       BRKPTAB+61
OPCODEFLG EQU       BRKPTAB+62
WRKSPOV   EQU       BRKPTAB+63
DATATBL   EQU       BRKPTAB+64
LBL_TBL   EQU       BRKPTAB+68
WRKSPTR   EQU       BRKPTAB+72
WRK_END   EQU       BRKPTAB+76
DISFRST   EQU       BRKPTAB+80
DISLAST   EQU       BRKPTAB+84
DISBUF    EQU       BRKPTAB+88
LBL_FLD   EQU       DISBUF+27
MNFIELD   EQU       DISBUF+34
OPR_FLD   EQU       DISBUF+42
DISBUFLEN EQU       82
BKPTABSIZ EQU       10
HEXSTR    EQU       DISBUF+DISBUFLEN

          XDEF      BASE_PNT,TOP_PNT,DISMOD,OPCODEFLG,WRKSPOV,RELMOD
          XDEF      DATATBL,LBL_TBL,WRKSPTR,WRK_END,DISFRST,DISLAST
          XDEF      DISBUF,LBL_FLD,MNFIELD,OPR_FLD,DISBUFLEN

          XREF      DISASSEM
          XREF      CN_ADDR
          XREF      CN_HEXB
          XREF      CN_HEXL
          XREF      ADD_WRK

          DATA      DATASPACE

          SECTION   MON_CODE

*--------------------------------------------------------------------
* This code can be LRESPR'd, in which case we get the 'MON' command,
* or, can be EXEC'd in which case, we get a job. Smart!
*--------------------------------------------------------------------
* Standard QDOS job header. 
*--------------------------------------------------------------------
          BRA.S     START

*--------------------------------------------------------------------
* Use the filler long word to hold the base address of the job's 
* dataspace - if it was stared by EXEC. Otherwise, it's random.
*--------------------------------------------------------------------
SYSVARS   DS.L      1

          DC.W      $4AFB,8
          DC.B      'MULTIMON'

*--------------------------------------------------------------------
* Call MT_INF to get the current jobid in D1.L. If this is zero, we
* are in SuperBASIC so link MON in as a new procedure. Otherwise, we
* have been EXEC'd and are running as a standalone job.
*--------------------------------------------------------------------
START     MOVEQ     #MT_INF,D0
          TRAP      #1
          TST.L     D1
          BNE.S     START2
          LEA       PROCTAB,A1
          MOVE.W    BP_INIT,A2
          JMP       (A2)

*--------------------------------------------------------------------
* If we arrive here, we are running as a standalone job:
*
* A4.L = Start of dataspace, relative to A6.L.
* A5.L = End of dataspace, relative to A6.L. (One byte past the end!)
* A6.L = JB_END.
* A7 = USP
*
*--------------------------------------------------------------------
* Point A6.L at the absolute address of the dataspace area for this
* job, then save it in SYSVARS.
*--------------------------------------------------------------------
START2    ADDA.L    A4,A6
          LEA       SYSVARS,A1
          MOVE.L    A6,(A1)
          TRAP      #0
          MOVE.L    $28064,OWN_JB(A6)
          MOVE.L    $28068,A0
          BSR       EXAM_REGS
          ANDI      #$DFFF,SR
          CLR.L     MEMPTR(A6)
          ST        RELMOD(A6)
          LEA       EXTABEND(A6),A7
          MOVEQ     #10,D0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
SETTRAPS  PEA       EXBRKPNT
          DBF       D0,SETTRAPS
          PEA       EXINTL7
          PEA       EXTRACE
          PEA       EXPRIVV
          PEA       EXTRAPV
          PEA       EXCHK
          PEA       EXDIVZER
          PEA       EXILLINST
          PEA       EXADDERR
          MOVE.L    A7,A1
          LEA       DATASPACE(A6),A7
          MOVEQ     #-1,D1
          MOVEQ     #MT_TRAPV,D0
          TRAP      #1

*--------------------------------------------------------------------
* There are 5 separate windows to be opened at startup. D7 has the
* count and A4 points at the first one. 
*--------------------------------------------------------------------
          MOVEQ     #5,D7
          LEA       WNDPRMS,A4
          LEA       PROMPTWND(A6),A5

*--------------------------------------------------------------------
*--------------------------------------------------------------------
OPEN_LP   MOVE.L    A4,A0
          LEA       WNDPAR1,A1
          TST.W     D7
          BNE.S     DO_OPEN
          LEA       WNDPAR2,A1

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DO_OPEN   MOVE.W    UT_WINDW,A2  SET UP DISPLAY WND'S
          JSR       (A2)
          BNE       QMON_1       QUIT IF ERR
          MOVE.L    A0,(A5)+     STORE CHAN ID
          MOVEQ     #3,D0
          ADD.W     (A4),D0
          BCLR      #0,D0
          ADDA.W    D0,A4        NEXT CHAN PRMS
          DBF       D7,OPEN_LP
          CLR.W     REGPTR(A6)
          CLR.W     HEXSTR(A6)
          LEA       BRKPTAB(A6),A0
          MOVEQ     #BKPTABSIZ-1,D0
CLRBKTAB  CLR.L     (A0)+
          CLR.W     (A0)+        CLEAR BREAKPOINT TABLE
          DBF       D0,CLRBKTAB
BAS_ENT2  LEA       SIGNON,A1    DISPLAY SIGNON ON FIRST ENTRY
          BRA       MAIN_ERR

BAS_ENT   MOVEQ     #-1,D1
          LEA       START,A1
          MOVEQ     #0,D2
          MOVE.L    #DATASPACE,D3
          MOVEQ     #MT_CJOB,D0
          TRAP      #1
          TST.L     D0
          BNE.S     BAS_QUIT
          MOVEQ     #32,D2
          MOVEQ     #-1,D3
          MOVEQ     #MT_ACTIV,D0
          TRAP      #1
BAS_QUIT  RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
PROCTAB   DC.W      1
          DC.W      BAS_ENT-*
          DC.B      3,'MON'
          DS.W      0
          DC.W      0,0,0

*--------------------------------------------------------------------
* The uppermost window displays a minilam help prompt all the time.
*--------------------------------------------------------------------
WNDPRMS   DC.W      16
          DC.B      'SCR_448X12A32X16'  PROMPT WINDOW
          DS.W      0

*--------------------------------------------------------------------
* The biggest window is to display the registers and the 8 bytes of
* RAM around each of the An registers. Also seen here is:
* 
* SP = Suppervisor SP.
* A7 = User SP.
* BP = Job start address.
* TP = Job end address.
* REL ON|OFF = Are addresses within the range BP to TP shown as 
*              relative or absolute addresses. Absolute are only the
*              lower 5 digits though.
*--------------------------------------------------------------------
          DC.W      17
          DC.B      'SCR_448X112A32X28' REGISTER WINDOW
          DS.W      0

*--------------------------------------------------------------------
* The two line MEMORY WINDOW displays 17 byes around the address of
* the memory pointer. There are 8 below and 8 above, which is 17 as
* the current MP is there too, and highlighted.
*--------------------------------------------------------------------
          DC.W      17
          DC.B      'SCR_448X22A32X140' MEMORY WINDOW
          DS.W      0

*--------------------------------------------------------------------
* The COMMAND WINDOW is where commands are entered and where the
* sign on message is displayed at startup.
*--------------------------------------------------------------------
          DC.W      17
          DC.B      'CON_448X42A32X174' COMMAND WINDOW
          DS.W      0

*--------------------------------------------------------------------
* This window is above the COMMAND WINDOW and displays a disassembly
* of the instruction at the current MP's address.
*--------------------------------------------------------------------
          DC.W      17
          DC.B      'SCR_448X12A32X162' DISASSEM WINDOW
          DS.W      0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
          DC.W      17
          DC.B      'SCR_448X190A32X27' AUX WINDOW
          DS.W      0

*--------------------------------------------------------------------
* Window parameters for the main windows:
*
* BORDER COLOUR = RED
* BORDER WIDTH = 1
* PAPER/STRIP COLOUR = BLACK
* INK COLOUR = WHITE
*--------------------------------------------------------------------
WNDPAR1   DC.B      2,1,0,7

*--------------------------------------------------------------------
* Window parameters for the help window:
*
* BORDER COLOUR = BLACK
* BORDER WIDTH = 0
* PAPER/STRIP COLOUR = RED
* INK COLOUR = WHITE
*--------------------------------------------------------------------
WNDPAR2   DC.B      0,0,2,7

*--------------------------------------------------------------------
* A small sign on message displayed at startup in the COMMAND WINDOW.
*--------------------------------------------------------------------
SIGNON    DC.W      39
          DC.B      'MULTIMON V2.1',10
          DC.B      ' 1986, 87 JAN BREDENBEEK'   ; CHR$(127) (C)
          DS.W      0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
SAVREGS   MOVE.L    A6,-(A7)
          MOVE.L    $28064,A6
          MOVE.L    (A6),A6
          MOVEM.L   D0-D7/A0-A5,$20(A6)
          MOVE.L    (A7)+,$58(A6)
          MOVE      USP,A1
          MOVE.L    A1,$5C(A6)
          MOVE.L    (A7)+,A5
          MOVE.W    (A7)+,$60(A6)
          MOVE.L    (A7)+,$62(A6)
          MOVE.L    $28064,A0
          MOVE.L    SYSVARS,A6
          BSR       EXAM_REGS
          LEA       DATASPACE(A6),A0
          MOVE      A0,USP
          MOVE.L    $28064,A0
          MOVE.L    OWN_JB(A6),A2
          CMPA.L    A0,A2
          BEQ.S     GO_MON
          MOVE.L    (A0),A0
          MOVE.W    #-1,$14(A0)
          SF        $17(A0)
GO_MON    MOVE.L    A2,$28064
          MOVE.L    (A2),A2
          CLR.W     $14(A2)
          MOVE.L    $0C(A2),D0
          BEQ.S     GO_MON1
          MOVE.L    D0,A2
          SF        (A2)
GO_MON1   MOVE      #$0000,SR
          JMP       (A5)

*--------------------------------------------------------------------
*--------------------------------------------------------------------
RESTREGS  MOVEQ     #0,D0
          TRAP      #1
          TRAP      #0
          MOVE.L    JBPNT(A6),A0
          TST.B     (A0)
          BLT.S     RR_BADJB
          MOVE.L    OWN_JB(A6),A2
          CMPA.L    A0,A2
          BEQ.S     RR_BADJB
          MOVE.L    A0,$28064
          MOVE.L    (A0),A0
          MOVE.L    (A2),A2
          MOVE.W    #-2,$14(A2)
          LEA       MAIN_REST,A1
          MOVE.L    A1,$62(A2)
          CLR.W     $60(A2)
          TAS       $17(A0)
          MOVE.L    D1,$18(A0)
          TST.B     $13(A0)
          BNE.S     REL_JB
          MOVE.B    #32,$13(A0)
REL_JB    CLR.W     $14(A0)
          MOVE.L    IM_PC(A6),-(A7)
          MOVE.W    IM_SR(A6),-(A7)
          MOVE.L    IM_USP(A6),A1
          MOVE      A1,USP
          MOVEM.L   (A6),D0-D7/A0-A6
          RTE
RR_BADJB  ANDI      #$DFFF,SR
          MOVE.L    CMDWND(A6),A0
          MOVEQ     #10,D1
          MOVEQ     #-1,D3
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          MOVEQ     #-2,D0
          BRA       PRT_ERR

*--------------------------------------------------------------------
*--------------------------------------------------------------------
*READ LINE FROM KBD

RDSTRING  LEA       DISBUF+2(A6),A2
          MOVEQ     #DISBUFLEN-2,D2
          BSR.S     RDLIN_2
          SUBQ.W    #1,D1
          MOVE.W    D1,-(A1)
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
READ_LINE LEA       DISBUF(A6),A2
          MOVEQ     #DISBUFLEN,D2
RDLIN_2   MOVE.L    CMDWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #':',D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          MOVE.L    A2,A1
          MOVEQ     #IO_FLINE,D0
          TRAP      #3
          MOVE.L    A2,A1
          RTS

*--------------------------------------------------------------------
* Prompt the user to supply an address. This may be as follows:
*
* %bbbbbbb       = binary - 32 bits max
* &nnnnnnn       = decimal
* hhhhhhhh       = hexadecimal - 8 digits max
* M              = Current memory pointer
* S              = Base pointer = BP = Start of job
* (Rn.s,Rm.s...) = Add registers and use result as address.
*
* Returns the address in D1.L and sets D0 and the Z flag to indicate
* errors.
*--------------------------------------------------------------------
GET_ADDR  MOVEM.L   D2-D4/A0-A1,-(A7)
          BSR.S     READ_LINE
          MOVEQ     #0,D4
GTAD_LP   SF        D3
          MOVE.B    (A1),D0
          SUBI.B    #'+',D0
          BEQ.S     GTAD_2
          SUBQ.B    #2,D0
          BNE.S     GTAD_3
          ST        D3
GTAD_2    ADDQ.W    #1,A1
GTAD_3    MOVE.B    (A1),D0
          CMPI.B    #10,D0
          BEQ       GTAD_E
          CMPI.B    #'%',D0         ; Get address in binary
          BEQ.S     GTAD_P
          CMPI.B    #'&',D0         ; Get address in decimal
          BEQ.S     GTAD_D
          CMPI.B    #'(',D0         ; Get address from a register addition
          BEQ.S     GTAD_B          ; expression like (A1,A2.W...)
          ANDI.B    #$DF,D0
          CMPI.B    #'M',D0         ; Current Memory Pointer value
          BEQ.S     GTAD_M
          CMPI.B    #'S',D0         ; Start of job = BP in Register Window
          BEQ.S     GTAD_S
          BSR       READHEX         ; Get address in hexadecimal. (Default)
          BNE       GTAD_RTS
          BRA.S     GTAD_4
GTAD_D    ADDQ.W    #1,A1
          BSR       READDEC
          BRA.S     GTAD_P1
GTAD_P    ADDQ.W    #1,A1
          BSR       READBIN
GTAD_P1   BNE.S     GTAD_RTS
          BRA.S     GTAD_4
GTAD_M    MOVE.L    MEMPTR(A6),D1
          BRA.S     GTAD_5
GTAD_S    MOVE.L    BASE_PNT(A6),D1
GTAD_5    ADDQ.W    #1,A1
GTAD_4    BSR.S     ADDVAL
          BRA.S     GTAD_LP
GTAD_B    MOVEQ     #0,D1
GTAD_B_L  ADDQ.W    #1,A1
          MOVEQ     #$DF,D0
          AND.B     (A1)+,D0
          MOVEQ     #$20,D2
          SUBI.B    #'A',D0
          BEQ.S     GTAD_6
          MOVEQ     #0,D2
          SUBQ.B    #3,D0
          BNE.S     GTAD_ERR
GTAD_6    MOVE.B    (A1)+,D0
          SUBI.B    #'0',D0
          BLT.S     GTAD_ERR
          CMPI.B    #7,D0
          BGT.S     GTAD_ERR
          LSL.B     #2,D0
          ADD.B     D0,D2
          CMPI.B    #'.',(A1)
          BNE.S     GTAD_IL
          ADDQ.W    #1,A1
          MOVEQ     #$DF,D0
          AND.B     (A1)+,D0
          CMPI.B    #'L',D0
          BEQ.S     GTAD_IL
          CMPI.B    #'W',D0
          BNE.S     GTAD_ERR
          MOVE.W    2(A6,D2.W),D0
          EXT.L     D0
          ADD.L     D0,D1
          BRA.S     GTAD_COM
GTAD_IL   ADD.L     0(A6,D2.W),D1
GTAD_COM  CMPI.B    #',',(A1)
          BEQ.S     GTAD_B_L
          CMPI.B    #')',(A1)+
          BNE.S     GTAD_ERR
          BRA       GTAD_4
GTAD_E    TST.B     D3
          BNE.S     GTAD_ERR
GTAD_OK   MOVE.L    D4,D1
          MOVEQ     #0,D0
          BRA.S     GTAD_RTS
GTAD_ERR  MOVEQ     #-17,D0
GTAD_RTS  MOVEM.L   (A7)+,D2-D4/A0-A1
          TST.L     D0
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
ADDVAL    TST.B     D3
          BEQ.S     ADDVAL_1
          NEG.L     D1
ADDVAL_1  ADD.L     D1,D4
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
READHEX   MOVEQ     #0,D1
          MOVEQ     #0,D0
          MOVE.L    A1,A0
GHEXLP    MOVE.B    (A1),D0
          CMPI.B    #'0',D0
          BLT.S     GHEX_END
          CMPI.B    #'9',D0
          BLE.S     GHEXADD
          CMPI.B    #'A',D0
          BLT.S     GHEX_END
          ANDI.B    #$DF,D0
          CMPI.B    #'F',D0
          BGT.S     GHEX_END
          SUBQ.B    #7,D0
GHEXADD   SUBI.B    #'0',D0
          LSL.L     #4,D1
          ADD.L     D0,D1
          ADDQ.W    #1,A1
          BRA.S     GHEXLP
GHEX_END  CMPA.L    A0,A1
          BEQ.S     GHEX_ERR
          MOVEQ     #0,D0
          RTS

GHEX_ERR  MOVEQ     #-17,D0
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
READDEC   MOVEQ     #0,D1
          MOVEQ     #0,D0
          MOVE.L    A1,A0
RDEC_LOOP MOVE.B    (A1),D0
          SUBI.B    #'0',D0
          BLT.S     GHEX_END
          CMPI.B    #10,D0
          BGE.S     GHEX_END
          MOVE.L    D1,D2
          LSL.L     #2,D1
          ADD.L     D2,D1
          ADD.L     D1,D1
          ADD.L     D0,D1
          ADDQ.W    #1,A1
          BRA.S     RDEC_LOOP

*--------------------------------------------------------------------
*--------------------------------------------------------------------
READBIN   MOVEQ     #0,D1
          MOVEQ     #0,D0
          MOVE.L    A1,A0
RDBIN_LP  MOVE.B    (A1),D0
          SUBI.B    #'0',D0
          BLT       GHEX_END
          CMPI.B    #1,D0
          BGT       GHEX_END
          ADD.L     D1,D1
          ADD.L     D0,D1
          ADDQ.W    #1,A1
          BRA.S     RDBIN_LP

*--------------------------------------------------------------------
*--------------------------------------------------------------------
*PROMPT WINDOW HANDLER

DSPROMPT  MOVE.L    PROMPTWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVEQ     #1,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3
          LEA       PROMPTMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
PROMPTMSG DC.W      45
          DC.B      'F1 = Help  F2 = Memory Dump  F3 = Disassemble'
          DS.W      0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
*REGISTER WINDOW HANDLER

DSPADDREG MOVE.W    CN_ITOHL,A2
          JSR       (A2)
          ADDQ.W    #6,A0
          MOVE.L    -4(A6,A1.W),A3
          TST.B     RELMOD(A6)
          BEQ.S     DSPA_SAV
          CMPA.W    #$3C,A1
          BGE.S     DSPA_SAV
          MOVE.L    BASE_PNT(A6),A2
          ADDA.L    A3,A2
          CMPA.L    TOP_PNT(A6),A2
          BCC.S     DSPA_SAV
          ADDA.L    BASE_PNT(A6),A3
DSPA_SAV  MOVE.W    A1,-(A7)
          MOVEQ     #7,D6
D_AR_LP   LEA       MATHSTK,A1
          MOVE.B    (A3)+,0(A6,A1.L)
          ADDQ.W    #1,A0
          MOVE.W    CN_ITOHB,A2
          JSR       (A2)
          DBF       D6,D_AR_LP
          MOVE.W    (A7)+,A1
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DSPREG    SUBA.L    A1,A1
          LEA       REGMSG+1,A0
          SUBA.L    A6,A0
          MOVEQ     #7,D7
DSPR_LP   ADDQ.W    #4,A0
          MOVE.W    CN_ITOHL,A2
          JSR       (A2)
          ADDQ.W    #5,A0
          ADDA.W    #7*4,A1
          BSR.S     DSPADDREG
          SUBA.W    #8*4,A1
          DBF       D7,DSPR_LP
          ADDQ.W    #4,A0
          LEA       IM_SSP,A1
          MOVE.W    CN_ITOHL,A2
          JSR       (A2)
          ADDQ.W    #5,A0
          LEA       IM_PC,A1
          BSR.S     DSPADDREG
          ADDA.W    #31,A0
          MOVE.W    CN_ITOHL,A2
          JSR       (A2)
          ADDQ.W    #5,A0
          MOVE.W    CN_ITOHL,A2
          JSR       (A2)
          ADDQ.W    #4,A0
          MOVE.W    CN_ITOBW,A2
          JSR       (A2)
          MOVE.L    REGWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVEQ     #1,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3
          LEA       REGMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          LEA       DISBUF(A6),A0
          MOVE.L    #'JB  ',(A0)
          ADDQ.W    #3,A0
          MOVE.L    JBPNT(A6),D1
          MOVE.L    D1,A1
          SUB.L     $28068,D1
          LSR.W     #2,D1
          MOVE.L    (A1),A1
          SWAP      D1
          MOVE.W    $10(A1),D1
          SWAP      D1
          JSR       CN_HEXL
          MOVE.L    REGWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #27,D1
          MOVEQ     #10,D2
          MOVEQ     #SD_POS,D0
          TRAP      #3
          LEA       DISBUF(A6),A1
          MOVEQ     #11,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          MOVEQ     #40,D1
          MOVEQ     #SD_TAB,D0
          TRAP      #3
          LEA       DISBUF(A6),A1
          MOVE.L    #'REL ',(A1)
          MOVE.L    #'OFF ',D1
          TST.B     RELMOD(A6)
          BEQ.S     PR_REL
          MOVE.L    #'ON  ',D1
PR_REL    MOVE.L    D1,4(A1)
          MOVEQ     #7,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          MOVEQ     #'>',D4
          BRA.S     DSPREGP

*--------------------------------------------------------------------
*--------------------------------------------------------------------
          SECTION   MON_END

REGMSG    DC.W      REGEND-REGMSG-2
          DC.B      'D0 00000000  A0 00000000  (A0) 00 00 00 00 00 00 00 00',10
          DC.B      'D1 00000000  A1 00000000  (A1) 00 00 00 00 00 00 00 00',10
          DC.B      'D2 00000000  A2 00000000  (A2) 00 00 00 00 00 00 00 00',10
          DC.B      'D3 00000000  A3 00000000  (A3) 00 00 00 00 00 00 00 00',10
          DC.B      'D4 00000000  A4 00000000  (A4) 00 00 00 00 00 00 00 00',10
          DC.B      'D5 00000000  A5 00000000  (A5) 00 00 00 00 00 00 00 00',10
          DC.B      'D6 00000000  A6 00000000  (A6) 00 00 00 00 00 00 00 00',10
          DC.B      'D7 00000000  A7 00000000  (A7) 00 00 00 00 00 00 00 00',10
          DC.B      'SP 00000000  PC 00000000  (PC) 00 00 00 00 00 00 00 00',10
          DC.B      '   T S  III   XNZVC        BP 00000000  TP 00000000',10
          DC.B      'SR 0000000000000000'
REGEND    EQU       *
          DC.W      0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
          SECTION   MON_CODE

*CHANGE REGPTR ROUTINES

RP_ADD1   MOVEQ     #4,D5
          BRA.S     RP_ADJ
RP_ADD8   MOVEQ     #8*4,D5
          BRA.S     RP_ADJ
RP_SUB1   MOVEQ     #-4,D5
          BRA.S     RP_ADJ
RP_SUB8   MOVEQ     #-8*4,D5
RP_ADJ    MOVEQ     #$20,D4
          BSR.S     DSPREGP
          MOVE.W    REGPTR(A6),D0
          MOVEQ     #80,D1
          ADD.W     D5,D0
          BGE.S     RP_UPPER
          ADD.W     D1,D0
RP_UPPER  CMP.W     D1,D0
          BLT.S     RP_STORE
          SUB.W     D1,D0
RP_STORE  MOVE.W    D0,REGPTR(A6)
          MOVEQ     #'>',D4
          BSR.S     DSPREGP
          BRA       MAIN_1

*--------------------------------------------------------------------
*--------------------------------------------------------------------
*PRINT REGISTER POINTER

DSPREGP   MOVE.L    REGWND(A6),A0
          MOVEQ     #-1,D3
          CMPI.B    #$20,D4
          BEQ.S     DSPRSP
          MOVEQ     #2,D1
          MOVEQ     #SD_SETST,D0
          TRAP      #3
DSPRSP    MOVE.W    REGPTR(A6),D0
          MOVEM.W   POSTABLE(PC,D0.W),D1-D2
          MOVEQ     #SD_POS,D0
          TRAP      #3
          MOVE.B    D4,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          MOVEQ     #0,D1
          MOVEQ     #SD_SETST,D0
          TRAP      #3
          RTS

*--------------------------------------------------------------------
* The position table, x,y, where the '>' cursor will be placed in the
* REGISTER WINDOW when the user presses the ALT Arrow keys to move
* to the desired register.
*
* Using ALT DOWN We go from D0 down to D7, then from A0 to A7, then PC,
* then BP, TP, SR and back to D0 again. ALT UP is the reverse.
*
* Using ALT LEFT we go from D0 to A0 to PC to D4 to A4 to D0. ALT 
* RIGHT is the revesre. Weird!
*--------------------------------------------------------------------
POSTABLE  DC.W      2,0,2,1,2,2,2,3,2,4,2,5,2,6,2,7
          DC.W      12,0,12,1,12,2,12,3,12,4,12,5,12,6,12,7,12,8,26,9,39,9,2,10

*--------------------------------------------------------------------
*--------------------------------------------------------------------
*MEMORY POINTER WINDOW HANDLER

DSPMEM    MOVE.L    MEMWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVEQ     #1,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3
          LEA       DISBUF(A6),A0
          MOVE.L    MEMPTR(A6),A4
          SUBQ.W    #8,A4
          MOVE.L    A4,D1
          JSR       CN_ADDR
          MOVE.L    MEMWND(A6),A0
          MOVEQ     #'>',D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          LEA       DISBUF(A6),A1
          MOVEQ     #5,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          MOVEQ     #15,D7
DM1_LP    ADDQ.W    #1,A4
          MOVEQ     #$20,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          LEA       DISBUF(A6),A0
          MOVE.L    A4,D1
          TST.B     RELMOD(A6)
          BEQ.S     DM_CONV
          CMP.L     BASE_PNT(A6),D1
          BLO.S     DM_CONV
          CMP.L     TOP_PNT(A6),D1
          BHS.S     DM_CONV
          SUB.L     BASE_PNT(A6),D1
DM_CONV   JSR       CN_HEXB
          MOVE.L    MEMWND(A6),A0
          CMPA.L    MEMPTR(A6),A4
          BNE.S     DM_PRT
          MOVEQ     #0,D1
          MOVEQ     #SD_SETIN,D0
          TRAP      #3
          MOVEQ     #7,D1
          MOVEQ     #SD_SETST,D0
          TRAP      #3
DM_PRT    LEA       DISBUF(A6),A1
          MOVEQ     #2,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          MOVEQ     #7,D1
          MOVEQ     #SD_SETIN,D0
          TRAP      #3
          MOVEQ     #0,D1
          MOVEQ     #SD_SETST,D0
          TRAP      #3
          DBF       D7,DM1_LP
          MOVEQ     #3,D1
          MOVEQ     #1,D2
          MOVEQ     #SD_POS,D0
          TRAP      #3
          MOVE.L    MEMPTR(A6),A4
          SUBQ.W    #8,A4
          MOVEQ     #16,D7
DM2_LP    MOVEQ     #$20,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          LEA       DISBUF(A6),A0
          MOVE.B    (A4)+,D1
          JSR       CN_HEXB
          MOVE.L    MEMWND(A6),A0
          LEA       DISBUF(A6),A1
          MOVEQ     #2,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          DBF       D7,DM2_LP
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
*DISASSEMBLY WINDOW HANDLER

DSPDIS    MOVE.L    DISWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVEQ     #1,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3
          MOVE.L    MEMPTR(A6),A4
          ST        DISMOD(A6)
          JSR       DISASSEM
          MOVE.L    A0,D4
          MOVE.L    DISWND(A6),A0
          MOVEQ     #-1,D3
          LEA       DISBUF(A6),A1
          MOVEQ     #27,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          LEA       MNFIELD(A6),A1
          SUB.W     A1,D4
          CMPI.W    #28,D4
          BLE.S     DSPDIS_2
          MOVEQ     #28,D4
DSPDIS_2  MOVE.W    D4,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          RTS

*--------------------------------------------------------------------
* In the unlikely event of an exception hapening, the following are
* the messages that will be displayed.
*--------------------------------------------------------------------
*EXCEPTION MESSAGES

ADDERRMSG DC.W      14
          DC.B      10,'Address Error'
          DS.W      0
ILLINSMSG DC.W      20
          DC.B      10,'Illegal Instruction'
          DS.W      0
DIVZERMSG DC.W      17
          DC.B      10,'Division by zero'
          DS.W      0
CHKMSG    DC.W      14
          DC.B      10,'CHK Exception'
          DS.W      0
TRAPVMSG  DC.W      16
          DC.B      10,'TRAPV Exception'
          DS.W      0
PRIVMSG   DC.W      20
          DC.B      10,'Privilege Violation'
          DS.W      0
BRKPNTMSG DC.W      20
          DC.B      10,'Breakpoint Executed'
          DS.W      0
INTL7MSG  DC.W      18
          DC.B      10,'Interrupt Level 7'
          DS.W      0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EXINTL7   MOVE.L    A3,-(A7)
          LEA       $18020,A3
          SF        -$1E(A3)
          MOVE.L    #$061F0000,(A3)
          MOVE.B    #$1F,1(A3)
          MOVE.B    #1,-$1D(A3)
          MOVE.L    (A7)+,A3
          JSR       SAVREGS
          LEA       INTL7MSG,A1
          BRA.S     MAINERR1
EXADDERR  ADDQ.W    #8,A7
          JSR       SAVREGS
          LEA       ADDERRMSG,A1
          BRA.S     MAINERR1
EXILLINST JSR       SAVREGS
          LEA       ILLINSMSG,A1
          BRA.S     MAINERR1
EXDIVZER  JSR       SAVREGS
          LEA       DIVZERMSG,A1
          BRA.S     MAINERR1
EXCHK     JSR       SAVREGS
          LEA       CHKMSG,A1
          BRA.S     MAINERR1
EXTRAPV   JSR       SAVREGS
          LEA       TRAPVMSG,A1
          BRA.S     MAINERR1
EXPRIVV   JSR       SAVREGS
          LEA       PRIVMSG,A1
          BRA.S     MAINERR1
EXBRKPNT  JSR       SAVREGS
          SUBQ.L    #2,IM_PC(A6)
          SUBQ.L    #2,MEMPTR(A6)
          BSR.S     REMOVEBRK
          LEA       BRKPNTMSG,A1
MAINERR1  BRA.S     MAIN_ERR

REMOVEBRK MOVEQ     #BKPTABSIZ-1,D0
          LEA       BRKPTAB(A6),A0
          MOVE.L    MEMPTR(A6),A1
EXBKPLP   CMPA.L    (A0),A1
          BEQ.S     RST_OPC
          ADDQ.W    #6,A0
          DBF       D0,EXBKPLP
          RTS

RST_OPC   MOVEQ     #0,D0
          MOVE.L    D0,(A0)+
          MOVE.W    (A0),(A1)
          RTS

UNDO_BRK  BSR.S     REMOVEBRK
          BRA.S     MAIN_REG

*--------------------------------------------------------------------
*--------------------------------------------------------------------
*MAIN EXECUTION LOOP

NULMSG    DC.W      0
MAIN_REST MOVE.L    SYSVARS,A6
          LEA       DATASPACE(A6),A7
          TRAP      #0
          MOVE.L    $28068,A0
          BSR       EXAM_REGS
          ANDI      #$DFFF,SR
          CLR.L     MEMPTR(A6)
          LEA       NULMSG,A1
MAIN_ERR  MOVEQ     #0,D1
          MOVEQ     #-1,D2
          MOVEQ     #MT_DMODE,D0
          TRAP      #1
          MOVE.L    CMDWND(A6),A0
          MOVE.L    A1,A2
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVEQ     #1,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3
          MOVE.L    A2,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)

MAIN_LOOP BSR       DSPROMPT
MAIN_REG  BSR       DSPREG
MAIN_MEM  BSR       DSPMEM
          BSR       DSPDIS


*--------------------------------------------------------------------
* Here we have the re-entry point after a command has completed, or,
* for example, when prompted for an address we cause an error. This
* part of the code accepts a new command from the COMMAND WINDOW.
*--------------------------------------------------------------------
MAIN_1    MOVE.L    CMDWND(A6),A0   ; Command window to be used
          MOVEQ     #-1,D3
          MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print a newline to the command window

MAIN_2    MOVE.L    CMDWND(A6),A0   ; Command window to be used
          MOVEQ     #-1,D3
          MOVEQ     #1,D1           ; 8 pixels wide
          MOVEQ     #0,D2           ; 10 pixels high
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; Set channle font size
          MOVEQ     #'>',D1         ; Cursor character
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print cursor
          MOVEQ     #SD_CURE,D0
          TRAP      #3              ; Make sure cursor is enabled
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3              ; Wait for a single byte to D1.B
          CMPI.B    #'a',D1
          BCS.S     SEARCHTAB       ; D1 is less than 'a' (97)
          CMPI.B    #'z',D1
          BHI.S     SEARCHTAB       ; D1 is higher than 'z' (122)
          SUBI.B    #$20,D1         ; Command is a letter command
                                    ; but is lower case. Convert 
                                    ; to upper case.

*--------------------------------------------------------------------
* Start searching the command table for the command in D1.B.
*--------------------------------------------------------------------
SEARCHTAB LEA       CMDTAB,A2


*--------------------------------------------------------------------
* Look for the next command in the command table if we haven't found
* the one corresponding to D1.B yet.
*--------------------------------------------------------------------
NEXTCMD   MOVE.W    (A2)+,D0        ; Get the next command word
          BEQ.S     MAIN_1          ; All done. Invalid command
          CMP.B     D0,D1           ; Is this our command?
          BEQ.S     CMDFOUND        ; Hooray!
          ADDQ.L    #2,A2           ; Skip over the command's offset
          BRA.S     NEXTCMD         ; And keep searching

*--------------------------------------------------------------------
* We have found our command in the table. Non-letter commands have 
* bit 7 set, indicating negative values. This is used to good effect.
*--------------------------------------------------------------------
CMDFOUND  ADDA.W    (A2),A2         ; Add the offset to the command code
          TST.B     D1              ; Letter command or arrow etc command?
          BLT.S     JMPCMD          ; Non-lette commands don't echo
          MOVEQ     #IO_SBYTE,D0    ; Letter commands do echo to the
          TRAP      #3              ; COMMAND WINDOW
JMPCMD    JMP       (A2)            ; Then do the action

*--------------------------------------------------------------------
* Command table is two words per command. The low word is the key for
* the command and the second is an offset to the command. The upper
* byte of the key is zero, only the lower byte is used.
* A word of zero indicates the end of the table.
*--------------------------------------------------------------------
CMDTAB    DC.W      $C0             ; Arrow LEFT Change Memory Pointer
          DC.W      LEFT-*

          DC.W      $C8             ; Arrow RIGHT Change Memory Pointer
          DC.W      RIGHT-*

          DC.W      $D0             ; Arrow UP Change Memory Pointer
          DC.W      RIGHT8-*

          DC.W      $D8             ; Arrow DOWN Change Memory Pointer
          DC.W      LEFT8-*

          DC.W      $C1             ; ALT Arrow LEFT Change Register Pointer
          DC.W      RP_SUB8-*

          DC.W      $C9             ; ALT Arrow RIGHT Change Register Pointer
          DC.W      RP_ADD8-*

          DC.W      $D1             ; ALT Arrow UP Change Register Pointer
          DC.W      RP_SUB1-*

          DC.W      $D9             ; ALT Arrow DOWN Change Register Pointer
          DC.W      RP_ADD1-*

          DC.W      $E8             ; F1 Help
          DC.W      HELP-*

          DC.W      $EC             ; F2 Memory Dump
          DC.W      MEMDUMP-*

          DC.W      $F0             ; F3 Dissassemble
          DC.W      DIS_PAGE-*

          DC.W      ' A'            ; A Alter memory
          DC.W      ALT_MEM-*

          DC.W      ' B'            ; B Set breakpoint
          DC.W      BREAKPNT-*

          DC.W      ' C'            ; C Call a subroutine
          DC.W      CALL-*

          DC.W      ' D'            ; D Dissassemble to a file
          DC.W      DIS_FILE-*

          DC.W      ' E'            ; E Examine a job
          DC.W      EXAMINE-*

          DC.W      ' F'            ; F Fill memory
          DC.W      FILL-*

          DC.W      ' G'            ; G Convert to decimal
          DC.W      HEXTODEC-*

          DC.W      ' H'            ; H Convert to hexadecimal
          DC.W      DECTOHEX-*

          DC.W      ' I'            ; I Set memory pointer indirect
          DC.W      INDIRECT-*

          DC.W      ' J'            ; J Jump to location
          DC.W      JUMP-*

          DC.W      ' K'            ; K Copy block of memory
          DC.W      COPY-*

          DC.W      ' L'            ; L List memory to a file
          DC.W      MEMDUMP_1-*

          DC.W      ' M'            ; M Set memory pointer
          DC.W      SMEMPTR-*

          DC.W      ' N'            ; N Adjust memory pointer
          DC.W      ADD_MEM-*

          DC.W      ' O'            ; O Change relative mode
          DC.W      CH_OFFSET-*

          DC.W      ' Q'            ; Q Quit
          DC.W      QMON-*

          DC.W      ' R'            ; R Set current register value
          DC.W      SREG-*

          DC.W      ' S'            ; S Search for a hexadecimal string
          DC.W      FIND_HEX-*

          DC.W      ' T'            ; T Trace current instruction
          DC.W      TRACE-*

          DC.W      ' U'            ; U Remove (undo) breakpoint
          DC.W      UNDO_BRK-*

          DC.W      ' V'            ; V Display system info, list of jobs etc
          DC.W      VERSION-*

          DC.W      ' X'            ; X Execute current instruction
          DC.W      XECUTE-*

          DC.W      0

*--------------------------------------------------------------------
* Arrow LEFT - decrement current memory pointer.
*--------------------------------------------------------------------
LEFT      MOVEQ     #-1,D1
          BRA.S     AMEMPTR

*--------------------------------------------------------------------
* Arrow RIGHT - increment current memory pointer.
*--------------------------------------------------------------------
RIGHT     MOVEQ     #1,D1
          BRA.S     AMEMPTR

*--------------------------------------------------------------------
* Arrow DOWN - decrement current memory pointer by 8.
*--------------------------------------------------------------------
LEFT8     MOVEQ     #-8,D1
          BRA.S     AMEMPTR

*--------------------------------------------------------------------
* Arrow UP - increment current memory pointer by 8.
*--------------------------------------------------------------------
RIGHT8    MOVEQ     #8,D1
          BRA.S     AMEMPTR

*--------------------------------------------------------------------
*--------------------------------------------------------------------
ADD_MEM   BSR       GETADDR1

*--------------------------------------------------------------------
* Called from LEFT, RIGHT, UP, DOWN to change the address of the 
* current memeory pointer. D1.L is the offset that will be added to
* the current address. The MEMORY WINDOW is redrawn to display the
* new data - 8 bytes below and 8 bytes above the current MP.
*--------------------------------------------------------------------
AMEMPTR   ADD.L     D1,MEMPTR(A6)
          BRA       MAIN_MEM

*--------------------------------------------------------------------
* Q: Quit the program.
*--------------------------------------------------------------------
QMON      MOVEQ     #BKPTABSIZ-1,D0
          LEA       BRKPTAB(A6),A0
QMON_BRK  TST.L     (A0)
          BEQ.S     BRKNXT
          MOVE.L    (A0),A1
          MOVE.W    4(A0),(A1)
BRKNXT    ADDQ.W    #6,A0
          DBF       D0,QMON_BRK
          TRAP      #0
          MOVE.W    $28062,D0
          MOVE.L    $28068,A0
          LEA       EXTAB-$54(A6),A2
QMON_LP   TST.B     (A0)
          BLT.S     QMON_NXT
          MOVE.L    (A0),A1
          CMPA.L    $1C(A1),A2
          BNE.S     QMON_NXT
          CLR.L     $1C(A1)
QMON_NXT  ADDQ.W    #4,A0
          DBF       D0,QMON_LP
          CLR.L     $28050
          ANDI      #$DFFF,SR
          MOVEQ     #0,D0
QMON_1    MOVE.L    D0,D7
          MOVE.L    CMDWND(A6),A0
          LEA       QUITMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVEQ     #SD_CURS,D0
          TRAP      #3
          MOVEQ     #-1,D1
          MOVE.L    D7,D3
          MOVEQ     #MT_FRJOB,D0
          TRAP      #1

*--------------------------------------------------------------------
* MEssage to be displayed when we choose to quit from the monitor.
*--------------------------------------------------------------------
QUITMSG   DC.W      19
          DC.B      10,'Exit from MULTIMON'
          DS.W      0

*--------------------------------------------------------------------
* Message to be displayed when an address is entered incorrectly.
*--------------------------------------------------------------------
HEXERRMSG DC.W      12
          DC.B      'Syntax error'
          DS.W      0

*--------------------------------------------------------------------
* Call here to get an address. Returns only if no errors. Exits from
* here by tidying the stack and returning via the main loop.
*--------------------------------------------------------------------
GETADDR1  JSR       GET_ADDR        ; Get an address
          BEQ.S     GTAD1_RTS       ; All ok
          ADDQ.W    #4,A7           ; Tidy return address of caller
HEXERR    LEA       HEXERRMSG,A1    ; Error message to print
          MOVE.L    CMDWND(A6),A0   ; Print it in the command window
          MOVE.W    UT_MTEXT,A2     ; Vector
          JSR       (A2)            ; Print message
          BRA       MAIN_1          ; Exit to main loop to try again
GTAD1_RTS RTS

*--------------------------------------------------------------------
* I: Set memory pointer indirect. In other words, prompt for the new
* memory pointer address.
*--------------------------------------------------------------------
INDIRECT  BSR.S     GETADDR1        ; Returns if we got one
          BCLR      #0,D1           ; Even things up
          MOVE.L    D1,A1
          MOVE.L    (A1),MEMPTR(A6)
          BRA.S     SMEM_1

SMEMPTR   BSR.S     GETADDR1
          MOVE.L    D1,MEMPTR(A6)
SMEM_1    BSR       DSPMEM
          BSR       DSPDIS
MAIN_2A   BRA       MAIN_2

SREG      BSR.S     GETADDR1
          MOVE.W    REGPTR(A6),D0
          CMPI.W    #IM_SR,D0
          BNE.S     SREG_1
          MOVE.W    D1,0(A6,D0.W)
          BRA.S     SREG_2
SREG_1    MOVE.L    D1,0(A6,D0.W)
SREG_2    BSR       DSPREG
          BRA.S     MAIN_2A

SET_PC    JSR       GET_ADDR
          BNE.S     SETPCRTS
          TST.L     D1
          BNE.S     SETPC_END
          MOVE.L    MEMPTR(A6),D1
SETPC_END BCLR      #0,D1
          MOVE.L    D1,IM_PC(A6)
          MOVEQ     #0,D0
SETPCRTS  RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
XECUTE    MOVE.L    MEMPTR(A6),D1
          BCLR      #0,D1
          MOVE.L    D1,IM_PC(A6)
          MOVE.L    MEMPTR(A6),A4
          JSR       DISASSEM
          MOVE.L    A4,D1
          BSR.S     BRKP_1
          BRA.S     JUMP_2

JUMP      BSR.S     SET_PC
          BNE       HEXERR
JUMP_2    JMP       RESTREGS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
CALL      BSR.S     SET_PC
          BNE       HEXERR
          MOVE.L    IM_USP(A6),A1
          MOVE.L    MEMPTR(A6),-(A1)
          LEA       CALL_RET,A3
          MOVE.L    A3,-(A1)
          MOVE.L    A1,IM_USP(A6)
          JMP       RESTREGS

CALL_RET  MOVE      SR,-(A7)
          TRAP      #0
          SUBQ.W    #6,A7
          MOVE.L    A0,-(A7)
          MOVE      USP,A0
          MOVE.W    (A0)+,4(A7)
          MOVE.L    (A0)+,6(A7)
          MOVE      A0,USP
          MOVE.L    (A7)+,A0
          JSR       SAVREGS
          BRA       MAIN_LOOP

*--------------------------------------------------------------------
*--------------------------------------------------------------------
TRACE     MOVE.L    MEMPTR(A6),D1
          BCLR      #0,D1
          MOVE.L    D1,IM_PC(A6)
          BSET      #7,IM_SR(A6)
          JMP       RESTREGS

EXTRACE   BCLR      #7,(A7)
          JSR       SAVREGS
          BRA       MAIN_LOOP

BRKP_SUB  MOVE.L    MEMPTR(A6),D1
BRKP_1    BCLR      #0,D1
          MOVEQ     #BKPTABSIZ-1,D0
          LEA       BRKPTAB(A6),A1
BRKP_LOOP TST.L     (A1)
          BEQ.S     ENTBRKP
          ADDQ.L    #6,A1
          DBF       D0,BRKP_LOOP
          LEA       BRKFULMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          ADDQ.L    #4,A7
          BRA       MAIN_1
ENTBRKP   MOVE.L    D1,(A1)+
          MOVE.L    D1,A0
          MOVE.W    (A0),(A1)
          MOVE.W    #$4E4F,(A0)
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
BREAKPNT  BSR.S     BRKP_SUB
BRKP_END  BRA       MAIN_LOOP

*--------------------------------------------------------------------
*--------------------------------------------------------------------
BRKFULMSG DC.W      21
          DC.B      10,'Too many breakpoints'
          DS.W      0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DIS_PAGE  MOVEQ     #SD_CURS,D0
          TRAP      #3
          BSR.S     ESC_MSG
          MOVE.L    AUXWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVE.L    MEMPTR(A6),D1
          BCLR      #0,D1
          MOVE.L    D1,A4
          ST        DISMOD(A6)
DP_LOOP   MOVE.W    #19,-(A7)
DP_LOOP1  JSR       DISASSEM
          MOVE.L    A0,D4
          MOVE.L    AUXWND(A6),A0
          MOVEQ     #-1,D3
          LEA       DISBUF(A6),A1
          MOVEQ     #27,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          LEA       MNFIELD(A6),A1
          SUB.W     A1,D4
          CMPI.W    #74-27,D4
          BLE.S     DP_MNEM
          MOVEQ     #74-27,D4
DP_MNEM   MOVE.W    D4,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          SUBQ.W    #1,(A7)
          BNE.S     DP_LOOP1
          ADDQ.W    #2,A7
          MOVE.L    CMDWND(A6),A0
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3
          CMPI.B    #$1B,D1
          BNE.S     DP_LOOP

*--------------------------------------------------------------------
* Clear the AUX and COMMAND WINDOWS before skipping back to the
* main loop.
*--------------------------------------------------------------------
DP_END    MOVE.L    AUXWND(A6),A0   ; Use the AUX WINDOW
          MOVEQ     #SD_CLEAR,D0    ; Clear it
          TRAP      #3
          MOVE.L    CMDWND(A6),A0   ; Use the COMMAND WINDOW
          MOVEQ     #SD_CLEAR,D0    ; Clear it
          TRAP      #3
          BRA       MAIN_LOOP       ; Go around again

*--------------------------------------------------------------------
* Print a message inviting the user to press ESC to quit or any other
* key to continue. This uses the PROMPT WINDOW.
*--------------------------------------------------------------------
ESC_MSG   MOVE.L    PROMPTWND(A6),A0    ; Use the PROMPT window
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0    ; Clear it
          TRAP      #3
          LEA       ESCPROMPT,A1    ; Any key to continue...
          MOVE.W    UT_MTEXT,A2
          JMP       (A2)            ; Print it

*--------------------------------------------------------------------
* And this is the prompt message used above.
*--------------------------------------------------------------------
ESCPROMPT DC.W      42
          DC.B      'Press any key to continue or <ESC> to exit'

*--------------------------------------------------------------------
*--------------------------------------------------------------------
MEMDUMP   MOVEQ     #SD_CURS,D0
          TRAP      #3
          MOVE.L    PROMPTWND(A6),A0
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVEQ     #0,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3
          MOVEQ     #43,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_PIXP,D0
          TRAP      #3
          LEA       MD_MSG1,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVE.W    #334,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_PIXP,D0
          TRAP      #3
          LEA       MD_MSG2,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVE.L    AUXWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVE.L    MEMPTR(A6),A4
MD_PAGE   MOVEQ     #18,D7
MD_LOOP   MOVE.L    A4,D1
          TST.B     RELMOD(A6)
          BEQ.S     MD2
          CMP.L     BASE_PNT(A6),D1
          BLO.S     MD2
          CMP.L     TOP_PNT(A6),D1
          BHS.S     MD2
          SUB.L     BASE_PNT(A6),D1
          ANDI.B    #$F0,D1
          ADD.L     BASE_PNT(A6),D1
          BRA.S     MD3
MD2       ANDI.B    #$F0,D1
MD3       MOVE.L    D1,A4
          BSR.S     DO_MEM
          MOVE.L    AUXWND(A6),A0
          MOVEQ     #-1,D3
          LEA       DISBUF(A6),A1
          MOVEQ     #72,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          DBF       D7,MD_LOOP
          MOVE.L    CMDWND(A6),A0
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3
          CMPI.B    #$1B,D1
          BNE.S     MD_PAGE
          BRA       DP_END

DO_MEM    MOVE.L    A4,D1
          LEA       DISBUF(A6),A0
          JSR       CN_ADDR
          MOVE.B    #':',(A0)+
          MOVE.B    #' ',(A0)+
          MOVEQ     #15,D2
DM_BYTE   MOVE.B    (A4)+,D1
          JSR       CN_HEXB
          MOVE.B    #' ',(A0)+
          DBF       D2,DM_BYTE
          MOVE.B    #' ',(A0)+
          SUBA.W    #16,A4
          MOVEQ     #15,D2
DM_CHR    MOVE.B    (A4)+,D1
          CMPI.B    #$0A,D1
          BNE.S     DM_CH1
          MOVEQ     #0,D1
DM_CH1    MOVE.B    D1,(A0)+
          DBF       D2,DM_CHR
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
MD_MSG1   DC.W      MDMSG_END-*-2
          DC.B      '0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F'
MDMSG_END EQU       *

*--------------------------------------------------------------------
*--------------------------------------------------------------------
MD_MSG2   DC.W      16
          DC.B      '0123456789ABCDEF'

*--------------------------------------------------------------------
*--------------------------------------------------------------------
ALT_MEM   MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          MOVE.L    MEMPTR(A6),A4
AM_LOOP   LEA       DISBUF(A6),A0
          MOVE.L    A4,D1
          JSR       CN_ADDR
          MOVE.B    #':',(A0)+
          MOVE.B    #' ',(A0)+
          MOVE.L    CMDWND(A6),A0
          MOVEQ     #-1,D3
          LEA       DISBUF(A6),A1
          MOVEQ     #7,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          BSR.S     HEX_LINE
          BEQ       MAIN_LOOP
          MOVE.L    A4,MEMPTR(A6)
          BRA.S     AM_LOOP

HEX_LINE  LEA       DISBUF+1(A6),A1
          MOVEQ     #DISBUFLEN-1,D2
          MOVEQ     #IO_FLINE,D0
          TRAP      #3
          SUBQ.W    #1,D1
          BEQ.S     HEXL_END
          LEA       DISBUF+1(A6),A1
          MOVE.L    A4,A5
          LSR.W     #1,D1
          BCC.S     HL_1
          MOVE.B    #'0',-(A1)
          ADDQ.W    #1,D1
HL_1      MOVE.W    D1,D4
GET_HLINE MOVE.B    2(A1),D6
          MOVE.B    #10,2(A1)
          JSR       READHEX
          CMPI.B    #10,(A1)
          BNE.S     HEXL_ERR
          MOVE.B    D1,(A5)+
          MOVE.B    D6,(A1)
          CMPI.B    #10,D6
          BNE.S     GET_HLINE
          MOVE.L    A5,A4
          MOVE.W    D4,D1
HEXL_END  RTS

HEXL_ERR  ADDQ.W    #4,A7
          LEA       BADHEXMSG,A1
          MOVE.L    CMDWND(A6),A0
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          BRA       MAIN_LOOP
BADHEXMSG DC.B      0,7,'Bad Hex'
          DS.W      0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
FIND_HEX  MOVEQ     #':',D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          LEA       HEXSTR+2(A6),A4
          BSR.S     HEX_LINE
          LEA       HEXSTR(A6),A5
          MOVE.W    D1,D7
          SUBQ.W    #1,D7
          BLT.S     FH_DEFLT
          MOVE.W    D7,(A5)+
          BRA.S     FH_MEM
FH_DEFLT  MOVE.W    (A5)+,D7
FH_MEM    MOVE.L    MEMPTR(A6),A3
FH_LOOP   ADDQ.W    #1,A3
          MOVE.W    D7,D6
          MOVE.L    A5,A4
          MOVE.L    A3,A2
FH_CMP    CMPM.B    (A2)+,(A4)+
          DBNE      D6,FH_CMP
          TST.W     D6
          BGE.S     FH_LOOP
FH_END    MOVE.L    A3,MEMPTR(A6)
          BSR       DSPMEM
          BSR       DSPDIS
          BRA       MAIN_2

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DECTOHEX  BSR       GETADDR1
          LEA       DISBUF(A6),A0
          MOVE.L    #'  = ',(A0)+
          JSR       CN_HEXL
          MOVE.L    CMDWND(A6),A0
          LEA       DISBUF+1(A6),A1
          MOVEQ     #11,D2
DTOH_2    MOVEQ     #-1,D3
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          BRA       MAIN_1

*--------------------------------------------------------------------
*--------------------------------------------------------------------
HEXTODEC  BSR       GETADDR1
          LEA       DISBUF+14(A6),A1
          MOVEQ     #3,D2
          MOVE.L    D1,D4
          BGE.S     HD_LOOP
          NEG.L     D1
HD_LOOP   MOVEQ     #0,D0
          SWAP      D1
          MOVE.W    D1,D0
          DIVU      #10,D0
          SWAP      D0
          MOVE.W    D0,D1
          SWAP      D1
          DIVU      #10,D1
          MOVE.W    D1,D0
          SWAP      D1
          EXG       D0,D1
          ADDI.B    #'0',D0
          MOVE.B    D0,-(A1)
          ADDQ.W    #1,D2
          TST.L     D1
          BNE.S     HD_LOOP
          TST.L     D4
          BGE.S     HD_POS
          MOVE.B    #'-',-(A1)
          ADDQ.W    #1,D2
HD_POS    MOVEQ     #' ',D0
          MOVE.B    D0,-(A1)
          MOVE.B    #'=',-(A1)
          MOVE.B    D0,-(A1)
          BRA.S     DTOH_2

CH_OFFSET NOT.B     RELMOD(A6)
          BRA       MAIN_REG

*--------------------------------------------------------------------
*--------------------------------------------------------------------
OPEN_FILE LEA       FN_MSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          BSR       RDSTRING
OP_AGAIN  LEA       DISBUF(A6),A0
          MOVEQ     #-1,D1
          MOVE.L    D4,D3
          MOVEQ     #IO_OPEN,D0
          TRAP      #2
          TST.L     D0
          BEQ.S     OP_OK
          ADDQ.L    #8,D0
          BEQ.S     OP_EXISTS
          SUBQ.L    #8,D0
          MOVE.L    CMDWND(A6),A0
          MOVE.W    UT_ERR,A2
          JSR       (A2)
          LEA       MAIN_2,A1
OP_QUIT   ADDQ.W    #4,A7
          JMP       (A1)

OP_EXISTS MOVE.L    CMDWND(A6),A0
          LEA       EXIST_MSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVEQ     #-1,D3
          MOVEQ     #SD_CURE,D0
          TRAP      #3
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3
          MOVE.W    D1,-(A7)
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          LEA       MAIN_1,A1
          MOVE.W    (A7)+,D1
          ANDI.B    #$DF,D1
          CMPI.B    #'Y',D1
          BNE.S     OP_QUIT
          MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          LEA       DISBUF(A6),A0
          MOVEQ     #-1,D1
          MOVEQ     #IO_DELET,D0
          TRAP      #2
          BRA.S     OP_AGAIN
OP_OK     RTS

*--------------------------------------------------------------------
* Message to be printed when prompting for a file name.
*--------------------------------------------------------------------
FN_MSG    DC.B      0,10,$0A,'File Name'

*--------------------------------------------------------------------
* Message displayed when the requested file already exists.
*--------------------------------------------------------------------
EXIST_MSG DC.B      0,31,'File exists. Overwrite ? (Y/N) ',0

*--------------------------------------------------------------------
* Code to request the start and end addresses for some feature. 
* The start address is returned in D4 and the end address in D1.L and
* D5.L.
* You will be repeatedly prompted if the start is bigger than the end
* address or if an error occurs when getting the user's input.
*--------------------------------------------------------------------
FIRSTLAST MOVE.L    CMDWND(A6),A0   ; Channel ID to use
          LEA       FIRSTMSG,A1     ; First message
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print it
          JSR       GET_ADDR        ; Fetch an address
          BNE.S     FIRSTLAST       ; Repeat on error
          MOVE.L    D1,D4           ; Save start address in D4.L

GT_LAST   LEA       LASTMSG,A1      ; Last message
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print it
          JSR       GET_ADDR        ; Fetch an address
          BNE.S     GT_LAST         ; Repeat on error
          MOVE.L    D1,D5           ; Copy end address in D5
          CMP.L     D4,D5           ; End must be > start
          BLT.S     FIRSTLAST       ; Try again, it's not
          RTS

*--------------------------------------------------------------------
* Messages displayed when prompting for the first and last addresses
* for a particulat funtion of the monitor.
*--------------------------------------------------------------------
FIRSTMSG  DC.B      0,5,'First',0
LASTMSG   DC.B      0,4,'Last'

*--------------------------------------------------------------------
* Header text written out for memory dumps.
*--------------------------------------------------------------------
MD_HEADR  DC.W      MDH_END-*-2
          DC.B      '       00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F  0123456789ABCDEF',10
MDH_END   EQU       *         

*--------------------------------------------------------------------
*--------------------------------------------------------------------
MEMDUMP_1 MOVEQ     #2,D4
          BSR       OPEN_FILE
          MOVE.L    A0,A5
          BSR       FIRSTLAST
          MOVE.L    D4,A4
          MOVE.L    A5,A0
          LEA       MD_HEADR,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
MD1_LOOP  BSR       DO_MEM
          LEA       DISBUF+56(A6),A1
          MOVEQ     #15,D0
MD1_LP1   CMPI.B    #$20,0(A1,D0.W)
          BCS.S     MK_POINT
          CMPI.B    #$7F,0(A1,D0.W)
          BCS.S     PNT_NXT
MK_POINT  MOVE.B    #'.',0(A1,D0.W)
PNT_NXT   DBF       D0,MD1_LP1
          MOVE.L    A5,A0
          LEA       DISBUF(A6),A1
          MOVEQ     #72,D2
          MOVEQ     #-1,D3
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          TST.L     D0
          BNE.S     MD1_END
          MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          TST.L     D0
          BNE.S     MD1_END
          CMPA.L    D5,A4
          BLE.S     MD1_LOOP
MD1_END   MOVE.L    D0,D4
          MOVEQ     #IO_CLOSE,D0
          TRAP      #2
          MOVE.L    D4,D0
PRT_ERR   MOVE.L    CMDWND(A6),A0
          MOVE.W    UT_ERR,A2
          JSR       (A2)
          BRA       MAIN_2

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DIS_FILE  MOVEQ     #2,D4
          BSR       OPEN_FILE
          MOVE.L    A0,A5
DIS_WRK   MOVE.L    CMDWND(A6),A0
          LEA       WRKSP_MSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          BSR       READ_LINE
          SUBQ.W    #1,D1
          BEQ.S     DIS_DEF
          JSR       READDEC
          CMPI.B    #10,(A1)
          BNE.S     DIS_WRK
          BRA.S     DIS_ALLOC
DIS_DEF   MOVE.L    #1024,D1
DIS_ALLOC MOVEQ     #-1,D2
          MOVEQ     #MT_ALCHP,D0
          TRAP      #1
          TST.L     D0
          BNE.S     DIS_WRK
          MOVE.L    A0,DATATBL(A6)
          MOVE.L    A0,WRKSPTR(A6)
          LEA       -$10(A0,D1.L),A0
          MOVE.L    A0,WRK_END(A6)
          SF        WRKSPOV(A6)
          BSR       FIRSTLAST
          MOVE.L    D4,DISFRST(A6)
          MOVE.L    D5,DISLAST(A6)
          LEA       OPC_MSG,A1
          MOVE.L    CMDWND(A6),A0
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVEQ     #-1,D3
          MOVEQ     #SD_CURE,D0
          TRAP      #3
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3
          ANDI.B    #$DF,D1
          CMPI.B    #'Y',D1
          SEQ       OPCODEFLG(A6)
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          LEA       DATA_MSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
DATA_LOOP BSR       FIRSTLAST
          OR.L      D4,D1
          BEQ.S     DIS_START
          BSR       GET_SIZE
          ROR.L     #8,D1
          ANDI.L    #$FF000000,D1
          OR.L      D4,D1
          JSR       ADD_WRK
          MOVE.L    D5,D1
          JSR       ADD_WRK
          TST.B     WRKSPOV(A6)
          BEQ.S     DATA_LOOP
WRKSP_ERR MOVE.L    CMDWND(A6),A0
          LEA       WRKERRMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVE.L    DATATBL(A6),A0
          MOVEQ     #MT_RECHP,D0
          TRAP      #1
          MOVE.L    A5,A0
          MOVEQ     #IO_CLOSE,D0
          TRAP      #2
          BRA       MAIN_1

*--------------------------------------------------------------------
* An error mesage for workspace overflow conditions.
*--------------------------------------------------------------------
WRKERRMSG DC.B      0,18,'Workspace Overflow'

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DIS_START MOVE.L    WRKSPTR(A6),LBL_TBL(A6)
          SF        DISMOD(A6)
          MOVE.L    DISFRST(A6),A4
DIS1_LP   MOVE.L    A5,-(A7)
          JSR       DISASSEM
          MOVE.L    (A7)+,A5
          TST.B     WRKSPOV(A6)
          BNE.S     WRKSP_ERR
          CMPA.L    DISLAST(A6),A4
          BLS.S     DIS1_LP
          ADDQ.B    #1,DISMOD(A6)
          MOVE.L    DISFRST(A6),A4
          MOVE.L    A5,-(A7)
DIS2_LP   JSR       DISASSEM
          MOVE.L    A0,D2
          LEA       DISBUF(A6),A1
          TST.B     OPCODEFLG(A6)
          BEQ.S     DIS_OUT
          LEA       LBL_FLD(A6),A1
DIS_OUT   SUB.L     A1,D2
          MOVE.L    (A7),A0
          MOVEQ     #-1,D3
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          TST.L     D0
          BNE.S     DIS_QUIT
          MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          TST.L     D0
          BNE.S     DIS_QUIT
          CMPA.L    DISLAST(A6),A4
          BLS.S     DIS2_LP
DIS_QUIT  MOVE.L    D0,D4
          MOVE.L    (A7)+,A0
          MOVEQ     #IO_CLOSE,D0
          TRAP      #2
          MOVE.L    DATATBL(A6),A0
          MOVEQ     #MT_RECHP,D0
          TRAP      #1
          MOVE.L    D4,D0
          BRA       PRT_ERR

*--------------------------------------------------------------------
* Prompt message to ask for a (new) workspace size.
*--------------------------------------------------------------------
WRKSP_MSG DC.B      0,14,'Workspace Size'

*--------------------------------------------------------------------
* Prompt message to asik if the opcode should be suppressed or not.
*--------------------------------------------------------------------
OPC_MSG   DC.B      0,24,'Suppress opcode ? (Y/N) '

*--------------------------------------------------------------------
*--------------------------------------------------------------------
DATA_MSG  DC.B      0,12,$0A,'Data areas',$0A

*--------------------------------------------------------------------
*--------------------------------------------------------------------
EXAMINE   JSR       RDSTRING
          ADDQ.W    #2,A1
          JSR       READHEX
          BNE.S     EX2
          CMPI.B    #10,(A1)
          BEQ.S     GET_JB
EX2       MOVEQ     #1,D4
          BSR       OP_AGAIN
          LEA       DISBUF(A6),A1
          MOVEQ     #$40,D2
          MOVEQ     #-1,D3
          MOVEQ     #FS_HEADR,D0
          TRAP      #3
          TST.L     D0
          BNE.S     EX_ERR
          MOVEQ     #-15,D0
          SUBQ.B    #1,DISBUF+5(A6)
          BNE.S     EX_ERR
          MOVE.L    A0,-(A7)
          MOVE.L    DISBUF(A6),D2
          MOVE.L    DISBUF+6(A6),D3
          MOVEQ     #-1,D1
          SUBA.L    A1,A1
          MOVEQ     #MT_CJOB,D0
          TRAP      #1
          MOVE.L    A0,A1
          MOVE.L    (A7)+,A0
          TST.L     D0
          BNE.S     EX_ERR
          MOVE.L    D1,D7
          MOVEQ     #-1,D3
          MOVEQ     #FS_LOAD,D0
          TRAP      #3
          TST.L     D0
          BEQ.S     EX_ERR
          MOVE.L    A0,-(A7)
          MOVEQ     #0,D3
          MOVE.L    D7,D1
          MOVEQ     #MT_FRJOB,D0
          TRAP      #1
          MOVE.L    (A7)+,A0
EX_ERR    MOVE.L    D0,D4
          MOVEQ     #IO_CLOSE,D0
          TRAP      #2
          MOVE.L    D4,D0
          BNE       PRT_ERR
          MOVE.L    D7,D1
GET_JB    MOVE.L    $28068,A0
          LSL.W     #2,D1
          ADDA.W    D1,A0
          CMPA.L    $2806C,A0
          BGE.S     BAD_JOB
          TST.B     (A0)
          BGE.S     COPY_REG
BAD_JOB   MOVEQ     #-2,D0
          BRA       PRT_ERR
COPY_REG  TRAP      #0
          BSR.S     EXAM_REGS
          ANDI      #$DFFF,SR
          BSR       DSPREG
          BSR       DSPMEM
          BSR       DSPDIS
          BRA       MAIN_2
EXAM_REGS MOVE.L    A0,JBPNT(A6)
          MOVE.L    (A0),A0
          LEA       $20(A0),A0
          MOVE.L    A6,A1
          MOVEQ     #15,D0
COPY_R_LP MOVE.L    (A0)+,(A1)+
          DBF       D0,COPY_R_LP
          MOVE.W    (A0)+,IM_SR(A6)
          MOVE.L    (A0),(A1)+
          MOVE.L    (A0)+,MEMPTR(A6)
          ADDQ.W    #2,A0
          MOVE.L    A0,(A1)+
          LEA       -$68(A0),A0
          LEA       EXTAB-$54(A6),A2
          MOVE.L    A2,$1C(A0)
          CMPA.L    $28010,A0
          BEQ.S     ST_TP_1
          ADDA.L    (A0),A0
          BRA.S     ST_TP
ST_TP_1   MOVE.L    $28014,A0
ST_TP     MOVE.L    A0,(A1)
          MOVE.L    A7,A0
          ADDQ.W    #4,A0
          MOVE.L    A0,IM_SSP(A6)
          RTS

*--------------------------------------------------------------------
*--------------------------------------------------------------------
GET_SIZE  MOVE.L    D4,-(A7)
          LEA       SIZMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVEQ     #SD_CURE,D0
          TRAP      #3
GTSIZ_1   MOVEQ     #IO_FBYTE,D0
          TRAP      #3
          MOVEQ     #-33,D0
          AND.B     D0,D1
          MOVEQ     #-1,D4
          CMPI.B    #'B',D1
          BEQ.S     GTSIZ_END
          MOVEQ     #0,D4
          CMPI.B    #'W',D1
          BEQ.S     GTSIZ_END
          MOVEQ     #1,D4
          CMPI.B    #'L',D1
          BNE.S     GTSIZ_1
GTSIZ_END
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          MOVE.B    D4,D1
          MOVE.L    (A7)+,D4
          RTS

*--------------------------------------------------------------------
* Size prompt.
*--------------------------------------------------------------------
SIZMSG    DC.B      0,15,'Size ? (B,W,L) ',0

*--------------------------------------------------------------------
*--------------------------------------------------------------------
FILL      MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          BSR       FIRSTLAST
          OR.L      D4,D1
          BEQ       MAIN_1
          MOVE.L    D4,A4
          BSR.S     GET_SIZE
          MOVE.B    D1,D7
          LEA       WITHMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          BSR       GETADDR1
          TST.B     D7
          BEQ.S     FILL_W
          BGT.S     FILL_L
FILL_B    MOVE.B    D1,(A4)+
          CMPA.L    D5,A4
          BLE.S     FILL_B
          BRA.S     FILL_END
FILL_W    MOVE.W    D1,(A4)+
          CMPA.L    D5,A4
          BLE.S     FILL_W
          BRA.S     FILL_END
FILL_L    MOVE.L    D1,(A4)+
          CMPA.L    D5,A4
          BLE.S     FILL_L
FILL_END  BRA       MAIN_2
WITHMSG   DC.B      0,4,'With'

*--------------------------------------------------------------------
*--------------------------------------------------------------------
COPY      MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          BSR       FIRSTLAST
          LEA       TO_MSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          BSR       GETADDR1
          MOVE.L    D1,A5
          CMP.L     D4,D1
          BLE.S     COPY_UP
          CMP.L     D5,D1
          BLE.S     COPY_DOWN
COPY_UP   MOVE.L    D4,A4
COPY_U_LP MOVE.B    (A4)+,(A5)+
          CMPA.L    D5,A4
          BLE.S     COPY_U_LP
          BRA.S     COPY_END
COPY_DOWN MOVE.L    D5,A4
          ADDQ.W    #1,A4
          SUB.L     D4,D5
          LEA       1(A5,D5.L),A5
COPY_D_LP MOVE.B    -(A4),-(A5)
          CMPA.L    D4,A4
          BGT.S     COPY_D_LP
COPY_END  BRA       MAIN_2
TO_MSG    DC.B      0,2,'To'

*--------------------------------------------------------------------
* V - Version command. Fills the output window with details of all
* the running jobs in the system.
*--------------------------------------------------------------------
VERSION   LEA       JOBSMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVE.L    $28068,A5
          SUBQ.W    #4,A5
          MOVEQ     #2,D7
          BRA.S     NXTJOB
JOBLOOP   MOVEQ     #3,D7
NXTJOB    ADDQ.W    #4,A5
          CMPA.L    $2806C,A5
          BGE       ENDJB
          TST.B     (A5)
          BLT.S     NXTJOB
          MOVE.L    (A5),A4
          MOVE.L    A5,D1
          SUB.L     $28068,D1
          LSR.W     #2,D1
          SWAP      D1
          MOVE.W    $10(A4),D1
          SWAP      D1
          LEA       DISBUF(A6),A0
          JSR       CN_HEXL
          MOVE.W    #$2020,(A0)+
          MOVE.L    8(A4),D1
          JSR       CN_HEXL
          MOVE.W    #$2020,(A0)+
          TST.W     $14(A4)
          BEQ.S     NOT_SUSP
          MOVE.B    #'S',-1(A0)
NOT_SUSP  MOVE.L    CMDWND(A6),A0
          MOVEQ     #10,D1
          MOVEQ     #-1,D3
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          LEA       DISBUF(A6),A1
          MOVEQ     #20,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          MOVEQ     #0,D1
          MOVE.B    $13(A4),D1
          MOVE.W    UT_MINT,A2
          JSR       (A2)
          MOVEQ     #24,D1
          MOVEQ     #SD_TAB,D0
          TRAP      #3
          LEA       $68+6(A4),A1
          CMPI.W    #$4AFB,(A1)+
          BNE.S     NONAME
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
NONAME    DBF       D7,NXTJOB
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3
          BRA       JOBLOOP
ENDJB     MOVE.L    CMDWND(A6),A0
          MOVEQ     #-1,D3
          TST.W     D7
          BGT.S     ENDJ1
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3
ENDJ1     LEA       VER_MSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVEQ     #MT_INF,D0
          TRAP      #1
          MOVE.L    CMDWND(A6),A0
          LEA       DISBUF(A6),A1
          MOVE.L    D2,(A1)
          MOVEQ     #4,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          LEA       FREEMSG,A1
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          MOVEQ     #MT_FREE,D0
          TRAP      #1
          LSR.L     #8,D1
          LSR.L     #2,D1
          MOVE.L    CMDWND(A6),A0
          MOVE.W    UT_MINT,A2
          JSR       (A2)
          MOVEQ     #'K',D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3
          BRA       MAIN_1

*--------------------------------------------------------------------
* Headings for the V command when displaying job details.
*--------------------------------------------------------------------
JOBSMSG   DC.B      0,30,10,'Job ID    Owner    Prior Name'
          DS.W      0

*--------------------------------------------------------------------
* HEadings for the V command when displaying the QDOS version.
*--------------------------------------------------------------------
VER_MSG   DC.B      0,15,10,'QDOS Version: '
          DS.W      0

*--------------------------------------------------------------------
* HEadings for the V command when displaying free memory.
*--------------------------------------------------------------------
FREEMSG   DC.B      0,15,'  Free Memory: ',0
          DS.W      0

*--------------------------------------------------------------------
* F1 - Help Command.
*--------------------------------------------------------------------
HELP      MOVEQ     #SD_CURS,D0     ; Enable the cursor
          TRAP      #3
          MOVE.L    PROMPTWND(A6),A0    ; In the PROMPT WINDOW
          MOVEQ     #SD_CLEAR,D0    ; And clear the screen
          TRAP      #3
          LEA       HELPMSG1,A1     ; "Continue" message
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print it.
          MOVE.L    AUXWND(A6),A0   ; Use the AUX WINDOW for help
          MOVEQ     #SD_CLEAR,D0    ; Clear the AUX WINDOW
          TRAP      #3
          LEA       HELPMSG2,A1     ; The full help text
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print it
          MOVE.L    CMDWND(A6),A0   ; Watch the COMMAND WINDOW
          MOVEQ     #IO_FBYTE,D0    ; for a key press
          TRAP      #3
          BRA       DP_END          ; Clear windows and renter main loop

*--------------------------------------------------------------------
*--------------------------------------------------------------------
HELPMSG1  DC.W      HLP1_END-*-2
          DC.B      'Press any key to continue'
HLP1_END  EQU       *
          DS.W      0

*--------------------------------------------------------------------
* The text below is the HELP message displayed when F1 is pressed. If
* you are reading this on a non-QL computer then it is possible that
* some characters don't appear correctly.
*
* The Copyright message has a CHR$(127) or (C) at the start.
* The CHANGE xxxx POINTER messages have the arrow keys as LEFT, RIGHT,
* UP and DOWN at the start of each message. CHR$(188, 189, 190, 191).
* 
*--------------------------------------------------------------------
* DO NOT ATTEMPT TO EDIT THOSE CHARACTERS ON A NON_QL COMPUTER AS YOU
* WILL CORRUPT THE CODE WHEN RUNNING ON A QL COMPUTER OR EMULATOR!!!!
*--------------------------------------------------------------------
HELPMSG2  DC.W      HLP2_END-*-2
          DC.B      '                             QL MULTIMON V2.1',10
          DC.B      '                        1986, 87 BY JAN BREDENBEEK',10,10
          DC.B      'COMMANDS:',10,10
          DC.B      '섹씩: CHANGE MEMORY POINTER            ALT-섹씩: CHANGE REGISTER POINTER',10
          DC.B      'F2: MEMORY DUMP TO SCREEN              F3: DISASSEMBLE TO SCREEN',10
          DC.B      'A: ALTER MEMORY                        B: SET BREAKPOINT',10
          DC.B      'C: CALL A SUBROUTINE                   D: DISASSEMBLE TO FILE',10
          DC.B      'E: EXAMINE A JOB                       F: FILL MEMORY',10
          DC.B      'G: CONVERT TO DEC                      H: CONVERT TO HEX',10
          DC.B      'I: SET MEMORY POINTER INDIRECT         J: JUMP TO LOCATION',10
          DC.B      'K: COPY BLOCK OF MEMORY                L: LIST MEMORY TO FILE',10
          DC.B      'M: SET MEMORY POINTER                  N: ADJUST MEMORY POINTER',10
          DC.B      'O: CHANGE RELATIVE MODE                Q: QUIT',10
          DC.B      'R: SET REGISTER VALUE                  S: SEARCH FOR HEX STRING',10
          DC.B      'T: TRACE CURRENT INSTRUCTION           U: REMOVE BREAKPOINT',10
          DC.B      'V: SYSTEM INFO                         X: EXECUTE CURRENT INSTRUCTION',10
HLP2_END  EQU       *

          END


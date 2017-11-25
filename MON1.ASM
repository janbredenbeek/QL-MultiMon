* MULTIMON
* QL MONITOR/DISASSEMBLER
* V1.0 - JANUARY 24, 1986

          INCLUDE   FDK1_QDOS_IN

DATASPACE EQU       512             Stack space for the monitor

*--------------------------------------------------------------------
* The following are offsets into the dataspace for various storage
* needs. The dataspace start address will, just after execution, be
* held in A6.
*--------------------------------------------------------------------
IM_D0     EQU       0               Storage for D0-A7
IM_USP    EQU       60              Storage for User SP  
IM_PC     EQU       64              Storage for Program Counter
BASE_PNT  EQU       68              Monitored job's base address
TOP_PNT   EQU       72              Monitored job's top address
IM_SR     EQU       76              Storage for Status Register
IM_SSP    EQU       78              Storage for Supervisor SP
EXTAB     EQU       82              Exception table
EXTABEND  EQU       158             End of Exception Table
PROMPTWND EQU       158             Channel IDs for Windows
REGWND    EQU       162             Register Window ID
MEMWND    EQU       166             Memory Window ID
CMDWND    EQU       170             Command Window ID
DISWND    EQU       174             Disassembly Window ID
AUXWND    EQU       178             Auxiliary Window ID
OWN_JB    EQU       182             ???? -> TODO
JBPNT     EQU       186             ???? -> TODO
MATHSTK   EQU       194             Temp top of 16 byte maths stack (194 - 178)
MEMPTR    EQU       190             Current memory address
REGPTR    EQU       198             ???? -> TODO

*--------------------------------------------------------------------
* The breakpoint table is defined here as 10 entries - if you change 
* this, adjst what follows as well. Or else!
*--------------------------------------------------------------------
BKPTABSIZ EQU       10              Maximum entries in breakpoint table
BRKPTAB   EQU       200             Breakpoint table - 10 entries of 6 bytes

*--------------------------------------------------------------------
* Adjest the following if you change the breakpoint table size. The
* following offsets should be (6*BKPTABBSIZ)+whatever is required.
* The default size is 10 slots of 6 bytes or 60 bytes.
*--------------------------------------------------------------------
RELMOD    EQU       BRKPTAB+60      Relative mode flag
DISMOD    EQU       BRKPTAB+61      Disassembly mode flag
OPCODEFLG EQU       BRKPTAB+62      Flag - $FF = Suppress Opcodes in disassembly
WRKSPOV   EQU       BRKPTAB+63      We overflowed the workspace flag ($FF = Overflow)
DATATBL   EQU       BRKPTAB+64      Dataspace allocated for disassembly address etc
LBL_TBL   EQU       BRKPTAB+68      ???? -> TODO
WRKSPTR   EQU       BRKPTAB+72      First free space in workarea (DATATBL)
WRK_END   EQU       BRKPTAB+76      End of the above buffer - 16
DISFRST   EQU       BRKPTAB+80      First address to disassemble
DISLAST   EQU       BRKPTAB+84      Last address to disassemble

*--------------------------------------------------------------------
* The disassembly buffer is used for many things!
*--------------------------------------------------------------------
DISBUF    EQU       BRKPTAB+88      Disassembly buffer

*--------------------------------------------------------------------
* As per the above, many things use the disassembly buffer, so these
* offsets are used to keep the disassembly data out of the way of the
* other stuff, as and when required.
*--------------------------------------------------------------------
LBL_FLD   EQU       DISBUF+27       The labels go here - up to 9 bytes
MNFIELD   EQU       DISBUF+34       ???? -> TODO
OPR_FLD   EQU       DISBUF+42       ???? -> TODO
DISBUFLEN EQU       82              Size of disassembly buffer (bytes)
HEXSTR    EQU       DISBUF+DISBUFLEN    Where the HEX codes go in the buffer

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
SYSVARS   DS.L      1               ; Storage for SYSVARS address

          DC.W      $4AFB,8         ; Job flag and name size
          DC.B      'MULTIMON'      ; Job name

*--------------------------------------------------------------------
* Call MT_INF to get the current jobid in D1.L. If this is zero, we
* are in SuperBASIC so link MON in as a new procedure. Otherwise, we
* have been EXEC'd and are running as a standalone job.
*--------------------------------------------------------------------
START     MOVEQ     #MT_INF,D0      ; Get system information
          TRAP      #1
          TST.L     D1              ; Check is SuperBASIC (Job zero)
          BNE.S     START2          ; Not SuperBASIC (job zero)             
          LEA       PROCTAB,A1      ; Must be SuperBASIC - one proc
          MOVE.W    BP_INIT,A2      ; Link MON proc into SuperBASIC
          JMP       (A2)            ; Do it & exit.

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
START2    ADDA.L    A4,A6           ; A6 = Start of data space
          LEA       SYSVARS,A1      ; Storage in standard job header
          MOVE.L    A6,(A1)         ; Save A6 in header
          TRAP      #0              ; Supervisor mode
          MOVE.L    $28064,OWN_JB(A6)   ; SV_JBPNT = Own Job id
          MOVE.L    $28068,A0       ; SV_JBBAS = Start of Job Table  
          BSR       EXAM_REGS       ; ???? -> TODO
          ANDI      #$DFFF,SR       ; Clear Supervisor bit
          CLR.L     MEMPTR(A6)      ; Current memory address
          ST        RELMOD(A6)      ; $FF = Relative? ???? -> TODO
          LEA       EXTABEND(A6),A7 ; Top of Exception vector table
          MOVEQ     #10,D0          ; Counter for 11 exception vectors

*--------------------------------------------------------------------
* Loop around for TRAP #15 to TRAP #5. Each of these points to the
* EXBRKPNT code and will fire a breakpoint if executed.
*--------------------------------------------------------------------
SETTRAPS  PEA       EXBRKPNT        ; Code for this trap's vector
          DBF       D0,SETTRAPS     ; Do all of #15 down to #5

*--------------------------------------------------------------------
* The rest of the exception vector table follows.
*--------------------------------------------------------------------
          PEA       EXINTL7         ; Interrupt level 7
          PEA       EXTRACE         ; Trace exception
          PEA       EXPRIVV         ; Privilege violation
          PEA       EXTRAPV         ; TRAPV
          PEA       EXCHK           ; CHK
          PEA       EXDIVZER        ; Divide by zero exception
          PEA       EXILLINST       ; ILLEGAL instruction exception
          PEA       EXADDERR        ; Address error exception

          MOVE.L    A7,A1           ; Exception vector table address
          LEA       DATASPACE(A6),A7    ; Reset stack pointer
          MOVEQ     #-1,D1          ; For the current job
          MOVEQ     #MT_TRAPV,D0    ;
          TRAP      #1              ; Set the exception vectors

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
* The procedure (and function) definition block to link the new MON
* procedure into SuperBASIC. Not used if this code is running as a
* job, or if this code is run in a non-zero job id. (SuperBASIC = 0.)
*--------------------------------------------------------------------
PROCTAB   DC.W      1               ; One PROCedure
          DC.W      BAS_ENT-*       ; Where it starts
          DC.B      3,'MON'         ; What it is called
          DC.W      0               ; No FuNctions (DC not DS!)
          DC.W      0,0,0           ; End of FNs, end of list.        

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
* The AUXILIARY WINDOW for Help and disassembly etc. 
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
          DC.B      127, ' 1986, 87 JAN BREDENBEEK'
          DS.W      0

*--------------------------------------------------------------------
* Save the registers for later display. Called whenever we hit an
* exception in a monitored job. This means that register values are
* as per the monitored job (or at least, the one that caused the
* exception) and not yet the monitor's registers as the scheduler
* has not been run to reschedule the current job back to the monitor.
* We are also in supervisor mode, hence USP and not A7 below! A7 is
* referring to the Supervisor SP in the following code.
*
* SR.S is set (for supervisor mode).
* SR.T is cleared (to disable trace).
* PC is stacked at -(SSP).
* SR is stacked at -(SSP).
* 
* A7 = SSP = Pointing at SR on stack, so:
*
* 2(A7) = Program Counter.L
* 0(A7) = Status Register.W
*
* BUS and ADDRESS Exceptions also stack:
*
* Instruction Register (Word)
* Exception Address Low Word (Word)
* Exception Address High Word (Word)
* Memory Access Type & Function Code (Word)
*
* A7 = SSP = Pointing at the Memory Access type & Function code word, so:
*
* A(A7) = Program Counter.L
* 8(A7) = Status Register.W
* 6(A7) = First word of the excepting instruction.W
* 2(A7) = Address accessed in error.L
* 0(A7) = Function code etc.W
*
* BUS Exceptions are not possible/likely on a QL. There are no external
* hardware stuff.
*
* ADDRESS Exceptions are of course, possible. On the 68008 anyway.
*
* When we enter here, SSP aka, A7, is pointing always, regardless of
* the exception type, at the return address above the SR word on the 
* stack - because we JSR here. So the stack is:
*
* 6(A7) = Program Counter.L
* 4(A7) = Status Register.W
* 0(A7) = Return address.L
*--------------------------------------------------------------------
SAVREGS   MOVE.L    A6,-(A7)            ; Save the job's base address
          MOVE.L    $28064,A6           ; SV_JBPNT - current job pointer
          MOVE.L    (A6),A6             ; Base address of current job
          MOVEM.L   D0-D7/A0-A5,$20(A6) ; Save job's registers in job header
          MOVE.L    (A7)+,$58(A6)       ; Save job's A6 = base address
          MOVE      USP,A1              ; Get the job's USP
          MOVE.L    A1,$5C(A6)          ; Save job's A7 stack pointer
          MOVE.L    (A7)+,A5            ; Return address of SAVEREGS caller
          MOVE.W    (A7)+,$60(A6)       ; Job's Status Register
          MOVE.L    (A7)+,$62(A6)       ; Job's Program Counter
          MOVE.L    $28064,A0           ; SV_JBPNT - current job pointer
          MOVE.L    SYSVARS,A6          ; Reset A6 to monitor's dataspace
          BSR       EXAM_REGS           ; ???? -> TODO
          LEA       DATASPACE(A6),A0    ; The monitor's top of stack
          MOVE      A0,USP              ; Reset our own stack
          MOVE.L    $28064,A0           ; We did this above, then broke it!
          MOVE.L    OWN_JB(A6),A2       ; The monitor's job id
          CMPA.L    A0,A2               ; Is the current job the monitor?
          BEQ.S     GO_MON              ; Yes. Skip.

*--------------------------------------------------------------------
* Suspend the monitored job, assuming it's not the monitor itself and
* inddicate nobody is waiting for this job.
*--------------------------------------------------------------------
          MOVE.L    (A0),A0             ; No, get base address of job
          MOVE.W    #-1,$14(A0)         ; JB_STAT - Flag job as suspended
          SF        $17(A0)             ; JB_WFLAG - flag no-one waiting

GO_MON    MOVE.L    A2,$28064           ; Make the monitor the current job
          MOVE.L    (A2),A2             ; Base address of the monitor
          CLR.W     $14(A2)             ; JB_STAT - Flag it as active
          MOVE.L    $0C(A2),D0          ; JB_HOLD - location to clear on exit
          BEQ.S     GO_MON1             ; Not needed, skip
          MOVE.L    D0,A2               ; Get the location to be cleared
          SF        (A2)                ; Clear the required location
GO_MON1   MOVE      #$0000,SR           ; Wipe everything from SR
          JMP       (A5)                ; Effectively, RTS to the caller

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
          BRA       PRT_ERR         ; Do error message then -> main loop

*--------------------------------------------------------------------
* Read some text from the user via whatever channel is in A0 at call
* time. Exits with the data length stored at the start of the buffer,
* but does not include the newline character, and A1 pointing at the
* data length word.
*--------------------------------------------------------------------
RDSTRING  LEA       DISBUF+2(A6),A2 ; Buffer address
          MOVEQ     #DISBUFLEN-2,D2 ; Buffer size
          BSR.S     RDLIN_2         ; Fetch some text
          SUBQ.W    #1,D1           ; Discount the newline
          MOVE.W    D1,-(A1)        ; Save the data length
          RTS                       ; Done

*--------------------------------------------------------------------
* Enter at READ_LINE to default to using the buffer at DISBUF(A6) for
* any text input by the user. Then get some text. Exits with A1
* pointing at the buffer start address, D1.W holding the data length
* not including the newline. The buffer does not have the data length
* stored in it.
*--------------------------------------------------------------------
READ_LINE LEA       DISBUF(A6),A2   ; Buffer address
          MOVEQ     #DISBUFLEN,D2   ; Buffer size

*--------------------------------------------------------------------
* Enter at RDLIN_2 when you want to specify the buffer and maximum
* buffer size instead of the defaults. Just reads the input from
* the user. Exits with A1 pointing at the buffer start address.
*--------------------------------------------------------------------
RDLIN_2   MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #':',D1         ; Colon to send (No, really???)
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Send colon
          MOVE.L    A2,A1           ; Buffer address
          MOVEQ     #IO_FLINE,D0
          TRAP      #3              ; Fetch some input
          MOVE.L    A2,A1           ; Restore buffer address
          RTS                       ; Done

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
GET_ADDR  MOVEM.L   D2-D4/A0-A1,-(A7)   ; Save workers
          BSR.S     READ_LINE       ; Read some text from the user
          MOVEQ     #0,D4           ; ???? -> TODO

GTAD_LP   SF        D3              ; Clear D3.B
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

GTAD_M    MOVE.L    MEMPTR(A6),D1   ; Current memory address
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
* Convert a buffer of characters from hexadecimal to a value in D1.
* If there are invalid characters then return an error in D0.
* Entry here required the buffer start address in A1. This is not in
* standard QDOS string format, the characters are converted until a
* ???? -> TODO is detected.
*--------------------------------------------------------------------
READHEX   MOVEQ     #0,D1           ; Result in D1
          MOVEQ     #0,D0           ; Clear out D0
          MOVE.L    A1,A0           ; Save the buffer start address

*--------------------------------------------------------------------
* Hex to Decimal conversion loop.
*--------------------------------------------------------------------
GHEXLP    MOVE.B    (A1),D0         ; Grab the first character
          CMPI.B    #'0',D0
          BLT.S     GHEX_END        ; Lower than '0' means done
          CMPI.B    #'9',D0
          BLE.S     GHEXADD         ; '0' - '9' are ok.
          CMPI.B    #'A',D0
          BLT.S     GHEX_END        ; Lower than 'A' means done
          ANDI.B    #$DF,D0         ; Convert to upper case
          CMPI.B    #'F',D0
          BGT.S     GHEX_END        ; Higher than 'F' means done
          SUBQ.B    #7,D0           ; Adjust for letters

*--------------------------------------------------------------------
* The character in D0 is '0'-'9' or ('A' - 7) - ('F' - 7). Convert it
* to binary, and tally it in the running total for the conversion.
*--------------------------------------------------------------------
GHEXADD   SUBI.B    #'0',D0         ; DeASCIIfy the character
          LSL.L     #4,D1           ; Total *= 16
          ADD.L     D0,D1           ; Total += D1
          ADDQ.W    #1,A1           ; Next character
          BRA.S     GHEXLP          ; Go around until done

*--------------------------------------------------------------------
* Check if we actually converted anything, if we did convert then we
* are done with no errors, return D1 as the value converted and D0
* showing no errors.
*--------------------------------------------------------------------
GHEX_END  CMPA.L    A0,A1           ; Has the buffer changed?
          BEQ.S     GHEX_ERR        ; Yes, we converted nothing at all
          MOVEQ     #0,D0           ; No, we are ok, no errors
          RTS                       ; Done

*--------------------------------------------------------------------
* Handle errors by returning an error code in D0.
*--------------------------------------------------------------------
GHEX_ERR  MOVEQ     #-17,D0         ; Error in expression
          RTS                       ; Done

*--------------------------------------------------------------------
* Read a decimal number from the user's input into a binary value in
* D1. Entry here requires that A1 be pointing at the first character
* in the buffer to be converted. The buffer holds characters and only
* '0' - '9' are permitted. Anything else is an error.
*--------------------------------------------------------------------
READDEC   MOVEQ     #0,D1           ; Result in D1
          MOVEQ     #0,D0           ; Clear out D0
          MOVE.L    A1,A0           ; Save start character address

*--------------------------------------------------------------------
* The main character to decimal conversion loop.
*--------------------------------------------------------------------
RDEC_LOOP MOVE.B    (A1),D0         ; Grab the first character
          SUBI.B    #'0',D0         ; DeASCIIfy it - 0 - 9 only
          BLT.S     GHEX_END        ; Was < '0' - we are done here
          CMPI.B    #10,D0          ; End of input? (or > 9)
          BGE.S     GHEX_END        ; Yes, we are done here
          MOVE.L    D1,D2           ; Total saved
          LSL.L     #2,D1           ; Total *= 4
          ADD.L     D2,D1           ; Total => Total * 5
          ADD.L     D1,D1           ; Total => Total * 10
          ADD.L     D0,D1           ; Add in current digit
          ADDQ.W    #1,A1           ; Next character in buffer
          BRA.S     RDEC_LOOP       ; Go around again

*--------------------------------------------------------------------
* Read a binary number from the user's input into a binary value in
* D1. Entry here requires that A1 be pointing at the first character
* in the buffer to be converted. The buffer holds characters and only
* '0' - '1' are permitted. Anything else is an error.
*--------------------------------------------------------------------
READBIN   MOVEQ     #0,D1           ; Result in D1
          MOVEQ     #0,D0           ; Clear D0 for working
          MOVE.L    A1,A0           ; Save first character address

*--------------------------------------------------------------------
* The main character to binary conversion loop.
*--------------------------------------------------------------------
RDBIN_LP  MOVE.B    (A1),D0         ; Grab a character
          SUBI.B    #'0',D0         ; DeASCIIfy it - 0 & 1 only
          BLT       GHEX_END        ; Lower than 0, we are done here
          CMPI.B    #1,D0           ; Got a 1?
          BGT       GHEX_END        ; Higher, we are done here
          ADD.L     D1,D1           ; Total *= 2
          ADD.L     D0,D1           ; Add new digit
          ADDQ.W    #1,A1           ; Next character
          BRA.S     RDBIN_LP        ; Go around again

*--------------------------------------------------------------------
* PROMPT WINDOW HANDLER
* Clears the prompt window, sets the desired character sizes and
* displays the usual prompt message about F1, F2 and F3 etc.
*--------------------------------------------------------------------
DSPROMPT  MOVE.L    PROMPTWND(A6),A0    ; PROMPT window ID
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3              ; CLS PROMPT window

          MOVEQ     #1,D1           ; 8 Pixels wide
          MOVEQ     #0,D2           ; 10 Pixels high
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; Set character sizes

          LEA       PROMPTMSG,A1    ; Message to print
          MOVE.W    UT_MTEXT,A2     
          JSR       (A2)            ; print it
          RTS                       ; Done

*--------------------------------------------------------------------
* This message should be visible in the PROMPT window at all times.
*--------------------------------------------------------------------
PROMPTMSG DC.W      45
          DC.B      'F1 = Help  F2 = Memory Dump  F3 = Disassemble'
          DS.W      0

*--------------------------------------------------------------------
* This is the code to convert a single address register and what the
* 8 bytes it points to, for the REGISTER window's contents.
* 
* The format of each of the register lines is as follows:
*
* 'D0 00000000  A0 00000000  (A0) 00 00 00 00 00 00 00 00',10
*     A       B    C       D     EF GH IJ KL MN OP QR ST   U 
*
* The line above has certain bytes flagged, these are used in the
* comments below.
*
* When we enter here, (A6,A0.L) is pointing at flag 'C' above and
* (A6,A1.L) points at the appropriate address register in storage
* in our dataspace.
*
* A6 points to our dataspace, which just happens to be where the
* D0 - A7, SR, PC etc registers are saved, handy that.
*--------------------------------------------------------------------

DSPADDREG MOVE.W    CN_ITOHL,A2     ; TOS -> HEX.L
          JSR       (A2)            ; Do conversion, A1 += 4
;                                   ; A0 now = flag 'D' above
          ADDQ.W    #6,A0           ; A0 now = flag 'E' above
          MOVE.L    -4(A6,A1.W),A3  ; Get the An value again
;                                   ; ???? -> TODO A6,A1.Word? Word?
          TST.B     RELMOD(A6)      ; $FF = Relative, $00 = Absolute
          BEQ.S     DSPA_SAV        ; Absolute mode, skip relativeness
          CMPA.W    #$3C,A1         ; Past A7 in register storage?
          BGE.S     DSPA_SAV        ; Yes, skip relativeness - not needed
;                                   ; Must still be an address register then
          MOVE.L    BASE_PNT(A6),A2 ; Base address of monitored job
          ADDA.L    A3,A2           ; Make A2 the absolute address
          CMPA.L    TOP_PNT(A6),A2  ; Past the end of the monitored job?
          BCC.S     DSPA_SAV        ; No, ???? -> TODO
          ADDA.L    BASE_PNT(A6),A3 ; Absolute address now

*--------------------------------------------------------------------
* This code deals with converting the 8 bytes pointed to by an 
* address register into the 8 pairs of hex digits at the end of each
* line of the register display.
*--------------------------------------------------------------------
* I THINK that the messing around with A1.W rather than A1.L is down
* to saving some time, clock cycles etc as the hig word of A1 is zero
* when we are doing all this work on the registers display window.
*--------------------------------------------------------------------
DSPA_SAV  MOVE.W    A1,-(A7)        ; Save register pointer
          MOVEQ     #7,D6           ; There are 8 bytes to convert

*--------------------------------------------------------------------
* A loop to convert and buffer 8 bytes pointed to by A0 for the
* end of the register display lines for A0 - A7. (A6,A0.L) points one
* byte before the desired place each time around, so this is flags
* 'E', 'G', 'I', 'K', 'M', 'O', 'Q', 'S' and must be adjusted by one
* byte to point at the desired output location.
*--------------------------------------------------------------------
D_AR_LP   LEA       MATHSTK,A1      ; The new maths stack
          MOVE.B    (A3)+,0(A6,A1.L)    ; Stack a single byte
          ADDQ.W    #1,A0           ; 'E'->'F', 'G'->'H' etc.
          MOVE.W    CN_ITOHB,A2     ; TOS -> HEX.B
          JSR       (A2)            ; Convert and TOS += 1
;                                   ; A0 now off by 1 again.
          DBF       D6,D_AR_LP      ; Deal with the rest
          MOVE.W    (A7)+,A1        ; Restore register storage pointer
          RTS                       ; Done

*--------------------------------------------------------------------
* REGISTER WINDOW HANDLER.
*
* Entry point to display the registers in the REGISTER window. We
* start off by setting A0, the output buffer to a slightly weird
* address - but worry ye not, it makes sense - later.
*
* The format of each of the register lines is as follows:
*
* 'D0 00000000  A0 00000000  (A0) 00 00 00 00 00 00 00 00',10
*     A       B    C       D     EF GH IJ KL MN OP QR ST   U 
*
* The line above has certain bytes flagged, these are used in the
* comments below.
*
* A6 points to our dataspace, which just happens to be where the
* D0 - A7, SR, PC etc registers are saved, handy that.
*--------------------------------------------------------------------
DSPREG    SUBA.L    A1,A1           ; Offset from A6 to Value at TOS
;                                   ; which happens to be the D0 value
          LEA       REGMSG+1,A0     ; We will adjust this later
          SUBA.L    A6,A0           ; Make A0 relative to A6
          MOVEQ     #7,D7           ; There are 8 registers

*--------------------------------------------------------------------
* A loop to convert each of the 8 data and 8 address registers into
* the format shown above. On entry, A0 is pointing to the byte just 
* before the 'D' in 'D0' at the start of the line.
* Each pass through here begins with the appropriate data register.
*--------------------------------------------------------------------
DSPR_LP   ADDQ.W    #4,A0           ; At 'A' for this Data register
          MOVE.W    CN_ITOHL,A2     ; TOS at (A6,A1.L) to HEX.L
          JSR       (A2)            ; Overwrites '00000000', A0 = 'B' 

          ADDQ.W    #5,A0           ; A0 now at flag 'C' above
          ADDA.W    #7*4,A1         ; A1 now looking at the Address register 
          BSR.S     DSPADDREG       ; Convert An and what it points to
          SUBA.W    #8*4,A1         ; Next Data register
          DBF       D7,DSPR_LP      ; Do all 8 Dn & An registers

*--------------------------------------------------------------------
* At the end of all 8 D and A registers, we need to do the rest. This
* is the format of the output to be done:
*
* 'SP 00000000  PC 00000000  (PC) 00 00 00 00 00 00 00 00',10
* '   T S  III   XNZVC        BP 00000000  TP 00000000',10
* 'SR 0000000000000000'
*
* A0 is pointing at the linefeed on the line ending with the A7 data
* bytes.
*--------------------------------------------------------------------
          ADDQ.W    #4,A0           ; Point at the SP register value
          LEA       IM_SSP,A1       ; Point at the stored register
          MOVE.W    CN_ITOHL,A2     ; TOS -> HEX.L
          JSR       (A2)            ; Convert 

          ADDQ.W    #5,A0           ; Point at the PC register value
          LEA       IM_PC,A1        ; Point at the stored register
          BSR.S     DSPADDREG       ; Pretend it's an address register

          ADDA.W    #31,A0          ; Point at the BP register value
          MOVE.W    CN_ITOHL,A2     ; TOS -> HEX.L
          JSR       (A2)            ; Convert

          ADDQ.W    #5,A0           ; Point at the TP register value
          MOVE.W    CN_ITOHL,A2     ; TOS -> HEX.L
          JSR       (A2)            ; Convert

          ADDQ.W    #4,A0           ; Point at the SR value    
          MOVE.W    CN_ITOBW,A2     ; TOS -> BIN.W (16 bits)
          JSR       (A2)            ; Convert

          MOVE.L    REGWND(A6),A0   ; REGISTER window ID
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3              ; Clear the REGISTER Window

          MOVEQ     #1,D1           ; 8 Pixels wide
          MOVEQ     #0,D2           ; 10 Pixels high
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; Set character sizes

          LEA       REGMSG,A1       ; The entire register window contents
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print the register values etc

*--------------------------------------------------------------------
* After printing all the register values, we convert the job's ID in
* a buffer at (A0) then print it at 27,10. The format of the job id 
* is a tag in the high word and the entry number in the job table in
* the low word.
*--------------------------------------------------------------------
          LEA       DISBUF(A6),A0   ; Working buffer
          MOVE.L    #'JB  ',(A0)    ; Buffer some text
          ADDQ.W    #3,A0           ; Destination in buffer
          MOVE.L    JBPNT(A6),D1    ; Current job table entry (or SV_JBBAS).
          MOVE.L    D1,A1           ; Save it
          SUB.L     $28068,D1       ; Subtract SV_JBBAS = offset into table
          LSR.W     #2,D1           ; 4 bytes per table entry
          MOVE.L    (A1),A1         ; Address of job in memory
          SWAP      D1              ; Low word available for use
          MOVE.W    $10(A1),D1      ; JB_TAG = Job Tag
          SWAP      D1              ; D1 = Tag | Entry number
          JSR       CN_HEXL         ; Convert to 8 characters

          MOVE.L    REGWND(A6),A0   ; REGISTER Window ID
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #27,D1          ; XPOS = 27
          MOVEQ     #10,D2          ; YPOS = 10
          MOVEQ     #SD_POS,D0
          TRAP      #3              ; Set position to 27,10

          LEA       DISBUF(A6),A1   ; Where our data lives
          MOVEQ     #11,D2          ; 11 bytes to print
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print Job tag | Entry number

          MOVEQ     #40,D1          ; Position 40 on this line
          MOVEQ     #SD_TAB,D0
          TRAP      #3              ; Set pos for REL ON/OFF

*--------------------------------------------------------------------
* Work out if we are in relative mode or not. We need to inform the
* user.
*--------------------------------------------------------------------
          LEA       DISBUF(A6),A1   ; Working buffer
          MOVE.L    #'REL ',(A1)    ; Title text gets buffered
          MOVE.L    #'OFF ',D1      ; Assume OFF
          TST.B     RELMOD(A6)      ; But check anyway
          BEQ.S     PR_REL          ; Correct, not in relative mode
          MOVE.L    #'ON  ',D1      ; Bad guess, we are relative

*--------------------------------------------------------------------
* Print out the relative mode details on the final line of the
* REGISTER window.
*--------------------------------------------------------------------
PR_REL    MOVE.L    D1,4(A1)        ; Buffer details
          MOVEQ     #7,D2           ; Size of data to print
          MOVEQ     #IO_SSTRG,D0    
          TRAP      #3              ; Print data

          MOVEQ     #'>',D4         ; Our REGISTER window prompt
          BRA.S     DSPREGP         ; Print the register pointer

*--------------------------------------------------------------------
* Blank template that is used to display the registers in the main 
* loop and various helper/command routines.
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
          MOVE.L    MEMPTR(A6),A4   ; Current memory address
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
          CMPA.L    MEMPTR(A6),A4   ; Current memory address
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
          MOVE.L    MEMPTR(A6),A4   ; Current memory address
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
          MOVE.L    MEMPTR(A6),A4   ; Current memory address
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
* Interrupt Level 7 handler.
* If this gets called, the chances are the QL is locked up as the
* interrupt causes communications with the 8049 to be reset. As the 
* code below mucks about in hardware registers, you better know what
* these are:
*
* $18000 PC_CLOCK - Real Time Clock in seconds (Long word).
* $18002 PC_TCTRL - Transmit Control.
* $18003 PC_IPCWR - IPC Write.
* $18020 PC_MCTRL - Microdrive control/status & IPC status.
* $18020 PC_IPCRD - IPC Read (Same as above.)
* $18021 PC_INTR  - Interrupt Control/Status.
* $18022 PC_TDATA - Transmit Data.
* $18022 PC_TRAK1 - Microdrive Read Track 1.
* $18023 PC_TRAK2 - Microdrive Read Track 2.
* $18063 MC_STAT  - Display Control.
*
* Of course, it's not as easy as that. These bytes have different
* functions when read from that when written! So, here they are:
*
* ADDR      NAME        READ FUNCTION           WRITE FUNCTION
  
* $18000    PC_CLOCK    RTC byte 0.             RTC Reset.
* $18001                RTC byte 1.             RTC step.
* $18002    PC_TCTRL    RTC byte 2.             Transmit Control.
* $18003    PC_IPCWR    RTC byte 3.             IPC Link Control.
* $18020    PC_MCTRL    MDV/RS232C Status.      MDV Control.
* $18021    PC_INTR     Interrupt/IPC Status.   Interrupt Control.  
* $18022    PC_TRAK1    MDV Data (Track 1).     MDC/RS232C Data.  
* $18023    PC_TRAK2    MDV Data (Track 2).     Display Control.
*
* For more information, you need the QDOS Technical Reference.
*--------------------------------------------------------------------
EXINTL7   MOVE.L    A3,-(A7)        ; Save A3 for a bit
          LEA       $18020,A3       ; Microdrive/IPC control/status
          SF        -$1E(A3)        ; $18002 Transmit control ???? -> TODO
          MOVE.L    #$061F0000,(A3) ; $18020-$18023           ???? -> TODO
          MOVE.B    #$1F,1(A3)      ; Hasn't this just been done?
          MOVE.B    #1,-$1D(A3)     ; $18003 PC_IPCWR - ???? -> TODO
          MOVE.L    (A7)+,A3        ; Restore A3
          JSR       SAVREGS         ; Save monitored job's registers
          LEA       INTL7MSG,A1     ; Message to print
          BRA.S     MAINERR1        ; Bale out

*--------------------------------------------------------------------
* Address Error handler.
* Tidy the additional data off the SSP.
* Save the registers - so you can hopefully see which one caused the
* exception - then print an address error message before hitting the
* main loop again.
*--------------------------------------------------------------------
EXADDERR  ADDQ.W    #8,A7           ; Point at the SR on the SSP
          JSR       SAVREGS         ; Save REGS and reschedule
          LEA       ADDERRMSG,A1    ; Message to print
          BRA.S     MAINERR1        ; Bale out

*--------------------------------------------------------------------
* Illegal Instruction handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXILLINST JSR       SAVREGS         ; Save REGS and reschedule
          LEA       ILLINSMSG,A1    ; Message to print
          BRA.S     MAINERR1        ; Bale out

*--------------------------------------------------------------------
* Divide by Zero handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXDIVZER  JSR       SAVREGS         ; Save REGS and reschedule
          LEA       DIVZERMSG,A1    ; Message to print
          BRA.S     MAINERR1        ; Bale out

*--------------------------------------------------------------------
* CHK handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXCHK     JSR       SAVREGS         ; Save REGS and reschedule
          LEA       CHKMSG,A1       ; Message to print
          BRA.S     MAINERR1        ; Bale out

*--------------------------------------------------------------------
* TRAPV handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXTRAPV   JSR       SAVREGS         ; Save REGS and reschedule
          LEA       TRAPVMSG,A1     ; Message to print
          BRA.S     MAINERR1        ; Bale out

*--------------------------------------------------------------------
* Privilege Violation handler.
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXPRIVV   JSR       SAVREGS         ; Save REGS and reschedule
          LEA       PRIVMSG,A1      ; Message to print
          BRA.S     MAINERR1        ; Bale out

*--------------------------------------------------------------------
* The code here is executed on any trap #5 to trap #15 by this job,
* the monitor, not the job being monitored.
*
* Breakpoints are activated by TRAP #15 and also arrive here.
*
* Save the registers.
* Print an address error message before hitting the main loop again.
*--------------------------------------------------------------------
EXBRKPNT  JSR       SAVREGS         ; Save REGS and reschedule
          SUBQ.L    #2,IM_PC(A6)    ; ???? -> TODO
          SUBQ.L    #2,MEMPTR(A6)   ; Current memory address = this instruction
          BSR.S     REMOVEBRK       ; Delete a breakpoint here, if necessary
          LEA       BRKPNTMSG,A1    ; Print 'Breakpoint executed'

*--------------------------------------------------------------------
* I get the impression this is simply here to allow a BRA.S from the
* above. I could be wrong...
*--------------------------------------------------------------------
MAINERR1  BRA.S     MAIN_ERR

*--------------------------------------------------------------------
* Delete a breakpoint at the current memory address, if there is one
* by removing it from the breakpoint table and replacing the TRAP #15
* breakpoint code with the instruction that was there previously.
* If there is no breakpoint, don't worry about it, just return.
*--------------------------------------------------------------------
REMOVEBRK MOVEQ     #BKPTABSIZ-1,D0 ; D0 + 1 slots in the table
          LEA       BRKPTAB(A6),A0  ; The table lives here
          MOVE.L    MEMPTR(A6),A1   ; Current memory address

*--------------------------------------------------------------------
* Loop to find the breakpoint with the address held in A1 and to
*--------------------------------------------------------------------
EXBKPLP   CMPA.L    (A0),A1         ; Is this our breakpoint?
          BEQ.S     RST_OPC         ; Yes
          ADDQ.W    #6,A0           ; No, look at the next one
          DBF       D0,EXBKPLP      ; Loop around until done
          RTS                       ; Done - even if we find nothing

*--------------------------------------------------------------------
* Reset the TRAP #15 at the breakpoint with the instruction that was
* there previously, when the breakpoint was set. Also, clear this
* breakpoint.
*--------------------------------------------------------------------
RST_OPC   MOVEQ     #0,D0           ; Flag no breakpoint here
          MOVE.L    D0,(A0)+        ; Clears this breakpoint
          MOVE.W    (A0),(A1)       ; Replace the TRAP #15 breakpoint code
          RTS                       ; Done

*--------------------------------------------------------------------
* U: Undo breakpoint at current memory address.
*--------------------------------------------------------------------
UNDO_BRK  BSR.S     REMOVEBRK       ; Look for and remove the breakpoint
          BRA.S     MAIN_REG        ; And back to the main loop

*--------------------------------------------------------------------
* This is a blank message of zero characters in length. 
*--------------------------------------------------------------------
NULMSG    DC.W      0

*--------------------------------------------------------------------
* MAIN EXECUTION LOOP
* Reset A6 to point at our (the monitor's) data space then set the
* stack appropriately before jumping into supervisor mode.
*--------------------------------------------------------------------
MAIN_REST MOVE.L    SYSVARS,A6      ; Address of our dataspace
          LEA       DATASPACE(A6),A7    ; Set up our stack
          TRAP      #0              ; Into supervisor mode
          MOVE.L    $28068,A0       ; SV_JBBAS - base of job table
          BSR       EXAM_REGS       ; ???? -> TODO
          ANDI      #$DFFF,SR       ; Exit supervisor mode
          CLR.L     MEMPTR(A6)      ; ???? -> TODO
          LEA       NULMSG,A1       ; ???? -> TODO

*--------------------------------------------------------------------
* We enter here from the exception handlers above, amongst other
* places. ???? -> TODO
*--------------------------------------------------------------------
MAIN_ERR  MOVEQ     #0,D1           ; Set mode 4
          MOVEQ     #-1,D2          ; Don't care (Read display type)
          MOVEQ     #MT_DMODE,D0
          TRAP      #1              ; MODE 4

          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVE.L    A1,A2           ; NULMSG pointer
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #SD_CLEAR,D0    ; CLS
          TRAP      #3              ; Clear COMMAND window

          MOVEQ     #1,D1           ; 8 Pixels wide
          MOVEQ     #0,D2           ; 10 Pixels high
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; Set font size

          MOVE.L    A2,A1           ; NULMSG pointer
          MOVE.W    UT_MTEXT,A2     
          JSR       (A2)            ; Print a zero length message

*--------------------------------------------------------------------
* Top of the main loop. 
* We start by:
*     Clearing the prompt window.
*     Setting the desired character sizes and
*     Displaying the message about F1, F2 and F3.
*--------------------------------------------------------------------
MAIN_LOOP BSR       DSPROMPT        ; Handle the PROMPT window stuff

*--------------------------------------------------------------------
*--------------------------------------------------------------------
MAIN_REG  BSR       DSPREG          ; Display register values

*--------------------------------------------------------------------
*--------------------------------------------------------------------
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
LEFT      MOVEQ     #-1,D1          ; Decrement by 1
          BRA.S     AMEMPTR

*--------------------------------------------------------------------
* Arrow RIGHT - increment current memory pointer.
*--------------------------------------------------------------------
RIGHT     MOVEQ     #1,D1           ; Increment by 1
          BRA.S     AMEMPTR

*--------------------------------------------------------------------
* Arrow DOWN - decrement current memory pointer by 8.
*--------------------------------------------------------------------
LEFT8     MOVEQ     #-8,D1          ; Decrement by 8
          BRA.S     AMEMPTR

*--------------------------------------------------------------------
* Arrow UP - increment current memory pointer by 8.
*--------------------------------------------------------------------
RIGHT8    MOVEQ     #8,D1           ; Increment by 8
          BRA.S     AMEMPTR

*--------------------------------------------------------------------
* Entry here means we prompt for an address, before dropping in.
*--------------------------------------------------------------------
ADD_MEM   BSR       GETADDR1

*--------------------------------------------------------------------
* Called from LEFT, RIGHT, UP, DOWN to change the address of the 
* current memory pointer. D1.L is the offset that will be added to
* the current address. The MEMORY WINDOW is redrawn to display the
* new data - 8 bytes below and 8 bytes above the current MP.
*--------------------------------------------------------------------
AMEMPTR   ADD.L     D1,MEMPTR(A6)   ; Adjust the memroy pointer
          BRA       MAIN_MEM        ; And go round again

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
* X: Execute current instruction.
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
* C: Call subroutine.
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
* T: Trace current instruction.
*--------------------------------------------------------------------
TRACE     MOVE.L    MEMPTR(A6),D1
          BCLR      #0,D1
          MOVE.L    D1,IM_PC(A6)
          BSET      #7,IM_SR(A6)
          JMP       RESTREGS

EXTRACE   BCLR      #7,(A7)
          JSR       SAVREGS
          BRA       MAIN_LOOP

*--------------------------------------------------------------------
* Set breakpoint helper. The breakpoints are stored in a table of
* a certain size, in the format:
*
* Address.L 
* Instruction.W
* ...
*
* We need to keep the instruction word safe as we are setting a TRAP
* #15 instruction at the breakpoint address to cause a jump into the
* monitor when executed.
*--------------------------------------------------------------------
BRKP_SUB  MOVE.L    MEMPTR(A6),D1   ; ???? -> TODO

BRKP_1    BCLR      #0,D1           ; Better be even
          MOVEQ     #BKPTABSIZ-1,D0 ; Maximum number of breakpoints
          LEA       BRKPTAB(A6),A1  ; Breakpoint table

*--------------------------------------------------------------------
* Loop through the breakpoint table looking for a free slot. If none
* are available, display an error message and go back to the main
* loop aand await a further command.
*--------------------------------------------------------------------
BRKP_LOOP TST.L     (A1)            ; Free slot?
          BEQ.S     ENTBRKP         ; Yes, add the new breakpoint
          ADDQ.L    #6,A1           ; No, skip to the next slot
          DBF       D0,BRKP_LOOP    ; And check that one too

          LEA       BRKFULMSG,A1    ; No more breakpoints message
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print it
          ADDQ.L    #4,A7           ; Tidy the return address
          BRA       MAIN_1          ; Back into the main loop

*--------------------------------------------------------------------
* We have found an empty slot in the breakpoint table, store the new
* breakpoint address in the slot.
*--------------------------------------------------------------------
ENTBRKP   MOVE.L    D1,(A1)+        ; Save the breakpoint address
          MOVE.L    D1,A0           ; Copy the address
          MOVE.W    (A0),(A1)       ; Save the instruction word
          MOVE.W    #$4E4F,(A0)     ; Insert a breakpoint TRAP #15
          RTS                       ; Done

*--------------------------------------------------------------------
* B: Set Breakpoint.
*--------------------------------------------------------------------
BREAKPNT  BSR.S     BRKP_SUB        ; Set the breakpoint, or barf
BRKP_END  BRA       MAIN_LOOP       ; Breakpoint set, go around again

*--------------------------------------------------------------------
* Error when we set too many breakpoints.
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

*--------------------------------------------------------------------
* Output a single line of 16 bytes, in hex and as characters from the
* address in A4.
*--------------------------------------------------------------------
DO_MEM    MOVE.L    A4,D1           ; Start address
          LEA       DISBUF(A6),A0   ; Disassembly buffer
          JSR       CN_ADDR         ; Buffer 5 bytes of the address
          MOVE.B    #':',(A0)+      ; Then a colon
          MOVE.B    #' ',(A0)+      ; Then a space (No! Really?)
          MOVEQ     #15,D2          ; 16 bytes to dump per line

DM_BYTE   MOVE.B    (A4)+,D1        ; Fetch a single byte
          JSR       CN_HEXB         ; Buffer it in hex
          MOVE.B    #' ',(A0)+      ; Then buffer a space
          DBF       D2,DM_BYTE      ; Do the remainder

          MOVE.B    #' ',(A0)+      ; A final space
          SUBA.W    #16,A4          ; Start address
          MOVEQ     #15,D2          ; 16 bytes again

DM_CHR    MOVE.B    (A4)+,D1        ; Fetch a byte
          CMPI.B    #$0A,D1         ; Newline?
          BNE.S     DM_CH1          ; No, buffer it
          MOVEQ     #0,D1           ; NULL = a blob

DM_CH1    MOVE.B    D1,(A0)+        ; Buffer a character
          DBF       D2,DM_CHR       ; Do the remainder
          RTS                       ; Done

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
* A: Alter memory.
*--------------------------------------------------------------------
ALT_MEM   MOVEQ     #10,D1          ; Newline character
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print it
          MOVE.L    MEMPTR(A6),A4   ; Current memory pointer

*--------------------------------------------------------------------
* Main loop for the Alter Memory command.
*--------------------------------------------------------------------
AM_LOOP   LEA       DISBUF(A6),A0   ; Output buffer address
          MOVE.L    A4,D1           ; Current memory pointer
          JSR       CN_ADDR         ; Show 5 bytes only of the address
          MOVE.B    #':',(A0)+      ; Then a colon
          MOVE.B    #' ',(A0)+      ; Then a space
          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVEQ     #-1,D3          ; Timeout
          LEA       DISBUF(A6),A1   ; Data to print
          MOVEQ     #7,D2           ; Data size 5 bytes + colon + space
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print address, colon, space
          BSR.S     HEX_LINE        ; ???? -> TODO
          BEQ       MAIN_LOOP
          MOVE.L    A4,MEMPTR(A6)
          BRA.S     AM_LOOP

*--------------------------------------------------------------------
* Fetch a line of input from the user. It should be valid hexadecimal
* characters. For each two bytes input, convert to hex and store in
* memory at the current memory pointer and beyond. The format of the
* input buffer will be either:
*
* hhhhhh<10> for an even number of hex characters, or
*  hhhhh<10> for an odd number.
*
* In the latter case, the buffer is preloaded with a leading zero to
* give:
*
* 0hhhhh<10> 
*
* Thus, giving a valid, even number of hex to convert.
*--------------------------------------------------------------------
HEX_LINE  LEA       DISBUF+1(A6),A1 ; Buffer start - leaves a space
;                                   ; for a leading zero if required
          MOVEQ     #DISBUFLEN-1,D2 ; Maximum buffer size
          MOVEQ     #IO_FLINE,D0    ; Prepare to fetch data
          TRAP      #3              ; Fetch!
          SUBQ.W    #1,D1           ; Did we get anything?
          BEQ.S     HEXL_END        ; No, just a newline - done.

*--------------------------------------------------------------------
* Prefix the odd number of hex charas with a zero character, if we
* read in an odd number of characters. I like this!
*--------------------------------------------------------------------
          LEA       DISBUF+1(A6),A1 ; Buffer start address 
          MOVE.L    A4,A5           ; Copy current memory pointer
          LSR.W     #1,D1           ; Bytes in input /2
          BCC.S     HL_1            ; It was an even length input
          MOVE.B    #'0',-(A1)      ; Odd length, high nibble is always '0'
          ADDQ.W    #1,D1           ; Account for it

HL_1      MOVE.W    D1,D4           ; Bytes to decode from hex characters

*--------------------------------------------------------------------
* Split the input into pairs of hex characters followed by a newline
* then convert the pair to a byte value to store in memory. On exit
* from READHEX the buffer pointer should be looking at a newline - 
* anything else is an invalid hex character and leads to an error.
*--------------------------------------------------------------------
GET_HLINE MOVE.B    2(A1),D6        ; Save third character = do byte pairs
          MOVE.B    #10,2(A1)       ; Insert a newline instead      
          JSR       READHEX         ; Convert from hex to a byte in D1
          CMPI.B    #10,(A1)        ; Valid?
          BNE.S     HEXL_ERR        ; No, do error handling
          MOVE.B    D1,(A5)+        ; Alter one byte in memory
          MOVE.B    D6,(A1)         ; Restore the saved byte 
          CMPI.B    #10,D6          ; Are we done yet?
          BNE.S     GET_HLINE       ; No, keep going
          MOVE.L    A5,A4           ; A4 is the new current memory pointer
          MOVE.W    D4,D1           ; D1 is the number of bytes stored.

HEXL_END  RTS                       ; Done

*--------------------------------------------------------------------
* Handle invalid hexadecimal characters in the user's input.
*--------------------------------------------------------------------
HEXL_ERR  ADDQ.W    #4,A7           ; Caller address tidied away
          LEA       BADHEXMSG,A1    ; MEssage to print
          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print the message
          BRA       MAIN_LOOP       ; Back to main loop

*--------------------------------------------------------------------
* This is the message to print when bad hex characters are found in
* the user's input.
*--------------------------------------------------------------------
BADHEXMSG DC.B      0,7,'Bad Hex'
          DS.W      0

*--------------------------------------------------------------------
* S: Search for a hexadecimal string.
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
* H: Convert decimal to Hexadecimal.
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
* G: Convert Hexadecimal to Decimal.
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
* Open a file. Enter here with:
*
* D4.L = Open mode:
*             0 = Old exclusive (OPEN)
*             1 = Old shared (OPEN_IN)
*             2 = New exclusive (OPEN_NEW)
*             3 = New overwrite (OPEN_OVER)
*             4 = Directory (OPEN_DIR)
* A0.L = Channel for prompt.
*
* If a file already exists, prompt the user to overwite it and if 
* this is chosen, delete the file and reopen it.
*
* On error, resume from MAIN_2 and if the user chooses not to trash
* an existing file, resume from MAIN_1 instead, otherwise just RTS.
*--------------------------------------------------------------------
OPEN_FILE LEA       FN_MSG,A1       ; 'File Name' prompt
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print prompt
          BSR       RDSTRING        ; Read the desired filename

OP_AGAIN  LEA       DISBUF(A6),A0   ; Get the filename
          MOVEQ     #-1,D1          ; This job's ID
          MOVE.L    D4,D3           ; Open Type 
          MOVEQ     #IO_OPEN,D0
          TRAP      #2              ; Open the file
          TST.L     D0              ; OK?
          BEQ.S     OP_OK           ; Yes indeed

          ADDQ.L    #8,D0           ; File already exists?
          BEQ.S     OP_EXISTS       ; Yes it does

          SUBQ.L    #8,D0           ; Reset the error code
          MOVE.L    CMDWND(A6),A0   ; COMMAND CHANEL
          MOVE.W    UT_ERR,A2
          JSR       (A2)            ; Print error message
          LEA       MAIN_2,A1       ; Where we want to be

OP_QUIT   ADDQ.W    #4,A7           ; Tidy stack return addresses
          JMP       (A1)            ; Skip to MAIN_2

*--------------------------------------------------------------------
* The requested output file already exists. Exit back to MAIN_1 if we
* choose not to overwite an existing file.
*--------------------------------------------------------------------
OP_EXISTS MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          LEA       EXIST_MSG,A1    ; Prompt 'File exists, overwrite'
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print prompt
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #SD_CURE,D0
          TRAP      #3              ; Enable cursor
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3              ; Fetch a single byte
          MOVE.W    D1,-(A7)        ; Save it
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print it back to channel
          LEA       MAIN_1,A1       ; Where to go if no overwrite
          MOVE.W    (A7)+,D1        ; Get the byte back again
          ANDI.B    #$DF,D1         ; Uppercase it
          CMPI.B    #'Y',D1         ; Overwite?
          BNE.S     OP_QUIT         ; No, exit from here
          MOVEQ     #10,D1          ; Yes - newline character
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print it
          LEA       DISBUF(A6),A0   ; Get the filename to delete
          MOVEQ     #-1,D1
          MOVEQ     #IO_DELET,D0
          TRAP      #2              ; Delete the existing file
          BRA.S     OP_AGAIN        ; And re-create it

OP_OK     RTS                       ; Done

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
* L: Memory dump command.
* Reads a start and end address into D4 and D5/D1 then dumps the area
* between the two in lines of 16 bytes as hex and character, if the
* characters are printable.
*--------------------------------------------------------------------
MEMDUMP_1 MOVEQ     #2,D4           ; OPEN_NEW mode
          BSR       OPEN_FILE       ; Open a file
          MOVE.L    A0,A5           ; Save the channel ID
          BSR       FIRSTLAST       ; Get start and end addresses
          MOVE.L    D4,A4           ; Start address in A4
          MOVE.L    A5,A0           ; Output channel ID
          LEA       MD_HEADR,A1     ; Prompt - headings
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print headings prompt

*--------------------------------------------------------------------
* Memory dump main loop.
*--------------------------------------------------------------------
MD1_LOOP  BSR       DO_MEM          ; Dump 16 bytes from (A4)
          LEA       DISBUF+56(A6),A1    ; ???? -> TODO
          MOVEQ     #15,D0          ; 16 bytes

MD1_LP1   CMPI.B    #$20,0(A1,D0.W) ; Less than a space character?
          BCS.S     MK_POINT        ; Yes, substitute a dot
          CMPI.B    #$7F,0(A1,D0.W) ; Control characters 
          BCS.S     PNT_NXT         ; No, skip

MK_POINT  MOVE.B    #'.',0(A1,D0.W) ; Buffer a dot to replace unprintables

PNT_NXT   DBF       D0,MD1_LP1      ; Do the remaining bytes
          MOVE.L    A5,A0           ; Output channel ID
          LEA       DISBUF(A6),A1   ; Start of buffer to be printed
          MOVEQ     #72,D2          ; Buffer size
          MOVEQ     #-1,D3          ; Timeout is infinite
          MOVEQ     #IO_SSTRG,D0    
          TRAP      #3              ; Print the string
          TST.L     D0              ; OK?
          BNE.S     MD1_END         ; No, skip
          MOVEQ     #10,D1          ; Newline character
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print it
          TST.L     D0              ; OK?
          BNE.S     MD1_END         ; No, skip
          CMPA.L    D5,A4           ; Reached the end yet?
          BLE.S     MD1_LOOP        ; No, do some more

MD1_END   MOVE.L    D0,D4           ; Save error code
          MOVEQ     #IO_CLOSE,D0
          TRAP      #2              ; Close output file
          MOVE.L    D4,D0           ; Retrieve error code

*--------------------------------------------------------------------
* Print an error message, according to the code in D0.L, to the 
* COMMAND channel. Then skip back into the main loop to wait for
* another command.
*--------------------------------------------------------------------
PRT_ERR   MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVE.W    UT_ERR,A2
          JSR       (A2)            ; Print message
          BRA       MAIN_2          ; Back to the main loop

*--------------------------------------------------------------------
* D: Dissassemble to a file.
*--------------------------------------------------------------------
DIS_FILE  MOVEQ     #2,D4           ; OPEN_NEW mode
          BSR       OPEN_FILE       ; Open a file
          MOVE.L    A0,A5           ; Save channnel ID

DIS_WRK   MOVE.L    CMDWND(A6),A0   ; COMMAND window
          LEA       WRKSP_MSG,A1    ; How much workspace prompt
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print the prompt
          BSR       READ_LINE       ; Fetch some input
          SUBQ.W    #1,D1           ; Get anything?
          BEQ.S     DIS_DEF         ; No, Allocate 1024 bytes workspace
          JSR       READDEC         ; Convert buffer to decimal number
          CMPI.B    #10,(A1)        ; Newline = valid numeric read
          BNE.S     DIS_WRK         ; Invalid number, keep prompting
          BRA.S     DIS_ALLOC       ; Allocate requested workspace size

*--------------------------------------------------------------------
* Allocate a buffer of 1024 bytes for the disassembly. We can also 
* enter at DIS_ALLOC with D1.L holding the desired space in bytes.
*--------------------------------------------------------------------
DIS_DEF   MOVE.L    #1024,D1        ; Assume 1024 bytes
DIS_ALLOC MOVEQ     #-1,D2          ; Owned by this job      
          MOVEQ     #MT_ALCHP,D0    ; Allocate memory trap
          TRAP      #1              ; Do it
          TST.L     D0              ; OK?
          BNE.S     DIS_WRK         ; No, bale out
          MOVE.L    A0,DATATBL(A6)  ; Save workarea address
          MOVE.L    A0,WRKSPTR(A6)  ; Current workarea pointer
          LEA       -$10(A0,D1.L),A0    ; 16 bytes from the end of the new buffer
          MOVE.L    A0,WRK_END(A6)  ; Save as end of workspace
          SF        WRKSPOV(A6)     ; Set a flag - no overflow yet = $00
          BSR       FIRSTLAST       ; Get first & last addresses to disassemble
          MOVE.L    D4,DISFRST(A6)  ; Save first address
          MOVE.L    D5,DISLAST(A6)  ; Save last address
          LEA       OPC_MSG,A1      ; Prompt 'Suppress opcode ? (Y/N)
          MOVE.L    CMDWND(A6),A0   ; COMMAND window is output
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print the prompt
          MOVEQ     #-1,D3
          MOVEQ     #SD_CURE,D0
          TRAP      #3              ; Enable the COMMAND cursor
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3              ; Fetch a byte
          ANDI.B    #$DF,D1         ; $DF = 1101 1111 = uppercase
          CMPI.B    #'Y',D1         ; Did we wish to suppress opcodes?
          SEQ       OPCODEFLG(A6)   ; $FF = yes if 'Y', $00 otherwise.
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print the users response (Y/N)
          LEA       DATA_MSG,A1     ; Prompt 'Data areas'
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print the prompt

*--------------------------------------------------------------------
* Loop around until the user stops giving us numbers, to find out any
* data areas within the range of addresses to be disassembled. These
* will be saved in the workarea buffer as long words:
*
* START ADDRESS
* END ADDRESS
* ...
*
* Each start address has the high byte = $FF for byte sized data,
* = $00 for word sized data or $01 for long sized data.  
*--------------------------------------------------------------------
DATA_LOOP BSR       FIRSTLAST       ; Get start and end addresses
          OR.L      D4,D1           ; D4 = start, D1 & D5 = last
          BEQ.S     DIS_START       ; Both zero = do the disassembly
          BSR       GET_SIZE        ; D1 = Byte -1, word 0, or long 1
          ROR.L     #8,D1           ; D1 = -1, 0 or $01000000
          ANDI.L    #$FF000000,D1   ; D1 = $FF000000, 0 or $01000000
          OR.L      D4,D1           ; Set the start address high byte to 
;                                   ; $FF for byte
;                                   ; $00 for word
;                                   ; $01 for long
          JSR       ADD_WRK         ; Save D1.L in the workarea buffer
          MOVE.L    D5,D1           ; End address
          JSR       ADD_WRK         ; Save D1.L in the workarea buffer
          TST.B     WRKSPOV(A6)     ; Workspace ok still?
          BEQ.S     DATA_LOOP       ; Yes.

*--------------------------------------------------------------------
* We have unfortunately overflowed the allocated workspace for a 
* disassembly. Advise the user, reclaim the workspace that we had
* allocated earlier and close the output file.
*--------------------------------------------------------------------
WRKSP_ERR MOVE.L    CMDWND(A6),A0   ; COMMAND channel
          LEA       WRKERRMSG,A1    ; Prompt 'Workspace Overflow'
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print prompt
          MOVE.L    DATATBL(A6),A0  ; Workspace address
          MOVEQ     #MT_RECHP,D0
          TRAP      #1              ; Reclaim workspace buffer
          MOVE.L    A5,A0           ; Output file ID
          MOVEQ     #IO_CLOSE,D0
          TRAP      #2              ; Close it
          BRA       MAIN_1

*--------------------------------------------------------------------
* An error mesage for workspace overflow conditions.
*--------------------------------------------------------------------
WRKERRMSG DC.B      0,18,'Workspace Overflow'

*--------------------------------------------------------------------
* D: Disassemble to screen. Enter here from disassemble to file with
* A5 holding the ouput file ID too.
*--------------------------------------------------------------------
DIS_START MOVE.L    WRKSPTR(A6),LBL_TBL(A6) ; Save ???? -> TODO
          SF        DISMOD(A6)      ; Flag - $00 set in DISMOD.
          MOVE.L    DISFRST(A6),A4  ; Address to be disassembled

DIS1_LP   MOVE.L    A5,-(A7)        ; Save output channel ID
          JSR       DISASSEM        ; Disassemble address (A4)
          MOVE.L    (A7)+,A5        ; Restore worker
          TST.B     WRKSPOV(A6)     ; Did we overflow workspace?
          BNE.S     WRKSP_ERR       ; Sadly, yes
          CMPA.L    DISLAST(A6),A4  ; No - have we finished?
          BLS.S     DIS1_LP         ; No, do some more
          ADDQ.B    #1,DISMOD(A6)   ; Flag - $00 set in DISMOD
          MOVE.L    DISFRST(A6),A4  ; Get the start address again
          MOVE.L    A5,-(A7)        ; Save the worker again        

DIS2_LP   JSR       DISASSEM        ; Disassemble address (A4)
          MOVE.L    A0,D2           ; ???? -> TODO
          LEA       DISBUF(A6),A1   ; Disassembly buffer start
          TST.B     OPCODEFLG(A6)   ; Are we suppressing opcodes?
          BEQ.S     DIS_OUT         ; No we are not
          LEA       LBL_FLD(A6),A1  ; We are, just do the labels etc

DIS_OUT   SUB.L     A1,D2           ; How many bytes to send?
          MOVE.L    (A7),A0         ; Output channel ID
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Send a string of bytes
          TST.L     D0              ; OK?
          BNE.S     DIS_QUIT        ; No, skip
          MOVEQ     #10,D1          ; NEwline character
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Send the newline
          TST.L     D0              ; OK?
          BNE.S     DIS_QUIT        ; No, skip
          CMPA.L    DISLAST(A6),A4  ; Are we done yet?
          BLS.S     DIS2_LP         ; No, do some more

*--------------------------------------------------------------------
* Either an error or we are done when we arrive here.
*--------------------------------------------------------------------
DIS_QUIT  MOVE.L    D0,D4           ; Error code is saved
          MOVE.L    (A7)+,A0        ; Output channel ID
          MOVEQ     #IO_CLOSE,D0
          TRAP      #2              ; Close it
          MOVE.L    DATATBL(A6),A0  ; Work area
          MOVEQ     #MT_RECHP,D0
          TRAP      #1              ; Reclaim it
          MOVE.L    D4,D0           ; Restore error code
          BRA       PRT_ERR         ; Do error message then -> main loop

*--------------------------------------------------------------------
* Prompt message to ask for a (new) workspace size.
*--------------------------------------------------------------------
WRKSP_MSG DC.B      0,14,'Workspace Size'

*--------------------------------------------------------------------
* Prompt message to asik if the opcode should be suppressed or not.
*--------------------------------------------------------------------
OPC_MSG   DC.B      0,24,'Suppress opcode ? (Y/N) '

*--------------------------------------------------------------------
* Prompt when user needs to enter a list of data areas in amongst the
* memory range to be disassembled.
*--------------------------------------------------------------------
DATA_MSG  DC.B      0,12,$0A,'Data areas',$0A

*--------------------------------------------------------------------
* E: Eaxmine a job.
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
          BNE       PRT_ERR         ; Do error message then -> main loop
          MOVE.L    D7,D1

GET_JB    MOVE.L    $28068,A0
          LSL.W     #2,D1
          ADDA.W    D1,A0
          CMPA.L    $2806C,A0
          BGE.S     BAD_JOB
          TST.B     (A0)
          BGE.S     COPY_REG

BAD_JOB   MOVEQ     #-2,D0
          BRA       PRT_ERR         ; Do error message then -> main loop

COPY_REG  TRAP      #0
          BSR.S     EXAM_REGS
          ANDI      #$DFFF,SR
          BSR       DSPREG
          BSR       DSPMEM
          BSR       DSPDIS
          BRA       MAIN_2

*--------------------------------------------------------------------
* ???? -> TODO
*
* Entry here is either with A0 = SV_JBBAS (base of jobs table) or
* SV_JBPNT Current job's job table entry - depending on the caller.
*--------------------------------------------------------------------
EXAM_REGS MOVE.L    A0,JBPNT(A6)    ; Current job, or SuperBASIC
          MOVE.L    (A0),A0         ; Base address of the job
          LEA       $20(A0),A0      ; Storage in job, for D0
          MOVE.L    A6,A1           ; A6 = Our dataspace = register storage
          MOVEQ     #15,D0          ; 16 Registers to store

*--------------------------------------------------------------------
* Copy the job being monitored's registers, SR and PC from its own
* job header into our register storage area. 
*--------------------------------------------------------------------
COPY_R_LP MOVE.L    (A0)+,(A1)+     ; Copy a job's register to our storage
          DBF       D0,COPY_R_LP    ; Repeat for all 16 registers

          MOVE.W    (A0)+,IM_SR(A6) ; And the job's Status Register
          MOVE.L    (A0),(A1)+      ; And the job's program counter
          MOVE.L    (A0)+,MEMPTR(A6)    ; The job's PC again.
          ADDQ.W    #2,A0           ; Skip unused word in job's header
          MOVE.L    A0,(A1)+        ; Store the job's JB_END.

          LEA       -$68(A0),A0     ; Start of job again
          LEA       EXTAB-$54(A6),A2    ; ???? -> TODO
          MOVE.L    A2,$1C(A0)      ; JB_TRAPV - vector table
          CMPA.L    $28010,A0       ; SV_BASIC = Start of SuperBASIC area
          BEQ.S     ST_TP_1         ; Skip if SuperBASIC is the job
          ADDA.L    (A0),A0         ; JB_LEN = job length in header
          BRA.S     ST_TP

*--------------------------------------------------------------------
* We only come here if looking at SuperBASIC. We get the top end of 
* SuperBASIC's alocated memory etc = SV_TRNSP.
*--------------------------------------------------------------------
ST_TP_1   MOVE.L    $28014,A0       ; SV_TRNSP = Start of jobs in memory

*--------------------------------------------------------------------
* We have, in A0, the top end of the job, or the start of the 
* transient memeory are if looking at SuperBASIC. The end of the job
* in other words.
*--------------------------------------------------------------------
ST_TP     MOVE.L    A0,(A1)         ; Save the top end address
          MOVE.L    A7,A0           ; Isn't this OUR A7? ???? -> TODO
          ADDQ.W    #4,A0           ; Skip our return address
          MOVE.L    A0,IM_SSP(A6)   ; Save the A7 register in storage
          RTS                       ; Done

*--------------------------------------------------------------------
* Prompt the user to enter the desired sizes for any data areas in a
* disassembly. Enter here with A0 holding the desired channel ID for
* input/output.
* Exit with D1.B = -1 for byte sized data areas
*                   0 for word sized data areas
*                   1 for long sized data areas.
*--------------------------------------------------------------------
GET_SIZE  MOVE.L    D4,-(A7)        ; Save worker
          LEA       SIZMSG,A1       ; Prompt 'Size ? (B,W,L) '
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print prompt
          MOVEQ     #SD_CURE,D0     ; Enable cusror
          TRAP      #3
GTSIZ_1   MOVEQ     #IO_FBYTE,D0    ; Fetch a byte
          TRAP      #3
          MOVEQ     #-33,D0         ; $DF = 1101 1111 = uppercase
          AND.B     D0,D1           ; Convert to uppercase
          MOVEQ     #-1,D4          ; Assume byte
          CMPI.B    #'B',D1         ; Correct?
          BEQ.S     GTSIZ_END       ; Yes

          MOVEQ     #0,D4           ; Assume word
          CMPI.B    #'W',D1         ; Correct?
          BEQ.S     GTSIZ_END       ; Yes

          MOVEQ     #1,D4           ; Assume long
          CMPI.B    #'L',D1         ; Correct?
          BNE.S     GTSIZ_1         ; Yes

GTSIZ_END
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print uppercase response character
          MOVEQ     #10,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; And a newline
          MOVE.B    D4,D1           ; D1 is the size flag
          MOVE.L    (A7)+,D4        ; Restore worker
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
          DC.B      '                       ', 127,' 1986, 87 BY JAN BREDENBEEK',10,10
          DC.B      'COMMANDS:',10,10
          DC.B      188,189,190,191,': CHANGE MEMORY POINTER            ALT-',188,189,190,191,': CHANGE REGISTER POINTER',10
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


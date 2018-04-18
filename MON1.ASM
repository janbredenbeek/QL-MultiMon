* MULTIMON
* QL MONITOR/DISASSEMBLER
* Copyright (C) 1986-1987 by Jan Bredenbeek
* Parts of the source code (C) 2017-2018 by Norman Dunbar and Jan Bredenbeek
* Released under the GPL v3 license in 2017

          INCLUDE   WIN1_QDOS_IN    QDOS Constants
          INCLUDE   MULTIMON_INC    Macros and definitions

*--------------------------------------------------------------------
* External definitions
*--------------------------------------------------------------------

* (we've moved the variable definitions to MULTIMON_INC)

*--------------------------------------------------------------------
* External references
*--------------------------------------------------------------------          
          
          XREF      DISASSEM
          XREF      CN_ADDR
          XREF      CN_HEXB
          XREF      CN_HEXL
          XREF      ADD_WRK

          DATA      DATASPACE       The dataspace required for this application

          SECTION   MON_CODE        Generate relocatable code from now on

*--------------------------------------------------------------------
* This code can be LRESPR'd, in which case we get the 'MON' command,
* or, can be EXEC'd in which case, we get a job. Smart!
*--------------------------------------------------------------------
* Standard QDOS job header. 
*--------------------------------------------------------------------
MON_BASE  BRA.S     START

*--------------------------------------------------------------------
* Use the filler long word to hold the base address of the job's 
* dataspace - if it was started by EXEC. Otherwise, it's random.
* 20171213-JB: We need to get rid of this, it's dirty programming...
*--------------------------------------------------------------------
MON_VARS  DC.L      0               ; Storage for variables address
          DC.W      $4AFB           ; Job flag and name size
MON_ID    STRING$   {'MULTIMON'}    ; Job name
                                    
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
          LEA       MON_VARS,A0     ; ptr to variable storage
          TST.L     (A0)            ; if zero, it's safe to use
          BEQ.S     VARS_OK
          LEA       VARSMSG,A1      ; But if nonzero, this copy is 
          SUBA.L    A0,A0           ; already being used
          MOVE.W    UT_MTEXT,A2     ; so print error message
          JSR       (A2)
          MOVEQ     #-1,D0          ; ... and exit 'not complete'
          BRA       QMON_1
VARS_OK   MOVE.L    A6,(A0)         ; store ptr to variable storage
          MOVE.L    D1,OWN_JB(A6)   ; set our own job ID

*--------------------------------------------------------------------
* Set up the register window contents from a template.
* We'll do it neatly this time so we'll copy the template to a buffer
* in the data area rather than poke into the template itself!
*--------------------------------------------------------------------
          LEA       REGBUF(A6),A0   ; Point to register buffer
          LEA       REGMSG,A1       ; Our register window template
          MOVE.W    #REGEND-REGMSG,D1 ; length
COPYRGDS  MOVE.B    (A1)+,(A0)+     ; copy over the template
          SUBQ.W    #1,D1
          BNE       COPYRGDS
*--------------------------------------------------------------------
* Enter supervisor mode and copy the register contents of job 0
* (probably S*BASIC) into our storage.
*--------------------------------------------------------------------
          TRAP      #0              ; Enter supervisor mode
          MOVEQ     #0,D1           ; job 0 (SBASIC)
          JSR       EXAM_REGS       ; Copy registers etc to storage
          ANDI      #$DFFF,SR       ; Clear Supervisor bit

*--------------------------------------------------------------------
* We don't yet have a current memory address, but we assume that we
* are in relative mode.
*--------------------------------------------------------------------          
          CLR.L     MEMPTR(A6)      ; Current memory address
          ST        RELMOD(A6)      ; $FF = Relative, $00 = Absolute

*** OBSOLETE CODE ***          
*          LEA       EXTABEND(A6),A7 ; Top of Exception vector table
*          MOVEQ     #10,D0          ; Counter for 11 exception vectors

*--------------------------------------------------------------------
* Loop around for TRAP #15 to TRAP #5. Each of these points to the
* EXBRKPNT code and will fire a breakpoint if executed.
*--------------------------------------------------------------------
*SETTRAPS  PEA       EXBRKPNT        ; Code for this trap's vector
*          DBF       D0,SETTRAPS     ; Do all of #15 down to #5

*--------------------------------------------------------------------
* The rest of the exception vector table follows.
*--------------------------------------------------------------------
*          PEA       EXINTL7         ; Interrupt level 7
*          PEA       EXTRACE         ; Trace exception
*          PEA       EXPRIVV         ; Privilege violation
*          PEA       EXTRAPV         ; TRAPV
*          PEA       EXCHK           ; CHK
*          PEA       EXDIVZER        ; Divide by zero exception
*          PEA       EXILLINST       ; ILLEGAL instruction exception
*          PEA       EXADDERR        ; Address error exception          
*          MOVE.L    A7,A1           ; EXTAB = Exception vectors address
*          LEA       DATASPACE(A6),A7 ; Reset stack pointer

*--------------------------------------------------------------------
* Fill in our own exception vector table, which we will also use for
* any job that we decide to monitor.
*--------------------------------------------------------------------

          LEA       EXTABLE(PC),A0  ; Our table of exception handlers
          LEA       EXTABEND(A6),A1 ; End of exception table

*--------------------------------------------------------------------
* Fill in the exception table by reading the relative address of our
* handlers and converting them to absolute addresses
*--------------------------------------------------------------------          
          MOVEQ     #NUMVECS-1,D0   ; Number of vectors - 1
SETVECS   MOVE.W    (A0)+,D1        ; Get offset in D1 (rel to PC)
          LEA       -2(A0,D1.W),A2  ; Compensate for postincrement
          MOVE.L    A2,-(A1)        ; Set vector address
          DBF       D0,SETVECS      ; Loop for all vectors
*--------------------------------------------------------------------
* A1 now points to start of exception vector table!
*--------------------------------------------------------------------          
          MOVEQ     #-1,D1          ; For the current job
          MOVEQ     #MT_TRAPV,D0     
          TRAP      #1               ; Set the exception vectors                    
          
*--------------------------------------------------------------------
* There are 6 separate windows to be opened at startup. D7 has the
* count and A4 points at the first window definition, A5 points at 
* the start of a consecutive storage area for the channel IDs. 
*--------------------------------------------------------------------
          MOVEQ     #5,D7           ; 6 windows to open
          LEA       WNDPRMS,A4      ; PROMPT window definition
          LEA       PROMPTWND(A6),A5    ; First window's storage area

*--------------------------------------------------------------------
* A loop to open the 5 windows used by the monitor. 
*--------------------------------------------------------------------
OPEN_LP   MOVE.L    A4,A0           ; Pointer to Window definition
          LEA       WNDPAR1,A1      ; Red border, white text on black
          TST.W     D7              ; Only the last window has different
          BNE.S     DO_OPEN         ; attributes - skip if not that one

*--------------------------------------------------------------------
* The last window opened is the AUX window and it has a different set
* of attributes
*--------------------------------------------------------------------
          LEA       WNDPAR2,A1      ; Black border, white text on red

*--------------------------------------------------------------------
* Open a single window and set its attributes. A0 is the window's
* definition and A1 is the attributes.
*--------------------------------------------------------------------
DO_OPEN   MOVE.W    UT_WINDW,A2     ; Open, paper, strip, ink, cls
          JSR       (A2)            ; Do it all
          BNE       QMON_1          ; Exit from monitor on error 
          MOVE.L    A0,(A5)+        ; Save this channel ID.
          MOVEQ     #3,D0           ; Prepare next window definition
          ADD.W     (A4),D0         ; Size of the one just opened
          BCLR      #0,D0           ; Make even
          ADDA.W    D0,A4           ; The next window definition

          DBF       D7,OPEN_LP      ; Do the rest

*--------------------------------------------------------------------
* Clear out a couple of storage areas and then enter a loop to zero
* out the entire breakpoint table - this is necessary as adding a new
* breakpoint requires a slot value of zero.
*--------------------------------------------------------------------
          CLR.W     REGPTR(A6)      ; No current register yet
          CLR.W     HEXSTR(A6)      ; ???? -> TODO
          LEA       BRKPTAB(A6),A0  ; Start of breakpoint table
          MOVEQ     #BKPTABSIZ-1,D0 ; Number of slots (minus 1)

*--------------------------------------------------------------------
* Loop to clear the breakpoint table slots.
*--------------------------------------------------------------------
CLRBKTAB  CLR.L     (A0)+           ; Clear the breakpoint address
          CLR.W     (A0)+           ; Clear the instruction word
          DBF       D0,CLRBKTAB     ; Do the whole table
          
*--------------------------------------------------------------------
* Set up ready to print a signon message when we finish starting up
* and begin the first execution of the main loop.
*--------------------------------------------------------------------
BAS_ENT2  LEA       SIGNON,A1       ; Message to display on entry
          BRA       MAIN_ERR        ; Display it, and enter the loop
          
*--------------------------------------------------------------------
* The entry point for the SuperBASIC 'MON' command if we LRESPR'd the
* code. All it does is creates a job anyway - so we might as well do
* an EXEC as we can at least clear it out when we are done as opposed
* to having the code lying around in memory "forever".
*--------------------------------------------------------------------
BAS_ENT   MOVEQ     #0,D1           ; This job, SuperBASIC, owns it
          LEA       MON_BASE,A1     ; Start address of the job's code
          MOVEQ     #0,D2           ; No code space required
          MOVE.L    #DATASPACE,D3   ; Data space requirement
          MOVEQ     #MT_CJOB,D0     ; Create, don't activate, a new job
          TRAP      #1              ; returning D1 with the new job id
          TST.L     D0              
          BNE.S     BAS_QUIT        ; Bale out on errors creating job
          MOVEQ     #32,D2          ; Priority = standard = 32
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #MT_ACTIV,D0    ; D1 = job id to activate
          TRAP      #1              ; Start the monitor
BAS_QUIT  RTS                       ; Exit back to SuperBASIC
   
*--------------------------------------------------------------------
* The procedure (and function) definition block to link the new MON
* procedure into SuperBASIC. Not used if this code is running as a
* job, or if this code is run in a non-zero job id. (SuperBASIC = 0.)
*--------------------------------------------------------------------   
PROCTAB   DC.W      1               ; One PROCedure
          DC.W      BAS_ENT-*       ; Where it starts
          DC.B      3,'MON'         ; What it is called
          DS.W      0               ; No FuNctions (DC not DS!)
          DC.W      0,0,0           ; End of FNs, end of list.   

*--------------------------------------------------------------------
* Table of our exception handlers. This holds relative addresses in
* reverse order. The initialisation code will convert these to
* absolute addresses to fill in the exception table
*--------------------------------------------------------------------
EXTABLE   DC.W      EXBRKPNT-*      ; Trap #5 to #15 - Breakpoint
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXBRKPNT-*
          DC.W      EXINTL7-*       ; Interrupt level 7
          DC.W      EXTRACE-*       ; Trace exception
          DC.W      EXPRIVV-*       ; Privilege violation
          DC.W      EXTRAPV-*       ; TRAPV exception
          DC.W      EXCHK-*         ; CHK exception
          DC.W      EXDIVZER-*      ; Division by zero
          DC.W      EXILLINST-*     ; Illegal instruction
          DC.W      EXADDERR-*      ; Address error
          
*--------------------------------------------------------------------
* This is the PROMPT window. (D7 = 5 in DO_OPEN)
* The uppermost window displays a minimal help prompt all the time.
*--------------------------------------------------------------------
WNDPRMS   DC.W      16
          DC.B      'SCR_452X12A32X16'  PROMPT WINDOW
          DS.W      0

*--------------------------------------------------------------------
* This is the REGISTER window. (D7 = 4 in DO_OPEN)
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
          DC.B      'SCR_452X112A32X28' REGISTER WINDOW
          DS.W      0
          
*--------------------------------------------------------------------
* This is the MEMORY window. (D7 = 3 in DO_OPEN)
* The two line MEMORY WINDOW displays 17 byes around the address of
* the memory pointer. There are 8 below and 8 above, which is 17 as
* the current MP is there too, and highlighted.
*--------------------------------------------------------------------          
          DC.W      17
          DC.B      'SCR_452X22A32X140' MEMORY WINDOW
          DS.W      0
          
*--------------------------------------------------------------------
* This is the COMMAND window. (D7 = 2 in DO_OPEN)
* The COMMAND WINDOW is where commands are entered and where the
* sign on message is displayed at startup.
*--------------------------------------------------------------------          
          DC.W      17
          DC.B      'CON_452X42A32X174' COMMAND WINDOW
          DS.W      0
          
*--------------------------------------------------------------------
* This is the DISSASSEM window. (D7 = 1 in DO_OPEN)
* This window is above the COMMAND WINDOW and displays a disassembly
* of the instruction at the current MP's address.
*--------------------------------------------------------------------          
          DC.W      17
          DC.B      'SCR_452X12A32X162' DISASSEM WINDOW
          DS.W      0
          
*--------------------------------------------------------------------
* This is the AUXILIARY window. (D7 = 0 in DO_OPEN)
* The AUXILIARY WINDOW for Help and disassembly etc. 
*--------------------------------------------------------------------          
          DC.W      17
          DC.B      'SCR_448X190A32X27' AUX WINDOW
          DS.W      0
          
*--------------------------------------------------------------------
* Window parameters for the main windows:
*
* Border Colour = Red
* Border Width = 1
* Paper/Strip Colour = Black
* Ink Colour = White
*--------------------------------------------------------------------          
WNDPAR1   DC.B      0,0,0,7

*--------------------------------------------------------------------
* Window parameters for the help window:
*
* Border Colour = Black
* Border Width = 0
* Paper/Strip Colour = Red
* Ink Colour = White
*--------------------------------------------------------------------
WNDPAR2   DC.B      0,0,2,7

*--------------------------------------------------------------------
* A small sign on message displayed at startup in the COMMAND WINDOW.
*--------------------------------------------------------------------
SIGNON    STRING$   {'MULTIMON V[version]',LF,127,' 1986-2017 Jan Bredenbeek',LF}
VARSMSG   STRING$   {'MULTIMON already active',LF}

*--------------------------------------------------------------------
* Save the registers for later display. Called whenever we hit an
* exception in a monitored job. This means that register values are
* as per the monitored job (or at least, the one that caused the
* exception) and not yet the monitor's registers as the scheduler
* has not been run to reschedule the current job back to the monitor.
*
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
SAVREGS   MOVEM.L   D0-D2/A0/A5-A6,-(A7) ; Save some registers
          MOVEQ     #MT_INF,D0      ; find address of system vars
          TRAP      #1
          MOVE.L    A0,A5           ; move to A5
          MOVE.L    $64(A5),A6      ; ptr to current entry in SV.JBTAB
          MOVE.L    (A6),A6         ; get job header's address
          MOVEM.L   (A7)+,D0-D2/A0  ; restore registers
          MOVEM.L   D0-D7/A0-A4,$20(A6) ; save them in job header
          LEA       $54(A6),A6      ; Address of JB.A5
          MOVE.L    (A7)+,(A6)+     ; Save value of A5
          MOVE.L    (A7)+,(A6)+     ; Id. for A6
          MOVE      USP,A1          ; get USP = A7 of job
          MOVE.L    A1,(A6)+        ; and store this
          MOVE.L    (A7)+,A4        ; Return address from SAVREGS
          MOVE.W    (A7)+,(A6)+     ; Save SR
          MOVE.L    (A7)+,(A6)+     ; and PC of job
          MOVE.L    MON_VARS,A6     ; get ptr to our data storage
          MOVEQ     #MT_INF,D0      ; get ID of offending job
          TRAP      #1
          JSR       EXAM_REGS       ; now copy regs to our storage
          LEA       DATASPACE(A6),A0 ; end of our dataspace
          MOVE      A0,USP          ; set our user stack pointer
          MOVE.L    OWN_JB(A6),D1   ; get our own job ID
***
***       TODO:     Check and cleaning up needed here!
***          
          BSR.S     FINDJB          ; Get details of MultiMon job
          MOVE.L    $64(A5),A2      ; Get ptr to current job header
          CMPA.L    A0,A2           ; Are we examining ourself?
          BEQ.S     GO_MON          ; yes

*--------------------------------------------------------------------
* Suspend the monitored job, assuming it's not the monitor itself and
* inddicate nobody is waiting for this job.
*--------------------------------------------------------------------
          MOVE.L    (A2),A2         ; Get base of job header
          MOVE.W    #-1,$14(A2)     ; Set JB.STAT to 'suspended'
          SF        $17(A2)         ; 
GO_MON    MOVE.L    A0,$64(A5)      ; Now make MultiMon 'current job'
          CLR.W     $14(A1)         ; Signal 'not suspended'
          MOVE.L    $0C(A1),D0      ; Get address of flag of waiting job
          BEQ.S     GO_MON1         ; ... if any ...
          MOVE.L    D0,A0
          SF        (A0)            ; Clear this location
GO_MON1   MOVE      #$0000,SR       ; Go to user mode
          JMP       (A4)            ; and jump to the saved return address

*--------------------------------------------------------------------          
* Find details of a job, given its ID in D1
* Returns: A0 ptr to job table entry
*          A1 ptr to job header
*          D0 0 OK, ERR.NJ if invalid ID
*--------------------------------------------------------------------

FINDJB    MOVE.L    D1,-(A7)        ; Save D1
          MOVEQ     #MT_INF,D0
          TRAP      #1              ; Get system variables address
          MOVE.L    (A7),D1         ; Restore job ID
          CMP.W     $62(A0),D1      ; Test against SV.JBMAX
          BHI.S     FJ_ERR          ; ERR.NJ if higher
          MOVE.L    $68(A0),A0      ; Get base of job table
          LSL.W     #2,D1           ; multiply job number by 4
          ADDA.W    D1,A0           ; A0 now points to table entry
          TST.B     (A0)            ; A negative value means no such job
          BLT.S     FJ_ERR          ; so return ERR.NJ
          MOVE.L    (A0),A1         ; Get job header address
          SWAP      D1              ; Job tag now in lower word of D1
          TST.W     D1              ; A tag of 0 means 'wildcard match'
          BEQ.S     FJ_OK           ; so return OK
          CMP.W     $10(A1),D1      ; Else, match against JB.TAG
          BNE.S     FJ_ERR
FJ_OK     MOVEQ     #0,D0           ; No error, return OK
          BRA.S     FJ_END
FJ_ERR    MOVEQ     #-2,D0          ; Exit point when 'invalid job'
FJ_END    MOVE.L    (A7)+,D1
          TST.L     D0
          RTS
          
*--------------------------------------------------------------------
* We get here in Supervisor mode.
*
* Check the current job to see if it is active, or the monitor, error
* out in either case.
* Fiddle about in the current job's header to set the following:
*    Job is being waited on by another
*    The waiting job is the monitor
*    Priority is set, if not, set it to 32.
* Fiddle about in our own job's header to set the following:
*    Job is waiting for another to complete
*    Set the PC to be MAIN_REST on reactivation
*    Clear the SR.
*--------------------------------------------------------------------
RESTREGS  MOVEQ     #MT_INF,D0
          TRAP      #1
          MOVE.L    A0,A5
          TRAP      #0
          MOVE.L    OWN_JB(A6),D1
          BSR       FINDJB
          MOVE.L    A0,A2
          MOVE.L    EXJB_ID(A6),D1
          BSR       FINDJB
          BNE.S     RR_BADJB
          MOVE.L    A0,$64(A5)
          MOVE.L    (A2),A2
          
*--------------------------------------------------------------------
* Show the monitor to be waiting for another job, and set the SR to
* zero (all off) and the PC = MAIN_REST when we are next reactivated.
*--------------------------------------------------------------------          
          MOVE.W    #-2,$14(A2)
          LEA       MAIN_REST,A0
          MOVE.L    A0,$62(A2)
          CLR.W     $60(A2)
          
*--------------------------------------------------------------------
* Set the monitored job to have a job (the monitor) waiting on it and
* make sure that the priority will increment.
*--------------------------------------------------------------------
          TAS       $17(A1)
          MOVE.L    OWN_JB(A6),$18(A1)
          TST.B     $13(A1)
          BNE.S     REL_JB
          MOVE.B    #32,$13(A1)

*--------------------------------------------------------------------
* Ready to release the monitored job. We set it to be active first,
* then push it's PC and SR onto the supervisor stack ready for the
* RTE, set it's USP to what it was before we interrupted it with the
* monitor, restore its registers from our storage and when the RTE
* fires, the job will run from its PC and with the SR set as per what
* we put on the SSP.
*--------------------------------------------------------------------   
REL_JB    CLR.W     $14(A1)
          MOVE.L    IM_PC(A6),-(A7)
          MOVE.W    IM_SR(A6),-(A7)
          MOVE.L    IM_USP(A6),A0
          MOVE      A0,USP
          MOVEM.L   IM_D0(A6),D0-D7/A0-A6
          RTE
          
*--------------------------------------------------------------------
* We arrive here if the current job happens to be inactive or if it
* is the monitor. Clear supervisor mode and display an 'invalid job'
* error.
*--------------------------------------------------------------------
RR_BADJB  ANDI      #$DFFF,SR       ; Clear supervisor mode
          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVEQ     #10,D1          ; Newline
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #IO_SBYTE,D0    
          TRAP      #3              ; Print newline
          MOVEQ     #-2,D0          ; Error 'Invalid Job'
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
* (Ra.s,Rb.s...) = Add registers and use result as address.
*
* Returns the address in D1.L and sets D0 and the Z flag to indicate
* errors.
*
* D4 is the running total while working out the address and D3 is the
* sign indicator - $00 = positive, $FF = negative.
*
* (ANTLR4) GRAMMAR for an address expression:
*
* <x>?  = <x> is optional - zero or one time.
* <x>+  = <x> is mandatory, 1 or more times.
* <x>*  = <x> is optional, zero or more times.
* A | B = A or B, one or the other, see also [AB].
* [AB]  = A or B, one or the other, see also A | B.
* A-B   = Anything from A to B inclusive.
* 'X'   = The actual character X.
*
* <expression> = <op>? <term> (<expression>)*
*
* <op>          : [+-]
* <size>        : '.' [WwLl]
* <regname>     : [DA] [01234567]
* <reg>         : <regname> <size>?
* <term>        : <hexnum> | <decnum> | <binnum> | <regexpr> |
*                 <currmemptr> | <baseptr>
* <hexnum>      : <hexdigit>+
* <decnum>      : <digit>+
* <binnum>      : <bindigit>+
* <regexpr>     : '(' <reg> (',' <reg>)*  ')'
* <currmemptr>  : [Mm]
* <baseptr>     : [Ss]
* <digit>       : [0-9]
* <hexdigit>    : [A-Fa-f0-9]
* <bindigit>    : [01]
*
* In otherwords, an optional plus or minus operation on a term 
* repeated zero or more times.
*--------------------------------------------------------------------
GET_ADDR  MOVEM.L   D2-D4/A0-A1,-(A7)   ; Save workers
          BSR.S     READ_LINE       ; Read some text from the user
          MOVEQ     #0,D4           ; Clear the running total

*--------------------------------------------------------------------
* For the start/next part of the expression, do we have a '+' or '-'
* if so, set D3.B accordingly.
*--------------------------------------------------------------------
GTAD_LP   SF        D3              ; Sign byte: 0 = +ve, $FF = -ve
          MOVE.B    (A1),D0         ; Get a character
          SUBI.B    #'+',D0         ; Is it a plus?
          BEQ.S     GTAD_2          ; Yes, skip it.
          SUBQ.B    #2,D0           ; Is it a minus?
          BNE.S     GTAD_3          ; No, skip
          ST        D3              ; Indicate a negative, D3.B = $FF

*--------------------------------------------------------------------
* Skip past the sign character.
*--------------------------------------------------------------------
GTAD_2    ADDQ.W    #1,A1           ; Increment buffer pointer

*--------------------------------------------------------------------
* Check if we are done which is indicated by a linefeed as the (new)
* current character.
*--------------------------------------------------------------------
GTAD_3    MOVE.B    (A1),D0         ; Grab the current character
          CMPI.B    #10,D0          ; Linefeed?
          BEQ       GTAD_E          ; Yes, we are done, bale out.

*--------------------------------------------------------------------
* We are not yet done, so what type of <term> are we dealing with?
* See above for details of the grammar.
* Unless we find different, we assume that this <term> is a <hexnum>.
*--------------------------------------------------------------------
          CMPI.B    #'%',D0         ; Is this <term> a <binnum>?
          BEQ.S     GTAD_P          ; Yes

          CMPI.B    #'&',D0         ; Is this <term> a <decnum>?
          BEQ.S     GTAD_D          ; Yes

          CMPI.B    #'(',D0         ; Is this <term> a <regexpr>?
          BEQ.S     GTAD_B          ; Yes

          ANDI.B    #$DF,D0         ; Uppercase the character
          CMPI.B    #'M',D0         ; Is this <term> a <currmemptr>?
          BEQ.S     GTAD_M

          CMPI.B    #'S',D0         ; Is this <term> a <baseptr>?
          BEQ.S     GTAD_S

*--------------------------------------------------------------------
* Here we deal with <hexnum> <term>s in the <expression>.
*--------------------------------------------------------------------
          BSR       READHEX         ; Get a hexadecimal value in D1
          BNE       GTAD_RTS        ; Invalid hex - exit with error
          BRA.S     GTAD_4          ; Totalise and go around again

*--------------------------------------------------------------------
* Here we deal with <decnum> <term>s in the <expression>.
*--------------------------------------------------------------------
GTAD_D    ADDQ.W    #1,A1           ; Skip over the '&'
          BSR       READDEC         ; Get a decimal value in D1
          BRA.S     GTAD_P1         ; Check valid & totalise

*--------------------------------------------------------------------
* Here we deal with <binnum> <term>s in the <expression>.
*--------------------------------------------------------------------
GTAD_P    ADDQ.W    #1,A1           ; Skip over the '%'
          BSR       READBIN         ; Get a binary value in D1

*--------------------------------------------------------------------
* After reading binary, decimal or hexadecimal values, we come here
* to check if what we read was valid. If not valid, bale out with an
* error, otherwise, update the running totals and go around again.
*--------------------------------------------------------------------
GTAD_P1   BNE.S     GTAD_RTS        ; Oops, error detected, exit
          BRA.S     GTAD_4          ; Totailse, and go around loop          

*--------------------------------------------------------------------
* Here we deal with <currmemptr> <term>s in the <expression>.
*--------------------------------------------------------------------
GTAD_M    MOVE.L    MEMPTR(A6),D1   ; Current memory address
          BRA.S     GTAD_5          ; Increment buffer and totalise

*--------------------------------------------------------------------
* Here we deal with <baseptr> <term>s in the <expression>.
*--------------------------------------------------------------------
GTAD_S    MOVE.L    BASE_PNT(A6),D1 ; Job's base address

*--------------------------------------------------------------------
* Skip over the current character, ready for next iteration.
*--------------------------------------------------------------------
GTAD_5    ADDQ.W    #1,A1           ; Next character position

*--------------------------------------------------------------------
* Add the current value to the running  total, then go around again.
*--------------------------------------------------------------------
GTAD_4    BSR.S     ADDVAL          ; Add current value to total
          BRA.S     GTAD_LP         ; Loop around until done

*--------------------------------------------------------------------
* Here we deal with <reg> <term>s in the <expression>. These are:
* '(' followed by a list of registers, comma separated, finally a ')'
* closes the expression.
*--------------------------------------------------------------------
GTAD_B    MOVEQ     #0,D1           ; This <term>'s value so far

*--------------------------------------------------------------------
* The main <regexpr> loop. Every pass by here means we are looking
* at the first character in a <reg> <term>. If not, we are in deep
* doodoo!
*--------------------------------------------------------------------
GTAD_B_L  ADDQ.W    #1,A1           ; Skip the '(' or ','
          MOVEQ     #$DF,D0         ; Prepare to uppercase register
          AND.B     (A1)+,D0        ; Upper case D or A only allowed
          MOVEQ     #$20,D2         ; Offset to A0 in storage
          SUBI.B    #'A',D0         ; Address register?
          BEQ.S     GTAD_6          ; Yes, skip
          MOVEQ     #0,D2           ; Offset to D0 in storage
          SUBQ.B    #3,D0           ; Check all the same
          BNE.S     GTAD_ERR        ; Nope, error exit - invalid

*--------------------------------------------------------------------
* Here we have a Data (D2 = 0) or an Address (D2 = $20) register, we
* should be able to get a digit now.
*--------------------------------------------------------------------
GTAD_6    MOVE.B    (A1)+,D0        ; Hopefully a '0' to '7'
          SUBI.B    #'0',D0 
          BLT.S     GTAD_ERR        ; Less than '0', invalid
          CMPI.B    #7,D0
          BGT.S     GTAD_ERR        ; More than '7', invalid

*--------------------------------------------------------------------
* Our register is a valid one. D2 is our offset into the dataspace of
* the monitor where the register values of the monitored job have
* been stored. We need to calculate an offset of D0*4 and add that to
* D2 to get the correct location.
*--------------------------------------------------------------------
          LSL.B     #2,D0           ; 4 bytes per register
          ADD.B     D0,D2           ; Offset to desired register

*--------------------------------------------------------------------
* We have our register at (A6,D2.W) but did we get a <size> for the
* <reg> <term> in the <regexpr>?
*--------------------------------------------------------------------
          CMPI.B    #'.',(A1)       ; Do we have a dot>
          BNE.S     GTAD_IL         ; Nope, just accumulate the register

*--------------------------------------------------------------------
* We have a <size> in our <reg> <term>, deal with it. We only allow
* Word and Long sized <size>s, so check.
*--------------------------------------------------------------------
          ADDQ.W    #1,A1           ; Skip over the dot
          MOVEQ     #$DF,D0         ; Prepare to uppercase the size
          AND.B     (A1)+,D0        ; Get the size specifier
          CMPI.B    #'L',D0         ; Long?
          BEQ.S     GTAD_IL         ; Yes, accumulate it in D1
          CMPI.B    #'W',D0         ; Word then?
          BNE.S     GTAD_ERR        ; No, exit with error
          MOVE.W    2(A6,D2.W),D0   ; Yes, read the low word from storage
          EXT.L     D0              ; And sign extend it to long
          ADD.L     D0,D1           ; Accumulate the word value
          BRA.S     GTAD_COM        ; Skip and check for <regexpr> end

*--------------------------------------------------------------------
* Read a register value (long) from storage, and accumulate it in the
* current <regexpr>'s running total.
*--------------------------------------------------------------------
GTAD_IL   ADD.L     0(A6,D2.W),D1   ; Add in a register from storage

*--------------------------------------------------------------------
* After each register, do we have a comma? If so, loop around to get
* the next register. We must therefore have a closing ')' so if we
* don't, we error out. If it is a ')' then totalise D1 and loop for
* more <term>s.
*--------------------------------------------------------------------
GTAD_COM  CMPI.B    #',',(A1)       ; Comma?
          BEQ.S     GTAD_B_L        ; Yes, do another register
          CMPI.B    #')',(A1)+      ; No, we must be done
          BNE.S     GTAD_ERR        ; Seems not, bale out with error
          BRA       GTAD_4          ; Totalise D1 and look for more

*--------------------------------------------------------------------
* We get here when we hit a linefeed in the input buffer. It means
* we are done scanning and evaluating the expressions for an address.
*--------------------------------------------------------------------
GTAD_E    TST.B     D3              ; Check the sign
          BNE.S     GTAD_ERR        ; A negative address is invalid

*--------------------------------------------------------------------
* All ok, we have a value for the address, prepare to return the 
* address in D1 which the caller expects.
*--------------------------------------------------------------------
GTAD_OK   MOVE.L    D4,D1           ; Copy the result to D1 for return
          MOVEQ     #0,D0           ; No errors
          BRA.S     GTAD_RTS        ; bale out

*--------------------------------------------------------------------
* It went pear shaped somewhere. Show our indignation and the error
* by returning random garbage in D1 and an error code in D0.
*--------------------------------------------------------------------
GTAD_ERR  MOVEQ     #-17,D0         ; Error in expression

*--------------------------------------------------------------------
* Common code for the return, either with D1 valid or on error.
*--------------------------------------------------------------------
GTAD_RTS  MOVEM.L   (A7)+,D2-D4/A0-A1   ; Restore workers
          TST.L     D0              ; Set Z flag
          RTS                       ; Done

*--------------------------------------------------------------------
* Subroutine to add D1 to the running total in D4, D3.B is the sign
* and is $00 for positive values and $FF for negatives.
*--------------------------------------------------------------------
ADDVAL    TST.B     D3              ; Check sign
          BEQ.S     ADDVAL_1        ; Zero is positive
          NEG.L     D1              ; Must be negative

ADDVAL_1  ADD.L     D1,D4           ; Update total
          RTS                       ; Done

*--------------------------------------------------------------------
* Convert a buffer of characters from hexadecimal to a value in D1.
* If there are invalid characters then return an error in D0.
* Entry here required the buffer start address in A1. This is not in
* standard QDOS string format, the characters are converted until a
* non-hexadecimal character is detected.
* We should exit with A1 pointing at either a linefeed (valid hex) and
* D0 = zero,  or with A1 pointing at a non-hex character (invalid hex
* entered) and D0 = -17 for Error in expression.
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
DSPADDREG MOVE.W    CN_ITOHL,A2
          JSR       (A2)
          ADDQ.W    #6,A0
          MOVE.L    -4(A1),A3
          TST.B     RELMOD(A5)
          BEQ.S     DSPA_SAV
          LEA       IM_A6(A5),A2
          CMPA.L    A2,A1
          BHS.S     DSPA_SAV
          MOVE.L    BASE_PNT(A5),A2
          ADDA.L    A3,A2
          CMPA.L    TOP_PNT(A5),A2
          BHS.S     DSPA_SAV
          ADDA.L    BASE_PNT(A5),A3

*--------------------------------------------------------------------
* This code deals with converting the 8 bytes pointed to by an 
* address register into the 8 pairs of hex digits at the end of each
* line of the register display.
*--------------------------------------------------------------------
* I THINK that the messing around with A1.W rather than A1.L is down
* to saving some time/clock cycles as the high word of A1 is zero
* when we are doing all this work on the registers display window.
*
* Looking in the manual, MOVE.W A1,-(A7) takes 8 clocks plus 1 bus
* read and one bus write, whereas MOVE.L A1,-(A7) takes 14 clocks 
* plus 1 bus read and 2 bus writes. (At least on an MC68008.)
*--------------------------------------------------------------------
DSPA_SAV  MOVE.L    A1,-(A7)
          MOVEQ     #7,D6
          
*--------------------------------------------------------------------
* A loop to convert and buffer 8 bytes pointed to by A0 for the
* end of the register display lines for A0 - A7. (A6,A0.L) points one
* byte before the desired place each time around, so this is flags
* 'E', 'G', 'I', 'K', 'M', 'O', 'Q', 'S' and must be adjusted by one
* byte to point at the desired output location.
*--------------------------------------------------------------------
D_AR_LP   LEA       MATHSTK(A5),A1
          MOVE.B    (A3)+,(A1)
          ADDQ.W    #1,A0
          MOVE.W    CN_ITOHB,A2
          JSR       (A2)
          DBF       D6,D_AR_LP
          MOVE.L    (A7)+,A1
          RTS

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
DSPREG    MOVE.L    A6,A5
          SUBA.L    A6,A6
          LEA       IM_D0(A5),A1
*          MOVE.L    REGDISPL(A5),A0
          LEA       REGBUF(A5),A0
          SUBQ.W    #1,A0
          MOVEQ     #7,D7
          
*--------------------------------------------------------------------
* A loop to convert each of the 8 data and 8 address registers into
* the format shown above. On entry, A0 is pointing to the byte just 
* before the 'D' in 'D0' at the start of the line.
* Each pass through here begins with the appropriate data register.
*--------------------------------------------------------------------
DSPR_LP   ADDQ.W    #4,A0
          MOVE.W    CN_ITOHL,A2
          JSR       (A2)
          ADDQ.W    #5,A0
          ADDA.W    #7*4,A1
          BSR.S     DSPADDREG
          SUBA.W    #8*4,A1
          DBF       D7,DSPR_LP
          
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
          ADDQ.W    #4,A0
          LEA       IM_SSP(A5),A1
          MOVE.W    CN_ITOHL,A2
          JSR       (A2)
          ADDQ.W    #5,A0
          LEA       IM_PC(A5),A1
          BSR.S     DSPADDREG
          ADDA.W    #31,A0
          MOVE.W    CN_ITOHL,A2
          JSR       (A2)                BASE POINTER
          ADDQ.W    #5,A0
          MOVE.W    CN_ITOHL,A2
          JSR       (A2)                TOP POINTER
          ADDQ.W    #4,A0
          MOVE.W    CN_ITOBW,A2
          JSR       (A2)                STATUS REGISTER
          MOVE.L    A5,A6
          MOVE.L    REGWND(A6),A0
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3
          MOVEQ     #1,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3
*          MOVE.L    REGDISPL(A6),A1
          LEA       REGBUF(A6),A1
          MOVE.W    #REGEND-REGMSG,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          
*--------------------------------------------------------------------
* After printing all the register values, we convert the job's ID in
* a buffer at (A0) then print it at 27,10. The format of the job id 
* is a tag in the high word and the entry number in the job table in
* the low word.
*--------------------------------------------------------------------
          LEA       DISBUF(A6),A0
          MOVE.L    #'JB  ',(A0)
          ADDQ.W    #3,A0
          MOVE.L    EXJB_ID(A6),D1
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
          
*--------------------------------------------------------------------
* Work out if we are in relative mode or not. We need to inform the
* user.
*--------------------------------------------------------------------
          LEA       DISBUF(A6),A1
          MOVE.L    #'REL ',(A1)
          MOVE.L    #'OFF ',D1
          TST.B     RELMOD(A6)
          BEQ.S     PR_REL
          MOVE.L    #'ON  ',D1
          
*--------------------------------------------------------------------
* Print out the relative mode details on the final line of the
* REGISTER window.
*--------------------------------------------------------------------
PR_REL    MOVE.L    D1,4(A1)
          MOVEQ     #7,D2
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3
          MOVEQ     #'>',D4
          BRA       DSPREGP

*--------------------------------------------------------------------
* Blank template that is used to display the registers in the main 
* loop and various helper/command routines.
*--------------------------------------------------------------------
REGMSG    DC.B      'D0 00000000  A0 00000000  (A0) 00 00 00 00 00 00 00 00',10
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

*--------------------------------------------------------------------
* ALT Arrow: Change Register Pointer.
*
* Enter here with D5 = ???? -> TODO.
*--------------------------------------------------------------------

*--------------------------------------------------------------------
* ALT DOWN: Should move from Dn or An to Dn+1 or An+1.
*--------------------------------------------------------------------
RP_ADD1   MOVEQ     #4,D5           ; Offset is 4 bytes
          BRA.S     RP_ADJ          ; Move to next D/A register

*--------------------------------------------------------------------
* ALT RIGHT: Should move from Dn to An.
*--------------------------------------------------------------------
RP_ADD8   MOVEQ     #8*4,D5         ; Offset is 32 bytes
          BRA.S     RP_ADJ          ; Move from D to A register

*--------------------------------------------------------------------
* ALT UP: Should move from Dn or An to Dn-1 or An-1.
*--------------------------------------------------------------------
RP_SUB1   MOVEQ     #-4,D5          ; Offset is -4 bytes
          BRA.S     RP_ADJ          ; Move to previous D/A register

*--------------------------------------------------------------------
* ALT LEFT: Should move from An -> Dn.
*--------------------------------------------------------------------
RP_SUB8   MOVEQ     #-8*4,D5        ; Offset is -32 bytes
                                    ; Move from A to D register

*--------------------------------------------------------------------
* Adjust the pointer position on screen to suit the ALT ARROW key 
* just pressed to move the register pointer around the screen. Delete
* it wherever it currently is and redraw it after moving. We do a bit
* of arithmetic to keep D0 inside the register table/storage area.
*--------------------------------------------------------------------
RP_ADJ    MOVEQ     #$20,D4         ; Space as the pointer
          BSR.S     DSPREGP         ; Delete current '>'
          MOVE.W    REGPTR(A6),D0   ; Current register pointer
          MOVEQ     #80,D1          ; D0-D7+A0-A7+PC = 20*4 bytes
          ADD.W     D5,D0           ; Offset to new register
          BGE.S     RP_UPPER        ; A positive offset is good!
          ADD.W     D1,D0           ; Make positive again.  

RP_UPPER  CMP.W     D1,D0           ; Too far?
          BLT.S     RP_STORE        ; No, store new register pointer
          SUB.W     D1,D0           ; Bring back into table

RP_STORE  MOVE.W    D0,REGPTR(A6)   ; Store new current pointer
          MOVEQ     #'>',D4         ; Prepare to highlight it
          BSR.S     DSPREGP         ; Print '>' at new register
          BRA       MAIN_1          ; Done

*--------------------------------------------------------------------
* PRINT REGISTER POINTER
*
* Called to delete the current '>' register pointer and redraw it in
* the new position when the pointer is moved. Where to print it is
* determined by a table of X and Y positions in the window.
* The '>' cursor is printed with a red strip to highlight it. If the
* call is to print a space, the strip is reset to black.
*--------------------------------------------------------------------
DSPREGP   MOVE.L    REGWND(A6),A0   ; REGISTER window ID
          MOVEQ     #-1,D3          ; Timeout
          CMPI.B    #$20,D4         ; Space being printed?
          BEQ.S     DSPRSP          ; Yes, delete current cursor
          MOVEQ     #2,D1           ; Red strip for '>' prompt
          MOVEQ     #SD_SETST,D0    ; 
          TRAP      #3              ; Set strip to red
DSPRSP    MOVE.W    REGPTR(A6),D0   ; Current register pointer
          MOVEM.W   POSTABLE(PC,D0.W),D1-D2 ; X,Y for current register
          MOVEQ     #SD_POS,D0
          TRAP      #3              ; Set position for this register
          MOVE.B    D4,D1           ; Character to print
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print cursor character
          MOVEQ     #0,D1           ; Black
          MOVEQ     #SD_SETST,D0
          TRAP      #3              ; Set black strip
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
* RIGHT is the reverse. Weird!
*--------------------------------------------------------------------
POSTABLE  DC.W      2,0,2,1,2,2,2,3,2,4,2,5,2,6,2,7
          DC.W      12,0,12,1,12,2,12,3,12,4,12,5,12,6,12,7,12,8,26,9,39,9,2,10

*--------------------------------------------------------------------
* MEMORY POINTER WINDOW HANDLER
*
* This code displays the 8 bytes prior to, and 8 bytes after the 
* current memory pointer. Only the lowest 5 bytes of the current
* memory address are printed however.
*
* Two lines are printed:
* The first is the address plus the offsets from $FA through $08 as
* headings, the second line is the 17 data bytes - 8 prior, 8 after 
* and the current byte as well.
*--------------------------------------------------------------------
DSPMEM    MOVE.L    MEMWND(A6),A0   ; MEMORY window ID
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3              ; Clear the MEMORY window
          MOVEQ     #1,D1           ; 8 Pixels wide
          MOVEQ     #0,D2           ; 10 Pixels high
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; Set font size
          LEA       DISBUF(A6),A0   ; Buffer address
          MOVE.L    MEMPTR(A6),A4   ; Current memory address
          SUBQ.W    #8,A4           ; First byte is 8 prior
          MOVE.L    A4,D1           ; Prepare to hexify
          JSR       CN_ADDR         ; Buffer 5 bytes of address
          MOVE.L    MEMWND(A6),A0   ; MEMORY window ID
          MOVEQ     #'>',D1         ; Prompt
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print '>' first on line 1
          LEA       DISBUF(A6),A1   ; Buffer address
          MOVEQ     #5,D2           ; 5 bytes of the address only
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print the lowest 5 bytes
          MOVEQ     #15,D7          ; We need 16 offsets in header
*--------------------------------------------------------------------
* Loop to print the offsets around the current memory pointer as
* headings. The final output looks like:
*
* '>AAAAA FA FB FC FD FE FF 00 01 02 03 04 05 06 07 08 09'
* '    BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB BB'
*
* Where 'AAAAA' = address and 'BB' = hex pairs. 
*
* The first line starts with the lowest 5 characters of the address
* and each pair of hex digits after that on the line, are the low
* byte of the subsequent addresses.
*--------------------------------------------------------------------
DM1_LP    ADDQ.W    #1,A4           ; Next memory address
          MOVEQ     #$20,D1         ; Space
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print a space first
          LEA       DISBUF(A6),A0   ; Output buffer
          MOVE.L    A4,D1           ; Copy Address of current byte
          TST.B     RELMOD(A6)      ; Relative? ($00 = no, $FF = yes)
          BEQ.S     DM_CONV         ; No, skip
          CMP.L     BASE_PNT(A6),D1 ; Are we within the job's address range?
          BLO.S     DM_CONV         ; No, skip
          CMP.L     TOP_PNT(A6),D1  ; Are we above the job's range?
          BHS.S     DM_CONV         ; Yes, skip
          SUB.L     BASE_PNT(A6),D1 ; Yes, adjust for relative mode
*--------------------------------------------------------------------
* If we have reached the current memory address then we change the
* strip to be white with black ink from white ink on a black strip.
* For each offset heading, we simply convert the low byte of D1, the
* address, to a hex pair and print it after a space.
*--------------------------------------------------------------------
DM_CONV   JSR       CN_HEXB         ; Convert D1.B to two hex chars
          MOVE.L    MEMWND(A6),A0   ; MEMORY window ID
          CMPA.L    MEMPTR(A6),A4   ; Current memory address yet?
          BNE.S     DM_PRT          ; No, skip
          MOVEQ     #0,D1           ; Black ink
          MOVEQ     #SD_SETIN,D0
          TRAP      #3              ; Set ink to black
          MOVEQ     #7,D1           ; White strip
          MOVEQ     #SD_SETST,D0
          TRAP      #3              ; Set strip to white

*--------------------------------------------------------------------
* Print the current offset as two hex bytes then reset the ink and 
* strip in case we changed it. 
*--------------------------------------------------------------------
DM_PRT    LEA       DISBUF(A6),A1   ; Hex buffer
          MOVEQ     #2,D2           ; 2 bytes to print
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print this offset
          MOVEQ     #7,D1           ; White ink again
          MOVEQ     #SD_SETIN,D0
          TRAP      #3              ; Reset to white ink
          MOVEQ     #0,D1           ; Black strip
          MOVEQ     #SD_SETST,D0
          TRAP      #3              ; Reset black strip
          DBF       D7,DM1_LP       ; Do the other offset headers

*--------------------------------------------------------------------
* The first line is done. Position at the second line on screen to
* print the actual byte values this time.
*--------------------------------------------------------------------
          MOVEQ     #3,D1           ; Column 3
          MOVEQ     #1,D2           ; Line 1
          MOVEQ     #SD_POS,D0
          TRAP      #3              ; Set position
          MOVE.L    MEMPTR(A6),A4   ; Get current memory address
          SUBQ.W    #8,A4           ; First byte offset
          MOVEQ     #16,D7          ; 17 bytes to print this time

*--------------------------------------------------------------------
* For each of the 17 bytes, print a space then the two hex characters
* making up the value.
*--------------------------------------------------------------------
DM2_LP    MOVEQ     #$20,D1         ; Start with a space (= column 4)
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print a space
          LEA       DISBUF(A6),A0   ; Disassembly buffer
          MOVE.B    (A4)+,D1        ; Get offset byte
          JSR       CN_HEXB         ; Convert to hex
          MOVE.L    MEMWND(A6),A0   ; MEMORY window ID
          LEA       DISBUF(A6),A1   ; Output buffer
          MOVEQ     #2,D2           ; 2 bytes to print
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print two bytes
          DBF       D7,DM2_LP       ; Do remaining offset bytes
          RTS                       ; Done

*--------------------------------------------------------------------
* DISASSEMBLY WINDOW HANDLER
*
* The disassembly buffer consists of 4 main parts:
*   Bytes  0 - 26 = Address and Hex codes of instruction
*   Bytes 27 - 33 = Labels
*   Bytes 34 - 41 = Instruction
*   Bytes 42 - 81 = Operand(s)
*
* 0     0            2      3      4                 8
* 0     6            7      4      2                 1
* 01068 50EE0036 ... L01068 ST     $0036(A6) ...     EOL
*
* At least when disassembling to a file. When output is to the screen
* there are no labels, those spaces are blank. (Space filled.)
*--------------------------------------------------------------------
DSPDIS    MOVE.L    DISWND(A6),A0   ; DISASSEMBLY window ID
          MOVEQ     #-1,D3
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3              ; CLS DISASSEMBLY window
          MOVEQ     #1,D1           ; 8 Pixels wide
          MOVEQ     #0,D2           ; 10 Pixels high
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; Set character sizes
          MOVE.L    MEMPTR(A6),A4   ; Current memory address
          ST        DISMOD(A6)      ; $FF = in disassembly
          JSR       DISASSEM        ; Go do a disassembly
          MOVE.L    A0,D4           ; Free byte in buffer? ???? -> TODO
          MOVE.L    DISWND(A6),A0   ; DISASSEMBLY window ID  
          MOVEQ     #-1,D3          ; Timeout
          LEA       DISBUF(A6),A1   ; Disassembly to be printed
          MOVEQ     #27,D2          ; This many bytes
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print address & hex codes

*--------------------------------------------------------------------
* ???? -> TODO
* Assuming A0 is returned as an address in the buffer, from DISASSEM,
* then we appear to be restricting the instruction text to a maximum
* of 28 bytes, so from byte 34 to byte 62 but the buffer allows up
* to character 81, so why restrict the instruction part I wonder.
*--------------------------------------------------------------------
          LEA       MNFIELD(A6),A1  ; Start of instruction in buffer
          SUB.W     A1,D4           ; Has instruction overflowed?
          CMPI.W    #28,D4          ; Test for 28 bytes maximum
          BLE.S     DSPDIS_2        ; We are ok, go print
          MOVEQ     #28,D4          ; Adjust size of instruction
DSPDIS_2  MOVE.W    D4,D2           ; How many bytes to print
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print disassembly line
          RTS                       ; Done


*--------------------------------------------------------------------
* EXCEPTION MESSAGES
* In the unlikely event of an exception hapening, the following are
* the messages that will be displayed.
*--------------------------------------------------------------------
ADDERRMSG STRING$   {'Address Error',LF}
ILLINSMSG STRING$   {'Illegal Instruction',LF}
DIVZERMSG STRING$   {'Division by zero',LF}
CHKMSG    STRING$   {'CHK Exception',LF}
TRAPVMSG  STRING$   {'TRAPV Exception',LF}
PRIVMSG   STRING$   {'Privilege Violation',LF}
BRKPNTMSG STRING$   {'Breakpoint Executed',LF}
INTL7MSG  STRING$   {'Interrupt Level 7',LF}
NOBRKMSG  STRING$   {'Not a Breakpoint',LF}
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
*
* Having said all that, the following code looks to be attempting to 
* reinitialise (or something like that) the communications between
* the 8049 and the rest of the system. It might work  I'm unable to
* test it as I only have QPC.
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
          BEQ.S     MAINERR1
          LEA       ILLINSMSG,A1

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
          MOVEQ     #-7,D0          ; Signal 'not found'.
          RTS                       ; Done

*--------------------------------------------------------------------
* Reset the TRAP #15 at the breakpoint with the instruction that was
* there previously, when the breakpoint was set. Also, clear this
* breakpoint.
*--------------------------------------------------------------------
RST_OPC   MOVEQ     #0,D0           ; Flag no breakpoint here
          MOVE.L    D0,(A0)+        ; Clears this breakpoint
          MOVE.W    (A0),(A1)       ; Replace the TRAP #15 breakpoint code
          TST.L     D0              ; Set zero flag
          RTS                       ; Done

*--------------------------------------------------------------------
* U: Undo breakpoint at current memory address.
*--------------------------------------------------------------------
UNDO_BRK  BSR.S     REMOVEBRK       ; Look for and remove the breakpoint
          BEQ.S     MAIN_REG
          LEA       NOBRKMSG,A1
          BRA.S     MAIN_ERR        ; And back to the main loop


*--------------------------------------------------------------------
* This is a blank message of zero characters in length. 
*--------------------------------------------------------------------
NULMSG    DC.W      0

*--------------------------------------------------------------------
* MAIN EXECUTION LOOP
* Reset A6 to point at our (the monitor's) data space then set the
* stack appropriately before jumping into supervisor mode.
*--------------------------------------------------------------------
MAIN_REST JSR       SAVREGS         ; return from finished job
          CLR.L     MEMPTR(A6)      ; Set Memory Pointer to zero
          LEA       NULMSG,A1       ; Point to dummy message

*--------------------------------------------------------------------
* We enter here from startup, the exception handlers above, amongst
* other places.
* A1 is either pointing at a message to be printed in the COMMAND 
* window, or is pointing at the NULMSG above so that nothing gets
* printed.
*--------------------------------------------------------------------
MAIN_ERR  MOVEQ     #-1,D1          ; first test MODE
          MOVEQ     #-2,D2
          MOVEQ     #MT_DMODE,D0
          TRAP      #1
          TST.B     D1              ; already MODE 4?
          BEQ.S     CLRCMD          ; yes, skip
          MOVEQ     #0,D1
          MOVEQ     #-1,D2
          MOVEQ     #MT_DMODE,D0
          TRAP      #1              ; else, set MODE 4
CLRCMD    MOVE.L    A1,A2           ; message to be printed
          MOVEQ     #4,D7           ; we have 5 windows
          
* Enter a loop to reset windows if they have been altered by a MODE call
          
          LEA       PROMPTWND(A6),A4 ; first window channel ID
          MOVEQ     #-1,D3          ; timeout
BRD_LOOP  MOVE.L    (A4)+,A0        ; channel ID
          MOVEQ     #2,D1           ; TODO: should be taken from WNDPAR1!
          MOVEQ     #1,D2
          MOVEQ     #SD_BORDR,D0
          TRAP      #3              ; Reset border
          DBF       D7,BRD_LOOP     ; Loop for all 5 windows
          MOVE.L    CMDWND(A6),A0   ; command window ID
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3              ; clear window
          MOVEQ     #1,D1
          MOVEQ     #0,D2
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; reset character size
          MOVE.L    A2,A1           ; now print message
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)
          BSR       DSPROMPT        ; Duplicate code - but avoids LF being
          BSR       DSPREG          ; printed after message
          BSR       DSPMEM
          BSR       DSPDIS
          BRA.S     MAIN_2
*--------------------------------------------------------------------
* Top of the main loop. 
* We start by:
*     Clearing the prompt window.
*     Setting the desired character sizes and
*     Displaying the message about F1, F2 and F3.
*--------------------------------------------------------------------
MAIN_LOOP BSR       DSPROMPT        ; Handle the PROMPT window stuff

*--------------------------------------------------------------------
* Call the subroutine that prints out the register, SR, BP, TP, SSP
* and relativity mode for the monitored job.
*--------------------------------------------------------------------
MAIN_REG  BSR       DSPREG          ; Display register values

*--------------------------------------------------------------------
* Call the code that displays the 8 bytes before and 8 after the
* current memory address.
*--------------------------------------------------------------------
MAIN_MEM  BSR       DSPMEM          ; Display the 16 bytes around
;                                   ; the current memory address

*--------------------------------------------------------------------
* Dissassemble the single instruction at the current memory address.
* Note that this will show TRAP #$0F in the event that we hit a 
* breakpoint as it gets called before we reset the breakpoint. Hmmm.
*--------------------------------------------------------------------
          BSR       DSPDIS          ; Dissassemble one instruction

*--------------------------------------------------------------------
* Here we have the re-entry point after a command has completed, or,
* for example, when prompted for an address we cause an error. This
* part of the code accepts a new command from the COMMAND window.
*--------------------------------------------------------------------
MAIN_1    MOVE.L    CMDWND(A6),A0   ; Command window to be used
          MOVEQ     #-1,D3
          MOVEQ     #LF,D1
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print a newline to the command window

MAIN_2    MOVE.L    CMDWND(A6),A0   ; Command window to be used
          MOVEQ     #-1,D3
          MOVEQ     #1,D1           ; 8 pixels wide
          MOVEQ     #0,D2           ; 10 pixels high
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; Set channel font size
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
* Start searching the command table for the command in D1.B. The table
* entries are a word with the command byte in the lower byte, plus an
* word offset to the actual code routine. The offset is from the 
* address of the offset word itself. Zero ends the table.
*--------------------------------------------------------------------
SEARCHTAB LEA       CMDTAB,A2       ; The command table


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
          BLT.S     JMPCMD          ; Non-letter commands don't echo
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

          DC.W      0               ; End of table

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
ADD_MEM   BSR       GETADDR1        ; Read an address expression

*--------------------------------------------------------------------
* Called from LEFT, RIGHT, UP, DOWN to change the address of the 
* current memory pointer. D1.L is the offset that will be added to
* the current address. The MEMORY WINDOW is redrawn to display the
* new data - 8 bytes below and 8 bytes above the current MP.
*--------------------------------------------------------------------
AMEMPTR   ADD.L     D1,MEMPTR(A6)   ; Adjust the memory pointer
          BRA       MAIN_MEM        ; And go round again

*--------------------------------------------------------------------
* Q: Quit the program.
*
* First make sure that all breakpoints are cleared.
*--------------------------------------------------------------------
QMON      MOVEQ     #BKPTABSIZ-1,D0 ; Prepare to clear breakpoint table
          LEA       BRKPTAB(A6),A0

QMON_BRK  TST.L     (A0)            ; Breakpoint in this slot?
          BEQ.S     BRKNXT          ; No, skip it
          MOVE.L    (A0),A1         ; Yes, grab address
          MOVE.W    4(A0),(A1)      ; Replace TRAP #15 with instruction

BRKNXT    ADDQ.W    #6,A0           ; Point at next slot
          DBF       D0,QMON_BRK     ; Do the whole table

*--------------------------------------------------------------------
* In supervisor mode, check every active job in the job table to see
* if it is using our vector table. If so, clear out its vector table
* then clear out the current vector table too.
*
* Wondering about the EXTAB-$54 operand? Me too - see Pennell page 94
*
* "When a table is set up, the (start address) - $54 is stored in
* both SV.TRAPV and JB.TRAPV".
*
* It's a QDOS thing!
*--------------------------------------------------------------------
          TRAP      #0              ; Supervisor mode
          MOVE.W    $28062,D0       ; SV_JBMAX = Highest job to date
          MOVE.L    $28068,A0       ; SV_JBBAS = Base of job table
          LEA       EXTAB-$54(A6),A2    ; Vector table address

QMON_LP   TST.B     (A0)            ; $FF000000 = Inactive job
          BLT.S     QMON_NXT        ; Skip those
          MOVE.L    (A0),A1         ; Base of job
          CMPA.L    $1C(A1),A2      ; JB_TRAPV = Vector table
          BNE.S     QMON_NXT        ; It's not using our vector table
          CLR.L     $1C(A1)         ; It was, clear it out

QMON_NXT  ADDQ.W    #4,A0           ; Next job table entry
          DBF       D0,QMON_LP      ; Do the whole table
          CLR.L     $28050          ; Clear SV_TRAPV = current vector table
          ANDI      #$DFFF,SR       ; User mode
          MOVEQ     #0,D0           ; No errors


*--------------------------------------------------------------------
* Display a cheerio message to the COMMAND window then exit from the
* monitor returning any error code in D3 as required.
*--------------------------------------------------------------------
QMON_1    MOVE.L    D0,D7           ; Save any error code
          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          LEA       QUITMSG,A1      ; Cheerio!
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print goodbye message

          MOVEQ     #SD_CURS,D0
          TRAP      #3              ; Enable the cursor
          MOVEQ     #-1,D1          ; This job
          MOVE.L    D7,D3           ; Error code
          MOVEQ     #MT_FRJOB,D0    ; Force remove a job
          TRAP      #1              ; Kill myself.

*--------------------------------------------------------------------
* Message to be displayed when we choose to quit from the monitor.
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

GTAD1_RTS RTS                       ; Done

*--------------------------------------------------------------------
* I: Set memory pointer indirect. In other words, prompt for the new
* memory pointer address then read the new memory pointer address
* from that address. In otherwords:
*
* INPUT address
* address = EVEN(address)
* CURRMEMPTR = PEEK_L(address)
*--------------------------------------------------------------------
INDIRECT  BSR.S     GETADDR1        ; Evaluate an address expression
          BCLR      #0,D1           ; Make the address even
          MOVE.L    D1,A1           ; Copy the new address
          MOVE.L    (A1),MEMPTR(A6) ; Set current memory address
          BRA.S     SMEM_1          ; Exit via the main loop

*--------------------------------------------------------------------
* M: Set Memory Pointer. Prompt the user for an address and use that
* as the new current memory pointer.
*--------------------------------------------------------------------
SMEMPTR   BSR.S     GETADDR1        ; Evaluate an address expression
          MOVE.L    D1,MEMPTR(A6)   ; Store it directly, may be odd!

*--------------------------------------------------------------------
* Common exit routine for setting the current memory pointer. Exit
* to the main loop after displaying the 8 bytes before and after the
* new value, and also the single instruction diossassembly for it too.
*--------------------------------------------------------------------
SMEM_1    BSR       DSPMEM          ; 8 bytes either side in hexadecimal
          BSR       DSPDIS          ; Dissassemble one instruction

MAIN_2A   BRA       MAIN_2          ; Go around again

*--------------------------------------------------------------------
* R: Set (current) register to a new value.
* A6 points to the register storage for D0 in our dataspace.
*--------------------------------------------------------------------
SREG      BSR.S     GETADDR1        ; Evaluate an address expression
          MOVE.W    REGPTR(A6),D0   ; Which register to change?
          CMPI.W    #IM_SR,D0       ; Is it the SR?
          BNE.S     SREG_1          ; No, skip

*--------------------------------------------------------------------
* Set the status register to the low word in D1.
*--------------------------------------------------------------------
          MOVE.W    D1,0(A6,D0.W)   ; Update the SR in storage
          BRA.S     SREG_2          ; Done

*--------------------------------------------------------------------
* Update a full width register with the value in D1.
*--------------------------------------------------------------------
SREG_1    MOVE.L    D1,0(A6,D0.W)   ; Update register in storage

SREG_2    BSR       DSPREG          ; Display REGISTER window in full
          BRA.S     MAIN_2A         ; Back into the main loop

*--------------------------------------------------------------------
* This code is called from the C(all) and J(ump) commands to set the
* program counter to the desired address input by the user.
*--------------------------------------------------------------------
SET_PC    JSR       GET_ADDR        ; Get an address from the user
          BNE.S     SETPCRTS        ; Error return
          TST.L     D1              ; Did we get an actual address?
          BNE.S     SETPC_END       ; No, skip
          MOVE.L    MEMPTR(A6),D1   ; Use current memory address

SETPC_END BCLR      #0,D1           ; Make even, just in case
          MOVE.L    D1,IM_PC(A6)    ; Save in PC register storage
          MOVEQ     #0,D0           ; No errors

SETPCRTS  RTS                       ; Done

*--------------------------------------------------------------------
* X: Execute current instruction.
* The instruction at the current memory address is executed which
* will continue until we hit a breakpoint - which we will do because
* we set one at the very next instruction!
*--------------------------------------------------------------------
XECUTE    MOVE.L    MEMPTR(A6),D1   ; Current memory address
          BCLR      #0,D1           ; Make even
          MOVE.L    D1,IM_PC(A6)    ; Save in PC register storage
          MOVE.L    MEMPTR(A6),A4   ; Address to disassemble
          JSR       DISASSEM        ; Disassemble and update A4
          MOVE.L    A4,D1           ; The next instruction address
          BSR.S     BRKP_1          ; Set a breakpoint there
          BRA.S     JUMP_2          ; And execute

*--------------------------------------------------------------------
* J: Jump to address. Control returns when the code has finished or
* it hits a breakpoint. If the code is within an inactive job then it
* will first be activated. The registers are updated with the values
* shown in the REGISTER window prior to the jump.
*--------------------------------------------------------------------
JUMP      BSR.S     SET_PC          ; Get the address to jump to
          BNE       HEXERR          ; Error exit

JUMP_2    JMP       RESTREGS        ; Restore registers & execute

*--------------------------------------------------------------------
* C: Call subroutine which must end with an RTS instruction.
*
* ???? -> TODO:
* Why we set the monitored job's stack up with our current memory
* address I have no idea. 
*
* We also make sure that the address of CALL_RET is uppermost on
* the job's stack so that when it executes an RTS, we return to that
* point. This serves two purposes, it means we come back, and, it 
* doesn't upset the stack for the job that is being monitored by
* popping off it's own return address, or whatever is top of it's A7
* (USP) stack.
*--------------------------------------------------------------------
CALL      BSR.S     SET_PC          ; Get the address to call
          BNE       HEXERR          ; Error exit
          MOVE.L    IM_USP(A6),A1   ; Get the job's USP
          MOVE.L    MEMPTR(A6),-(A1)    ; Stack current memory address
          LEA       CALL_RET,A3     ; We want to return here
          MOVE.L    A3,-(A1)        ; Add it to the job's stack
          MOVE.L    A1,IM_USP(A6)   ; Save the jobs new USP
          JMP       RESTREGS        ; Restore registers & execute

*--------------------------------------------------------------------
* We return here when the called code does an RTS.
*
* ???? -> TODO
* I'm not sure why we copy the 6 bytes from the called job's stack
* (USP) when we come back after a call command. In theory, the long
* word on the stack should be the current memory pointer as we put
* it there before executing the call - but what are the two other 
* bytes?
*--------------------------------------------------------------------
CALL_RET  MOVE      SR,-(A7)        ; Save SR on USP
          TRAP      #0              ; Supervisor mode required
          SUBQ.W    #6,A7           ; Create stack frame on SSP
          MOVE.L    A0,-(A7)        ; Save A0 too
          MOVE      USP,A0          ; Get the job's USP into A0
          MOVE.W    (A0)+,4(A7)     ; ???? -> TODO
          MOVE.L    (A0)+,6(A7)     ; ???? -> TODO
          MOVE      A0,USP          ; Update USP
          MOVE.L    (A7)+,A0        ; Restore A0
          JSR       SAVREGS         ; Copy job's registers to storage
          BRA       MAIN_LOOP       ; Guess!

*--------------------------------------------------------------------
* T: Trace current instruction.
* Execute a single instruction. TRAPs, BSR, JSR, JMP etc all execute
* one instruction at a time.
*--------------------------------------------------------------------
TRACE     MOVE.L    MEMPTR(A6),D1   ; Current memory pointer
          BCLR      #0,D1           ; Even address
          MOVE.L    D1,IM_PC(A6)    ; Set program counter
          BSET      #7,IM_SR(A6)    ; Set Trace bit
          JMP       RESTREGS        ; Restore registers & execute

EXTRACE   BCLR      #7,(A7)         ; Clear trace bit
          JSR       SAVREGS         ; Copy registers to storage
          BRA       MAIN_LOOP       ; Guess!

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
* Enter at BRKPT_SUB to set a break at the current memory address.
*--------------------------------------------------------------------
BRKP_SUB  MOVE.L    MEMPTR(A6),D1   ; Get the current memory address

*--------------------------------------------------------------------
* Enter here with D1 holding the address to set a breakpoint at.
*--------------------------------------------------------------------
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
* F3: Disassemble to screen
*
* Disassemble a single page of output to the screen in the DISASSEMBLY
* window. User is prompted to press ESC at the end of each page of
* output. There is no prompting for data areas here, unlike when the 
* 'D' command is used to disassemble to a file.
* 
* A4 is set up as the current memory address (made even).
*--------------------------------------------------------------------
DIS_PAGE  MOVEQ     #SD_CURS,D0
          TRAP      #3              ; Enable the cursor (COMMAND Window)
          BSR.S     ESC_MSG         ; PROMPT window - press ESC ....
          MOVE.L    AUXWND(A6),A0   ; Use the AUX window for disassembly
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3              ; Clear the AUX Window
          MOVE.L    MEMPTR(A6),D1   ; Current memory address = start here
          BCLR      #0,D1           ; Make even
          MOVE.L    D1,A4           ; A4 = disassembly address
          ST        DISMOD(A6)      ; We are disassembling ($FF)

*--------------------------------------------------------------------
* Head of the disassembly page loop. We allow 19 lines on the screen 
* before we ask the user to press ESC or otherwise.
*--------------------------------------------------------------------
DP_LOOP   MOVE.W    #19,-(A7)       ; 19 lines of output allowed

*--------------------------------------------------------------------
* Disassembly loop. We disassemble a single line and save A0 which is
* the first free byte in the output buffer. We need it later to count
* characters.
* We start by printing the hex address - but only the lowest 5 bytes -
* then the hex codes for the instruction. These take up to 27 bytes.
*--------------------------------------------------------------------
DP_LOOP1  JSR       DISASSEM        ; Disassemble one line of code
          MOVE.L    A0,D4           ; Pointer to end of buffer
          MOVE.L    AUXWND(A6),A0   ; AUX window ID
          MOVEQ     #-1,D3
          LEA       DISBUF(A6),A1   ; Buffer pointer
          MOVEQ     #27,D2          ; Address (5 bytes) and hex codes
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print first part of the line
          LEA       MNFIELD(A6),A1  ; Pointer to instructon disassembly
          SUB.W     A1,D4           ; How many bytes to print?
          CMPI.W    #74-27,D4       ; 47 bytes maximum
          BLE.S     DP_MNEM         ; Size is ok, skip
          MOVEQ     #74-27,D4       ; Limited to 47 bytes

*--------------------------------------------------------------------
* Print the actual decoded instruction now. This is limited to a max
* of 47 characters. This could be longer as the buffer is 82 chars in
* size giving 55 max - as far as I can see.
*--------------------------------------------------------------------
DP_MNEM   MOVE.W    D4,D2           ; How many bytes to print
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print one line
          MOVEQ     #10,D1          ; Linefeed
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print the linefeed
          SUBQ.W    #1,(A7)         ; Decrement line counter
          BNE.S     DP_LOOP1        ; Repeat if more to do
          ADDQ.W    #2,A7           ; Tidy line counter off the stack
          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3              ; Wait for keypress
          CMPI.B    #$1B,D1         ; ESC?
          BNE.S     DP_LOOP         ; No, decode another page

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
* F2: List memory to screen
*--------------------------------------------------------------------
MEMDUMP   MOVEQ     #SD_CURS,D0
          TRAP      #3              ; Enable the cursor
          MOVE.L    PROMPTWND(A6),A0    ; In the PROMPT window
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3              ; Clear the PROMPT window
          MOVEQ     #0,D1           ; 6 Pixels wide
          MOVEQ     #0,D2           ; 10 Pixels high
          MOVEQ     #SD_SETSZ,D0
          TRAP      #3              ; Set character size
          MOVEQ     #43,D1          ; 43 Pixels across
          MOVEQ     #0,D2           ; And zero down
          MOVEQ     #SD_PIXP,D0
          TRAP      #3              ; Set print position
          LEA       MD_MSG1,A1      ; Heading
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print the heading
          MOVE.W    #334,D1         ; 334 Pixels across
          MOVEQ     #0,D2           ; Zero down
          MOVEQ     #SD_PIXP,D0
          TRAP      #3              ; Set print position
          LEA       MD_MSG2,A1      ; ASCII heading
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print ASCII heading
          MOVE.L    AUXWND(A6),A0   ; AUX window ID
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #SD_CLEAR,D0
          TRAP      #3              ; Clear AUX window
          MOVE.L    MEMPTR(A6),A4   ; Start address in A4

*--------------------------------------------------------------------
* Head of the page loop. We set up to allow 19 lines of memory to be
* dumped to the screen. There is no prompt at the end of each page to
* press ESC - it is assumed we know.
*--------------------------------------------------------------------
MD_PAGE   MOVEQ     #18,D7          ; 19 Lines per page

*--------------------------------------------------------------------
* The start address, the current memory pointer, is in A4 but we now
* test and adjust for relative mode.
*--------------------------------------------------------------------
MD_LOOP   MOVE.L    A4,D1           ; Save start address
          TST.B     RELMOD(A6)      ; Relative mode ($FF = Yes)
          BEQ.S     MD2             ; No, skip

*--------------------------------------------------------------------
* If we are in relative mode, check the start address is within the
* monitored job's code boundary.
*--------------------------------------------------------------------
          CMP.L     BASE_PNT(A6),D1 ; Are we above base address?
          BLO.S     MD2             ; No, skip
          CMP.L     TOP_PNT(A6),D1  ; Are we below top address?
          BHS.S     MD2             ; No, skip

*--------------------------------------------------------------------
* Our start address is withing the job's code area. Make sure we set
* it to a multiple of 16 bytes before we dump - the one before the
* starting address.
*--------------------------------------------------------------------
          SUB.L     BASE_PNT(A6),D1 ; Remove base address
          ANDI.B    #$F0,D1         ; Round down to previous 16 byte
          ADD.L     BASE_PNT(A6),D1 ; Absolute address again
          BRA.S     MD3             ; Skip

*--------------------------------------------------------------------
* Make the address an even multiple of 16 bytes, and force it to start
* from the 16 byte boundary just below the desired start address.
* So $12345 (74,565) becomes $12340 (74,560).
*--------------------------------------------------------------------
MD2       ANDI.B    #$F0,D1         ; Round down to nearest 16

*--------------------------------------------------------------------
* At this point we have an address that has been rounded down to the
* nearest 16 byte boundary. This is desired as we only ever dump in
* 16 byte chunks - there are no partial lines here.
*--------------------------------------------------------------------
MD3       MOVE.L    D1,A4           ; Adjusted start address
          BSR.S     DO_MEM          ; Dump one line of 16 bytes
          MOVE.L    AUXWND(A6),A0   ; AUX window ID
          MOVEQ     #-1,D3          ; Timeout
          LEA       DISBUF(A6),A1   ; Where the data are
          MOVEQ     #72,D2          ; How many bytes per line
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print one line
          MOVEQ     #10,D1          ; Linefeed
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print the linefeed
          DBF       D7,MD_LOOP      ; Do the remaining lines

*--------------------------------------------------------------------
* At the end of each page of 19 lines, wait for a key to be pressed
* in the COMMAND window.
*--------------------------------------------------------------------
          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVEQ     #IO_FBYTE,D0
          TRAP      #3              ; Wait for a keypress
          CMPI.B    #$1B,D1         ; ESC?
          BNE.S     MD_PAGE         ; No, do another page
          BRA       DP_END          ; Yes, clear AUX & COMMAND windows

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
* Heading for memory dump to screen. (But not to file!) The digits in
* the following are pixel positioned to appear midway between the two
* hex digits being output on the screen.
*--------------------------------------------------------------------
MD_MSG1   DC.W      MDMSG_END-*-2
          DC.B      '0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F'
MDMSG_END EQU       *

*--------------------------------------------------------------------
* Heading for the ASCII character end of the memory dump output.
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
          BSR.S     HEX_LINE        ; Get the new value
          BEQ       MAIN_LOOP       ; No bytes got, skip to main loop
          MOVE.L    A4,MEMPTR(A6)   ; New memory pointer stored
          BRA.S     AM_LOOP         ; Do more

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
* Prefix the odd number of hex chars with a zero character, if we
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
*
* Up to 40 bytes (80 hex characters) can be searched for, The search
* begins at the current memory address. If you eneter nothing when
* prompted for a string, the previous search string will be used to
* search again from the current memory pointer - which you may have
* changed with the M command.
* If the search string is found, the current memory pointer will be
* updated to match the start of the string in memory.
*
* D1.W = Size of bytes to find, including the linefeed.
* D7.W = Ditto, but minus the linefeed.
* A4.L = Pointer to first character to find.
* A5.L = Pointer to word count for A4.L's string of text.
*--------------------------------------------------------------------
FIND_HEX  MOVEQ     #':',D1         ; Prompt for COMMAND window
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print prompt
          LEA       HEXSTR+2(A6),A4 ; Buffer for characters gotten
          BSR.S     HEX_LINE        ; Get hex bytes
          LEA       HEXSTR(A6),A5   ; Word count location
          MOVE.W    D1,D7           ; How many bytes?
          SUBQ.W    #1,D7           ; No linefeed required
          BLT.S     FH_DEFLT        ; No hex got, use previous search
          MOVE.W    D7,(A5)+        ; Word count stored, minus linefeed
;          BRA.S     FH_MEM         ; ND: removed instruction

*--------------------------------------------------------------------
* First time through, we have to start searching from the current 
* memory pointer, so make sure we decrement A3 before jumping to
* search. 
*--------------------------------------------------------------------
          MOVE.L    MEMPTR(A6),A3   ; Get current address
          SUBQ.W    #1,A3           ; Prepare for FH_LOOP (Extends to long!) 
          BRA.S     FH_LOOP         ; Go look for new search hex string

*--------------------------------------------------------------------
* Pick up the previous search string size if nothing entered.
*--------------------------------------------------------------------
FH_DEFLT  MOVE.W    (A5)+,D7        ; Use existing counter

*--------------------------------------------------------------------
* Enter here with D7 holding the count of bytes to find.
* A5 = A4 = the start of the bytes to find.
* A3 will be the current memory pointer.
* We use A4 and A2 as working copies of A5 and A3 each time we search
* for the desired text and D7 will be a copy of D6 for each search.
*--------------------------------------------------------------------
FH_MEM    MOVE.L    MEMPTR(A6),A3   ; Start address = current memory pointer

FH_LOOP   ADDQ.W    #1,A3           ; Increment start address
          MOVE.W    D7,D6           ; Copy byte count           
          MOVE.L    A5,A4           ; Copy Start of search text
          MOVE.L    A3,A2           ; Copy start of search address

*--------------------------------------------------------------------
* Start the search loop. We scan memory for each byte of the serach
* text and if we find each and every byte, D6 will be -1 on exit. The
* loop will terminate early if any byte doesn't match.
*--------------------------------------------------------------------
FH_CMP    CMPM.B    (A2)+,(A4)+     ; Same byte?
          DBNE      D6,FH_CMP       ; Branch until D6 = -1 or bytes differ
          TST.W     D6              ; -1 = found it
          BGE.S     FH_LOOP         ; No, not found, try again

*--------------------------------------------------------------------
* We must have found the search string. A3 holds the address and we
* will update the current memory pointer with the new address then
* Display the 8 bytes before and after the address we found the text
* at and do a single line disassembly of that address too.
*--------------------------------------------------------------------
FH_END    MOVE.L    A3,MEMPTR(A6)   ; Save new memory pointer
          BSR       DSPMEM          ; Display 8 bytes around new address
          BSR       DSPDIS          ; One line disassembly
          BRA       MAIN_2          ; BAck into main loop

*--------------------------------------------------------------------
* H: Convert binary/decimal/hexadecimal to Hexadecimal.
*--------------------------------------------------------------------
DECTOHEX  BSR       GETADDR1        ; Get a value, dec, bin or hex
          LEA       DISBUF(A6),A0   ; Output buffer start
          MOVE.L    #'  = ',(A0)+   ; Prompt
          JSR       CN_HEXL         ; Convert to hex long 
          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          LEA       DISBUF+1(A6),A1 ; Data start
          MOVEQ     #11,D2          ; How many bytes to print

*--------------------------------------------------------------------
* Enter here with A1 pointing at the buffer start and D2 holding
* the number of bytes to print, and A0 with the channel id.
*--------------------------------------------------------------------
DTOH_2    MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print the details
          BRA       MAIN_1          ; Back into main loop

*--------------------------------------------------------------------
* G: Convert binary/decimal/hexadecimal to Decimal.
*--------------------------------------------------------------------
HEXTODEC  BSR       GETADDR1        ; Get a value, dec, bin or hex
          LEA       DISBUF+14(A6),A1    ; Output buffer end
          MOVEQ     #3,D2           ; 3 characters to print so far
          MOVE.L    D1,D4           ; Positive?
          BGE.S     HD_LOOP         ; Yes, skip
          NEG.L     D1              ; No, make it positive

*--------------------------------------------------------------------
* The value in D1.L is now positive. D4 has the original value.
* We convert D1.L to decimal by dint of repeated division by 10.
* I haven't quite worked out the algorithm here, but it works!
*--------------------------------------------------------------------
HD_LOOP   MOVEQ     #0,D0           ; Current digit accumulator   
          SWAP      D1              ; Start with the high word
          MOVE.W    D1,D0           ; Accumulate it  
          DIVU      #10,D0          ; Guess!
          SWAP      D0              ; Swap remainder into low word
          MOVE.W    D0,D1           ; Move remainder into D1.W
          SWAP      D1              ; And into the high word of D1
          DIVU      #10,D1          ; Divide the low word now
          MOVE.W    D1,D0           ; Quotient into D0.W
          SWAP      D1              ; Remainder in low word
          EXG       D0,D1           ; Swap around.
          ADDI.B    #'0',D0         ; ASCIIfy this digit
          MOVE.B    D0,-(A1)        ; Buffer it
          ADDQ.W    #1,D2           ; One more byte to print
          TST.L     D1              ; Done yet?
          BNE.S     HD_LOOP         ; No, do more

*--------------------------------------------------------------------
* We are done dividing and ASCIIfying. 
*--------------------------------------------------------------------
          TST.L     D4              ; Do we need a minus?
          BGE.S     HD_POS          ; No, skip
          MOVE.B    #'-',-(A1)      ; Yes, buffer one
          ADDQ.W    #1,D2           ; Increment byte counter

*--------------------------------------------------------------------
* Buffer up the three extra characters we pre-loaded D2 with, above.
* I think there must be a space already there when we are done, as we
* only add two characters here, not three.
* The output buffer is now ' = nnnnnn' - at least, that's what prints.
*--------------------------------------------------------------------
HD_POS    MOVEQ     #' ',D0
          MOVE.B    D0,-(A1)        ; Buffer a space 
          MOVE.B    #'=',-(A1)
          MOVE.B    D0,-(A1)        ; Buffer an equals
          BRA.S     DTOH_2          ; Print the output

*--------------------------------------------------------------------
* O: Change relative mode.
*
* If we are in relative mode, change $FF to $00 and if not, change
* $00 to $FF.
*--------------------------------------------------------------------
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
DIS_START MOVE.L    WRKSPTR(A6),LBL_TBL(A6) ; Set start of label table
          SF        DISMOD(A6)      ; Flag 'pass 1 of 2'
          MOVE.L    DISFRST(A6),A4  ; Address to be disassembled

DIS1_LP   MOVE.L    A5,-(A7)        ; Save output channel ID
          JSR       DISASSEM        ; Disassemble address (A4)
          MOVE.L    (A7)+,A5        ; Restore worker
          TST.B     WRKSPOV(A6)     ; Did we overflow workspace?
          BNE.S     WRKSP_ERR       ; Sadly, yes
          CMPA.L    DISLAST(A6),A4  ; No - have we finished?
          BLS.S     DIS1_LP         ; No, do some more
          ADDQ.B    #1,DISMOD(A6)   ; Flag 'pass 2 of 2'
          MOVE.L    DISFRST(A6),A4  ; Get the start address again
          MOVE.L    A5,-(A7)        ; Save the worker again        

DIS2_LP   JSR       DISASSEM        ; Disassemble address (A4)
          MOVE.L    A0,D2           ; End of line in buffer
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
* E: Examine a job.
*
* Here we are prompted to enter a job id or a filename that will be
* loaded as a new job (but not started) which we can monitor.
*--------------------------------------------------------------------
EXAMINE   JSR       RDSTRING        ; Read the jobid, or filename
          ADDQ.W    #2,A1           ; Skip the word count
          JSR       READHEX         ; Try to convert to a value in D1
          BNE.S     EX2             ; Invalid characters - try a file
          CMPI.B    #LF,(A1)        ; Valid input?
          BEQ.S     GET_JB          ; Yes, skip

*--------------------------------------------------------------------
* The jobid was invalid, so we attempt a file open here.
*--------------------------------------------------------------------
EX2       MOVEQ     #1,D4           ; Open mode - old shared (OPEN_IN)
          BSR       OP_AGAIN        ; Try to open it (doesn't return if error)
          LEA       DISBUF(A6),A1   ; Working buffer
          MOVEQ     #$40,D2         ; Size of buffer
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #FS_HEADR,D0
          TRAP      #3              ; Read file header
          TST.L     D0              ; OK?
          BNE.S     EX_ERR          ; No, bale out
*--------------------------------------------------------------------
*** Removed test for EXECable file, useful for examining LRESPRable
*** files. Of course, no attempt should be made to EXEC these...
*
*          MOVEQ     #-15,D0         ; Assume bad parameter error
*          SUBQ.B    #1,DISBUF+5(A6) ; File type, EXECutable = 1
*          BNE.S     EX_ERR          ; Not EXECutable, bale out
*--------------------------------------------------------------------
          MOVE.L    A0,-(A7)        ; Save channel id for file
          MOVE.L    DISBUF(A6),D2   ; File size from header
          MOVEQ     #0,D3           ; Assume dataspace of 0 bytes
          SUBQ.B    #1,DISBUF+5(A6) ; Test for EXECable file
          BNE.S     EX3             ; Skip if not (avoids junk in D3)
          MOVE.L    DISBUF+6(A6),D3 ; Data space from header
EX3       MOVEQ     #-1,D1          ; This job is the owner job
          SUBA.L    A1,A1           ; Start address = start of code        
          MOVEQ     #MT_CJOB,D0
          TRAP      #1              ; Create a new job
          MOVE.L    A0,A1           ; Job's address
          MOVE.L    (A7)+,A0        ; Channel ID
          TST.L     D0              ; Create ok?
          BNE.S     EX_ERR          ; No, bale out
          MOVE.L    D1,D7           ; Save job id
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #FS_LOAD,D0     
          TRAP      #3              ; Load job into job space reserved
          TST.L     D0              ; Load ok?
          BEQ.S     EX_ERR          ; Yes, skip
          MOVEM.L   D0/A0,-(A7)     ; Load error, save D0/A0 (Bugfix!)
          MOVEQ     #0,D3           ; Signal no error to return
          MOVE.L    D7,D1           ; Job id
          MOVEQ     #MT_FRJOB,D0
          TRAP      #1              ; Force kill the job
          MOVEM.L   (A7)+,D0/A0     ; Restore D0/A0

*--------------------------------------------------------------------
* The filename passed is invalid for a job, or cannot be read etc.
*--------------------------------------------------------------------
EX_ERR    MOVE.L    D0,D4           ; Save error code
          MOVEQ     #IO_CLOSE,D0
          TRAP      #2              ; Close job file
          MOVE.L    D4,D0           ; Retrieve error code
          BNE       PRT_ERR         ; Do error message then -> main loop
          MOVE.L    D7,D1           ; Copy the job id

*--------------------------------------------------------------------
* We are here with a jobid in D1. This is either an existing job or
* one we just created from a supplied filename.
*--------------------------------------------------------------------
GET_JB    BSR       FINDJB
          BEQ.S     COPY_REG

*--------------------------------------------------------------------
* We have a bad job id. Display an error and bale out,
*--------------------------------------------------------------------
BAD_JOB   MOVEQ     #-2,D0          ; Invalid Job id error code
          BRA       PRT_ERR         ; Do error message then -> main loop

*--------------------------------------------------------------------
* We only arrive here if the job id we had in D1 was valid.
*--------------------------------------------------------------------
COPY_REG  TRAP      #0              ; Supervisor mode
          BSR.S     EXAM_REGS       ; Copy registers etc to storage
          ANDI      #$DFFF,SR       ; User mode again
          BSR       DSPREG          ; Display registers
          BSR       DSPMEM          ; Display 16 bytes around mem pointer
          BSR       DSPDIS          ; Display one line of disassembly
          BRA       MAIN_2          ; Go around again

*--------------------------------------------------------------------
* Copy the monitored job's registers to our storage for later display
* in the REGISTER window. 
*
* Entry here is either with A0 = SV_JBBAS (base of jobs table) or
* SV_JBPNT Current job's job table entry - depending on the caller,
* however, we ALWAYS enter and exit here in supervisor mode.
*--------------------------------------------------------------------
*** EXAM_REGS MOVE.L    A0,JBPNT(A6)    ; Current job or SuperBASIC
EXAM_REGS BSR       FINDJB          ; Get ptr to job table entry A0
*          MOVE.L    (A0),A0         ; Obsolete - pointer is now in A1
          LEA       $20(A1),A0      ; Storage in job header, for D0
          LEA       IM_D0(A6),A1    ; A6 = Our dataspace = register storage
          MOVEQ     #15,D0          ; 16 Registers to store

*--------------------------------------------------------------------
* Copy the job being monitored's registers from its own job header
* into our register storage area. 
*--------------------------------------------------------------------
COPY_R_LP MOVE.L    (A0)+,(A1)+     ; Copy a job's register to our storage
          DBF       D0,COPY_R_LP    ; Repeat for all 16 registers

*--------------------------------------------------------------------
* Copy the job being monitored's SR and PC from its own job header
* into our register storage area. 
*--------------------------------------------------------------------
          MOVE.W    (A0)+,IM_SR(A6) ; And the job's Status Register
          MOVE.L    (A0),(A1)+      ; And the job's program counter
          MOVE.L    (A0)+,MEMPTR(A6)    ; The job's PC again.
          ADDQ.W    #2,A0           ; Skip unused word in job's header
          MOVE.L    A0,(A1)+        ; Store the job's JB_END in BP

*--------------------------------------------------------------------
* Force the job to use our exception vector table too, otherwise we
* won't be able to trap exceptions, trace progress etc.
* Wondering about the EXTAB-$54 operand? Me too - see Pennell page 94
*
* "When a table is set up, the (start address) - $54 is stored in
* both SV.TRAPV and JB.TRAPV".
*
* It's a QDOS thing!
*--------------------------------------------------------------------
          LEA       -$68(A0),A0     ; Start of job again
          LEA       EXTAB-$54(A6),A2    ; Vector table address
          MOVE.L    A2,$1C(A0)      ; JB_TRAPV - vector table

*--------------------------------------------------------------------
*** TODO: This check fails under SMSQ/E since SV.BASIC no longer
***       points to header of job 0! Also avoid peeking into sysvars,
***       specially using absolute addresses!

          CMPA.L    $28010,A0       ; SV_BASIC = Start of SuperBASIC area
          BEQ.S     ST_TP_1         ; Skip if SuperBASIC is the job
          ADDA.L    (A0),A0         ; JB_LEN = job length in header
          BRA.S     ST_TP

*--------------------------------------------------------------------
* We only come here if looking at SuperBASIC. We get the top end of 
* SuperBASIC's alocated memory etc = SV_TRNSP.
*** TODO: This test is no longer valid for SMSQ/E!
*--------------------------------------------------------------------
ST_TP_1   MOVE.L    $28014,A0       ; SV_TRNSP = Start of jobs in memory

*--------------------------------------------------------------------
* We have, in A0, the top end of the job, or the start of the 
* transient memory are if looking at SuperBASIC. The end of the job
* in other words.
*--------------------------------------------------------------------
ST_TP     MOVE.L    A0,(A1)         ; Save the top end address
          MOVE.L    A7,A0           ; This is the SSP, not USP.
          ADDQ.W    #4,A0           ; Skip our return address
          MOVE.L    A0,IM_SSP(A6)   ; Save the SSP register in storage
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
* F: Fill memory
*
* Propt for first address, last address, size and what to fill into
* the range of addresses.
*--------------------------------------------------------------------
FILL      MOVEQ     #10,D1          ; Newline
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print newline (COMMAND window)
          BSR       FIRSTLAST       ; Get first and last addresses
          OR.L      D4,D1           ; Got start address?
          BEQ       MAIN_1          ; No, loop around again
          MOVE.L    D4,A4           ; Start address
          BSR.S     GET_SIZE        ; Get size to fill
          MOVE.B    D1,D7           ; Save size          
          LEA       WITHMSG,A1      ; 'With' prompt
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print it
          BSR       GETADDR1        ; Get the value
          TST.B     D7              ; What size?
          BEQ.S     FILL_W          ; Zero = word
          BGT.S     FILL_L          ; +1 = long

*--------------------------------------------------------------------
* Fill memory with byte values. A4 is the destination, D1 is the
* value.
*--------------------------------------------------------------------
FILL_B    MOVE.B    D1,(A4)+        ; Fill one byte
          CMPA.L    D5,A4           ; Done yet?
          BLE.S     FILL_B          ; No, do more
          BRA.S     FILL_END        ; Yes, bale out

*--------------------------------------------------------------------
* Fill memory with word values. A4 is the destination, D1 is the
* value.
*--------------------------------------------------------------------
FILL_W    MOVE.W    D1,(A4)+        ; Fill one word
          CMPA.L    D5,A4           ; Done yet?
          BLE.S     FILL_W          ; No, do more
          BRA.S     FILL_END        ; Yes, bale out

*--------------------------------------------------------------------
* Fill memory with long values. A4 is the destination, D1 is the
* value.
*--------------------------------------------------------------------
FILL_L    MOVE.L    D1,(A4)+        ; Fill one long word
          CMPA.L    D5,A4           ; Done yet?
          BLE.S     FILL_L          ; No, do more

*--------------------------------------------------------------------
* Filling is complete. Exit back to the main loop.
*--------------------------------------------------------------------
FILL_END  BRA       MAIN_2

*--------------------------------------------------------------------
* Message to prompt user for a value to fill memory with.
*--------------------------------------------------------------------
WITHMSG   DC.B      0,4,'With'

*--------------------------------------------------------------------
* K: Copy block of memory
*
* User is prompted for First, Last, To addresses.
* D4 = First, D1 = To, D5 = Last.
*--------------------------------------------------------------------
COPY      MOVEQ     #10,D1          ; Linefeed
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print linefeed
          BSR       FIRSTLAST       ; First and last addresses in D4,D5
          LEA       TO_MSG,A1       ' 'To' message
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print it
          BSR       GETADDR1        ; Get the To address
          MOVE.L    D1,A5           ; Destination in A5           
          CMP.L     D4,D1           ; First and To
          BLE.S     COPY_UP         ; First <= To, copy upwards
          CMP.L     D5,D1           ; Last and To
          BLE.S     COPY_DOWN       ; Last <= To, copy downwards

*--------------------------------------------------------------------
* If the From & Last addresses are <= To address we can copy up in 
* memory.
*
* First ....... Last ....... To
*--------------------------------------------------------------------
COPY_UP   MOVE.L    D4,A4           ; From address

COPY_U_LP MOVE.B    (A4)+,(A5)+     ; Copy a byte
          CMPA.L    D5,A4           ; Reached Last address?
          BLE.S     COPY_U_LP       ; No, copy another byte
          BRA.S     COPY_END        ; Yes, done

*--------------------------------------------------------------------
* If there's an overlap in First, Last and To addresses then we copy 
* downwards.
*
* First ....... To ....... Last (etc)
*--------------------------------------------------------------------
COPY_DOWN MOVE.L    D5,A4           ; Last address
          ADDQ.W    #1,A4           ; One past last
          SUB.L     D4,D5           ; How many bytes to copy
          LEA       1(A5,D5.L),A5   ; Set To address top + 1

COPY_D_LP MOVE.B    -(A4),-(A5)     ; Copy a single byte downwards
          CMPA.L    D4,A4           ; Reached the start yet?
          BGT.S     COPY_D_LP       ; No, do another

COPY_END  BRA       MAIN_2          ; All done, back to main loop


*--------------------------------------------------------------------
* Message used to prompt the user for the 'to' address when copying a
* block of memory with the K command (above).
*--------------------------------------------------------------------
TO_MSG    DC.B      0,2,'To'

*--------------------------------------------------------------------
* V - Version command.
*
* Fills the output window with details of all the running jobs in the 
* system.
*
* D7 is used as the line counter for the window depth. It is 3 for
* the first screen and 4 for the remaining screen fulls.
*
* On the last line, the free memory total can be negative for very
* large QL emulations. :-(
*--------------------------------------------------------------------
VERSION   LEA       JOBSMSG,A1      ; Job id, owner etc heading line
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print heading to COMMAND channel
          MOVE.L    $28068,A5       ; SV_JBBAS - start of job table
          SUBQ.W    #4,A5           ; Prepare for code at NXTJOB
          MOVEQ     #2,D7           ; First screen = 3 jobs only
          BRA.S     NXTJOB          ; Skip to do it

*--------------------------------------------------------------------
* The COMMAND window can show 4 lines on each page. The first page had
* three plus the headings - the rest need 4 as there are no headings.
*--------------------------------------------------------------------
JOBLOOP   MOVEQ     #3,D7           ; 4 jobs per page now

*--------------------------------------------------------------------
* This is the D7 loop to display 3 or 4 jobs per page.
* D7 is the line counter.
* A5 is the job table pointer.
* A4 is the job's address in memory.
* A0 is the buffer to be output for each job.
*--------------------------------------------------------------------
NXTJOB    ADDQ.W    #4,A5           ; Point at next job table entry

          CMPA.L    $2806C,A5       ; SV_JBTOP = are we done?
          BGE       ENDJB           ; Yes, exit
          TST.B     (A5)            ; $FF000000 = inactive job
          BLT.S     NXTJOB          ; Job is inactive, ignore it
          MOVE.L    (A5),A4         ; JB_END for this active job

          MOVE.L    A5,D1           ; Job table entry address
          SUB.L     $28068,D1       ; Minus job table start (SV_JBBAS)
          LSR.W     #2,D1           ; 4 bytes per entry so divide
          SWAP      D1              ; Keep job id (table entry number)
          MOVE.W    $10(A4),D1      ; Get job's tag from JB_TAG
          SWAP      D1              ; TAG | ID = 'Job ID'
          LEA       DISBUF(A6),A0   ; Buffer address
          JSR       CN_HEXL         ; Buffer job id in hex
          MOVE.W    #$2020,(A0)+    ; And two spaces
          MOVE.L    8(A4),D1        ; JB_OWNER = job's parent
          JSR       CN_HEXL         ; Buffer it in hex
          MOVE.W    #$2020,(A0)+    ; And two more spaces

*--------------------------------------------------------------------
* ???? -> BUGFIX
*
* Is this a bug? The values of JB_STAT are:
*   -2 = Waiting for another job;
*   -1 = suspended;
*    0 = (possibly) active;
*   >0 = delay time until reactivation. 
*
* So we should possibly test for -2 and flag 'W' for waiting, -1 is
* the only (?) flag for 'S' (Suspended) etc?
*--------------------------------------------------------------------
          TST.W     $14(A4)         ; JB_STAT = 0 = active
          BGE.S     NOT_SUSP        ; Job is active or delayed for rescehdule
          CMPI.W    #-2,$14(A4)     ; Is job waiting for another?
          BEQ.S     JOB_WAIT        ; Yes, skip

          MOVE.B    #'S',-1(A0)     ; Show job as suspended
          BRA.S     NOT_SUSP        ; Skip waiting code

JOB_WAIT  MOVE.B    #'W',-1(A0)     ; Show job is waiting

*--------------------------------------------------------------------
* The job being looked at is not suspended (but see above) and the 
* output buffer looks like 'IIIIIIII  OOOOOOOO  '
*--------------------------------------------------------------------
NOT_SUSP  MOVE.L    CMDWND(A6),A0   ; COMMAND channel id
          MOVEQ     #10,D1          ; Linefeed to print
          MOVEQ     #-1,D3          ; Timeout
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print a linefeed

          LEA       DISBUF(A6),A1   ; Buffer start
          MOVEQ     #20,D2          ; 20 bytes to print
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print job id, owner and suspended flag
          MOVEQ     #0,D1
          MOVE.B    $13(A4),D1      ; JB_PRINC = priority increment
          MOVE.W    UT_MINT,A2
          JSR       (A2)            ; Print JB_PRINC to screen
          MOVEQ     #24,D1          ; Tab 24
          MOVEQ     #SD_TAB,D0
          TRAP      #3              ; Set tab position
          LEA       $68+6(A4),A1    ; Job's code start address
          CMPI.W    #$4AFB,(A1)+    ; Should be $4AFB for a valid job
          BNE.S     NONAME          ; Nope, job has no name
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print job's name from its code

*--------------------------------------------------------------------
* The end of a D7 page of jobs, do some more if we still have spare
* lines in D7.
*--------------------------------------------------------------------
NONAME    DBF       D7,NXTJOB       ; Complete one page of jobs

*--------------------------------------------------------------------
* Page is complete, wait for any key. On receipt, restart a new page
* of job details. 
*--------------------------------------------------------------------
          MOVEQ     #IO_FBYTE,D0    ; Wait for a key press
          TRAP      #3              ; Do it
          BRA       JOBLOOP         ; Start another page of jobs

*--------------------------------------------------------------------
* We get here when we run out of job's in the job table. D7 determines
* if we have space on the current page to output additional QDOS info
* or if we have to wait for a keypress again.
*--------------------------------------------------------------------
ENDJB     MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVEQ     #-1,D3          ; Timeout
          TST.W     D7              ; Got room on this page?
          BGT.S     ENDJ1           ; Yes, skip
          MOVEQ     #IO_FBYTE,D0    ; No room on this page
          TRAP      #3              ; Wait for a keypress again

*--------------------------------------------------------------------
* After the list of jobs has been completed, we need to output the
* QDOS version and the current free memory total. Sadly this has a
* slight bug in systems with masses of free memory as it reports a
* negative value for the free total. Hey! This code is over 30 years
* old - be gentle!
*--------------------------------------------------------------------
ENDJ1     LEA       VER_MSG,A1      ; 'QDOS Version: ' message
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print message
          MOVEQ     #MT_INF,D0
          TRAP      #1              ; Get system information
          MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          LEA       DISBUF(A6),A1   ; Output buffer
          MOVE.L    D2,(A1)         ; QDOS version 'x.xx'
          MOVEQ     #4,D2           ; 4 bytes to print
          MOVEQ     #IO_SSTRG,D0
          TRAP      #3              ; Print QDOS version number
          LEA       FREEMSG,A1      ; 'Free memory: ' message
          MOVE.W    UT_MTEXT,A2
          JSR       (A2)            ; Print message

*--------------------------------------------------------------------
* Get the free memory (in the jobs area) and convert it to KB before
* printing it out. Note that any value of $F000 kb or higher will be
* printed as negative.
*
* ???? -> BUGFIX
* If bit 15 of D1 is set after dividing by 1024, divide again and use
* Megabytes rather than Kilobytes for the total.
*--------------------------------------------------------------------
          MOVEQ     #MT_FREE,D0     ; Prepare to get free space
          TRAP      #1              ; Go get it
          LSR.L     #8,D1           ; Divide by 1024 - part 1
          LSR.L     #2,D1           ; Continued
          MOVEQ     #'K',D7         ; Assume Kilobytes
          CMPI.L    #$7FFF,D1       ; Have we gone into megabytes?
          BLE.S     V_FREE          ; No, skip
          MOVEQ     #'M',D7         ; Yes, flag Megabytes
          LSR.L     #8,D1           ; Divide by 1024 again
          LSR.L     #2,D1

V_FREE    MOVE.L    CMDWND(A6),A0   ; COMMAND window ID
          MOVE.W    UT_MINT,A2      ; Prepare to print a word
          JSR       (A2)            ; Print free memory in KB
          MOVE.B    D7,D1           ; Needs a 'K' or 'M'
          MOVEQ     #IO_SBYTE,D0
          TRAP      #3              ; Print it.
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
          DC.B      '                             QL MULTIMON V3.0',10
          DC.B      '                       ',127,' 1986-2018 BY JAN BREDENBEEK',10,10
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



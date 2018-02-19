* MULTIMON
* QL MONITOR/DISASSEMBLER
* Copyright (C) 1986-1987 by Jan Bredenbeek
* Parts of the source code (C) 2017-2018 by Norman Dunbar and Jan Bredenbeek
* Released under the GPL v3 license in 2017

* This file should be INCLUDEd at the start of MON1.ASM and MON2.ASM

*--------------------------------------------------------------------
* A Macro for generating QDOS strings
*--------------------------------------------------------------------
          
STRING$   MACRO A
[.LAB]    DC.W      .E.[.L]-.S.[.L]
.S.[.L]   DC.B      [A]
.E.[.L]   EQU       *
          ENDM

*--------------------------------------------------------------------
* Definitions
*--------------------------------------------------------------------          
          
version   SETSTR    3.00            Our new version!

DATASPACE EQU       1024            Stack space for the monitor
LF        EQU       $0A             EOL character
BKPTABSIZ EQU       10              Breakpoint table size
NUMVECS   EQU       19              Number of exception vectors

*--------------------------------------------------------------------
* The following are offsets into the dataspace for various storage
* needs. The dataspace start address will, just after execution, be
* held in A6.
*--------------------------------------------------------------------

          OFFSET    0

IM_D0     DS.L      14              Storage for D0-A5
IM_A6     DS.L      1               Storage for A6
IM_USP    DS.L      1               Storage for User SP  
IM_PC     DS.L      1               Storage for Program Counter
BASE_PNT  DS.L      1               Monitored job's base address
TOP_PNT   DS.L      1               Monitored job's top address
IM_SR     DS.W      1               Storage for Status Register
IM_SSP    DS.L      1               Storage for Supervisor SP

*--------------------------------------------------------------------
* There's room in the exception table here for 19 exception vectors.
*--------------------------------------------------------------------
EXTAB     DS.L      NUMVECS         Exception vector table
EXTABEND  EQU       *               End of Exception vector table
OWN_JB    DS.L      1               Pointer to our own entry in job table
EXJB_ID   DS.L      1               ID of job to be Examined

*--------------------------------------------------------------------
* Channel IDs for the various windows that we have open.
*--------------------------------------------------------------------
PROMPTWND DS.L      1               Prompt Windows ID
REGWND    DS.L      1               Register Window ID
MEMWND    DS.L      1               Memory Window ID
CMDWND    DS.L      1               Command Window ID
DISWND    DS.L      1               Disassembly Window ID
AUXWND    DS.L      1               Auxiliary Window ID
MEMPTR    DS.L      1               Current memory pointer address
REGPTR    DS.L      1               Current register pointer

*--------------------------------------------------------------------
* The breakpoint table is defined here as 10 entries - if you change 
* this, adjst what follows as well. Or else!
*--------------------------------------------------------------------
BRKPTAB   DS.B      BKPTABSIZ*6     Breakpoint table - 10 entries of 6 bytes         
DATATBL   DS.L      1               Dataspace allocated for disassembly address etc
LBL_TBL   DS.L      1               Pointer to start of label table
WRKSPTR   DS.L      1               First free space in workarea (DATATBL)
WRK_END   DS.L      1               End of the above buffer - 16
DISFRST   DS.L      1               First address to disassemble
DISLAST   DS.L      1               Last address to disassemble
MATHSTK   DS.L      1               Temp 4 byte maths stack (198 - 194)
RELMOD    DS.B      1               Relative mode flag
DISMOD    DS.B      1               Disassembly mode: <0 single, 0 or 1 multi-pass
OPCODEFLG DS.B      1               Flag - $FF = Suppress Opcodes in disassembly
WRKSPOV   DS.B      1               We overflowed the workspace flag ($FF = Overflow)

*--------------------------------------------------------------------
* Buffer for the register window. It's size must be at least
* REGEND-REGMSG. Unfortunately this calculation cannot be done right
* now so we have to specify it literally here...
*--------------------------------------------------------------------
REGBUF    DS.B      600             Allow for some overhead
          DS.W      0               Next areas must start at word boundary

*--------------------------------------------------------------------
* The disassembly buffer is used for many things!
* Format: (s = space)
* Addr- -------Opcode------- Label- Mnemonic Operand(s)--------------
*  (5) s        (20)        s (6)  s  (7)   s   (40 max)
*--------------------------------------------------------------------
ADDRLEN   EQU       5               should be increased to 8!
OPCODLEN  EQU       20              Hex of opcode+operands (max!)
LABELLEN  EQU       ADDRLEN+1       Hex of address plus 'L'
MNEMLEN   EQU       7               Length of mnemonic+size field
OPRLEN    EQU       40              Length of operands (max)

DISBUF    DS.B      ADDRLEN+1+OPCODLEN+1 ; Address + sp + Opcode + sp
LBL_FLD   DS.B      LABELLEN+1      The labels go here (+ space)
MNFIELD   DS.B      MNEMLEN+1       Start of mnemonic field
OPR_FLD   DS.B      40              Start of operand field
DISBUFLEN EQU       *-DISBUF        Size of disassembly buffer (bytes)

HEXSTR    DS.B      41              Where the HEX codes go in the buffer

                                    QL MULTIMON V3.1
                                    ----------------

Copyright (C) 1986-2024 by JAN BREDENBEEK, the Netherlands


LEGAL STUFF
-----------
To keep it short: As of 2017, MULTIMON is covered by the GNU General Public 
Licence v3. See https://github.com/janbredenbeek/QL-MultiMon/blob/master/LICENSE
for details. This is also the place where you can find updates, give feedback
etcetera.

INTRODUCTION
------------
MULTIMON is a monitor, disassembler and debugger for the Sinclair QL.
This program allows you to inspect the QL's memory and test, disassemble and
debug machine code programs. It is entirely written in machine code and very
compact in size.

As MULTIMON operates on machine code on a low level, it is very easy to crash
the QL when used without care. You should therefore be very careful when
using the commands which change memory or execute (part of) code. As always,
you should SAVE your important programs and data before doing something which
may potentially crash the system.


USING MULTIMON
--------------

MULTIMON can be started in two ways:

1. As a multitasking program by entering EXEC <drive>MULTIMON or EXEC_W
<drive>MULTIMON.

2. As a S(uper)BASIC procedure, by entering:
A=RESPR(1e4): LBYTES <drive>MULTIMON,A: CALL A
(or LRESPR <drive>MULTIMON if you have the TK2 extensions)
In this case, you can start MULTIMON by simply typing 'MON' from the BASIC
command line.

When started, MULTIMON will display (roughly) the following screen:

```
F1 = Help  F2 = Memory Dump  F3 = Disassemble 

D0>01234567  A0 89ABCDEF  (A0) 00 11 22 33 44 55 66 77  
D1 00112233  A1 44556677  (A1) 88 99 AA BB CC DD EE FF  
D2 98765432  A2 12345678  (A2) 01 02 03 04 05 06 07 08  
D3 00000000  A3 0007FFFF  (A3) 43 FA 00 0A 30 78 01 10  
D4 FFFFFFFF  A4 00030000  (A3) 00 00 00 00 00 00 00 00  
D5 55555555  A5 0000016A  (A5) 4A FB 00 01 40 E7 60 00  
D6 00000000  A6 00028000  (A6) D2 54 00 00 00 02 9A 00  
D7 44444444  A7 0003FFFF  (A7) FF FF FF FF FF FF FF FF  
SP 00028480  PC 0003AFC0  (PC) 43 FA 00 0A 30 78 01 10  
     T S  III   XNZVC      BP 0003C000  TP 0003FE00  
SR = 0010000000000000      JB 00000000  REL ON  

>3AFB8 B9 BA BB BC BD BE BF C0 C1 C2 C3 C4 C5 C6 C7 C8  
    48 E7 FF FF 4E BA 01 44 43 FA 00 0A 30 78 01 10 4E  

3AFC0 43FA000A        LEA   $3AFCC,A1

MULTIMON V3
(C) 1986-2021 JAN BREDENBEEK
>
```

WINDOWS
-------
The uppermost window displays a short explanatory message. The big window below
it is the register window; this displays all the 68000 registers and their
contents. In addition, the contents of the first eight locations pointed to by
the eight address registers and the program counter (PC) are displayed.
All values are in hexadecimal except the contents of the status register (SR)
which are displayed in binary. Note that the value displayed for the SP
register applies to the Supervisor stack pointer (SSP), the user stack pointer
is referred to by register A7.

There are also two pseudo-registers BP and TP. These refer to the start and end
address of the job currently being examined by MULTIMON, whose job ID is
displayed next to 'JB'. When MULTIMON starts, this will be zero which is the
job ID of S(uper)BASIC.
Finally, the sign 'REL ON' or 'REL OFF' displays the current mode which may be
relative or absolute. In relative mode, all addresses used in MULTIMON will be
treated as relative to the Base Pointer (BP) if they lie within the address
range pointed to by the Base Pointer (BP) and Top Pointer (TP). This may be
useful when debugging S(uper)BASIC or other position-independent code.

All registers, including BP and TP, may be altered by moving the Register
Pointer (the '>' sign) to the desired register using the arrow keys in
conjunction with the ALT-key, and then using the 'R' command to set the new
value.

The two-line window below the Register window displays the contents of the 17
locations centered around the Memory Pointer. The window below it displays the
68000 assembly instruction at the location of the Memory Pointer.

Finally, the bottom window is used to enter commands. All commands are entered
using a single letter. Some of them expect additional input in the form of an
expression. These may have the following format:

- A hexadecimal number, consisting of digits 0 to 9 and A to F (or a to f). Up
  to eight digits may be entered, corresponding with a 32 bit number;
- The '%' sign followed by a binary number, up to 32 bits;
- The '&' sign followed by a decimal number;
- One or more 68000 register names D0 to D7 or A0 to A7; separated by commas
  and enclosed in brackets. The value obtained will be the sum of the contents
  of all registers. A register name may be followed by .W or .L, in the case of
  .W the value of the lower 16 bits will be sign-extended and before adding it.
- The letter M or m, which corresponds to the current value of the Memory
  Pointer;
- The letter S or s, which corresponds to the current value of the Base Pointer
  (BP).

For the more technically oriented people, here is the exact syntax of an
expression:

```
The symbol | means 'or';  
The symbols [ ] mean 'optional';  
The symbols { } mean 'zero or more times';  

<op>      = + | -  
<size>    = .W | .L  
<regname> = D0 | D1 ... D7 | A0 | A1 ... A7  
<reg>     = <regname>[<size>]  
<term>    = <hexnumber> |  
          %<binnumber> |  
          &<decnumber> |  
          (<reg>{,<reg>}) |  
          M |  
          S  

<expression> = [<op>]<term>{<op><term>}  
```

Some examples:

```
28000             has the value hex 28000
%0100101011111011 has the value hex 4AFB
&131072           has the value dec 131072 (= hex 20000)
(A0)              has the value of the contents of register A0.L
(D0.W,D2.W,D7.L)  has the value of D0.W+D2.W+D7.L
S+20              has the value of the start address of the current job + hex 20
M                 has the value of the memory-pointer
-1                has the value of -1 = hex FFFFFFFF
```
NOTE: Spaces are NOT allowed within an expression!


COMMANDS
--------
F1: Displays Help page. Any key returns to the main display.

F2: Displays a memory dump from the Memory Pointer address onwards. The left
    column displays values in hex, the right column in ASCII. Press ESC to
    return to the main display; any other key continues one page.

F3: Displays a disassembly from the Memory Pointer address onwards. Press ESC
    to leave the disassembly, any other key displays a new page.

CURSOR LEFT (¼): Decrease the Memory Pointer by one.
CURSOR RIGHT (½): Increase the Memory Pointer by one.
CURSOR DOWN (¿): Decrease the Memory Pointer by eight.
CURSOR UP (¾): Increase the Memory Pointer by eight.

ALT+CURSOR LEFT, RIGHT, DOWN, UP: Move the register  pointer.
You can 'walk' through the registers D0 to D7 and A0 to A7, the status register
(SR) and the job pointers BP and TP and subsequently set them using the 'R'
command. It is not possible to set the supervisor stack pointer (SSP) in this
way.

A: Change (alter) the memory from the Memory Pointer onwards.
-------------------------------------------------------------
You may enter up to 80 hex digits (or 40 ASCII bytes) in response. If you want
to enter a plain ASCII string, you must enclose it in single quotes. For hex,
no spaces are allowed between digits, and an odd-length string will be padded
to the left.
Examples: When the memory pointer is at $20000, entering 4AFB0001 will enter 4
          bytes $4A, $FB, $00, $01 at location $20000.
          When the memory pointer is at $30000, entering 4E4 will enter 2
          bytes $04 and $E4 at location $30000.
          A string 'Hello' will enter bytes $48, $65, $6c, $6c and $6f at the
          current memory location.
          Note that the closing quote may be omitted. A quote character in the
          string will be treated as such, provided it's not at the end.
Upon pressing ENTER, the values will be entered and the Memory Pointer updated
accordingly. You may then enter new values. Pressing ENTER on a blank line will
return to the main display.

B: Set a Breakpoint
-------------------
This command sets a Breakpoint at the current memory location. Breakpoints can
only be set in RAM. The instruction at the current location is replaced by an
opcode $4AFB, which will be trapped by the processor as an illegal instruction.
Upon execution, this will enter MULTIMON which recognises it as a Breakpoint,
display the message 'Breakpoint executed' and restore the original instruction.
At most 10 breakpoints may be set simultaneously. You may restore unused
breakpoints with the 'U' command.

C: CALL a subroutine
--------------------
This will Call a subroutine with the register values shown in the Register
window. The subroutine should end with an RTS instruction.

D: Disassemble to a file
------------------------
This disassembles a block of code to a file. Data areas which should not be
disassembled (but marked as 'DC.x' instructions) may optionally be specified.
This command requires the following parameters:

- File name (must be specified in full);
- Workspace size. This will be used to store address information used for
  generating labels during disassembly. By default, 1 Kilobyte is used which
  allows for 256 labels (each label occupies 4 bytes). When disassembling large
  blocks, you should specify a larger workspace (in bytes).
- First and last address of the memory block to be disassembled;
- Suppress opcodes (Yes or No). Answer Yes if you don't want opcodes to
  be generated for each line of code (useful if you want to generate source
  code to be re-assembled later).
- Data areas. For each area, enter the start- and end address and the size
  (byte, word or long). When you have finished, just press ENTER.

When all information has been entered, MULTIMON will start disassembling the
block of code. This is done in two passes; in the first pass it will generate
label information and in the second pass the actual disassembly will be
created. Labels will be generated for addresses referred to by instructions
such as Bxx, JMP, JSR and LEA, but ONLY if they lie within the range of the
disassembly. Labels will have the form Lxxxxx where xxxxx is the absolute or
relative address (depending on absolute or relative mode) in hexadecimal.
Data areas marked as byte-sized will be disassembled as DC.B 'x' (ASCII) when x
has a value between 20 and 7E hex, otherwise the hex value will be generated.
Invalid opcodes will be marked as '*ILLEGAL OPCODE*'. If the opcode contains an
invalid addressing mode, a '?' will be shown as either source or destination.
If you get a message 'Workspace Overflow', there is insufficient workspace
available for the number of labels generated. You have to re-enter the command
with a bigger workspace size.

E: Examine a job
----------------
This command allows you to examine an existing job or load an EXECutable
program.
Any existing job (whether running or not) may be examined by entering its job
ID at this command's prompt. A list of jobs may be obtained by using the 'V'
command. Note that it is sufficient to enter only the lower 16 bits of the job
ID. For example, a job with id 00180003 may be examined by entering just '3' at
the prompt.
Alternatively, you may load an EXECutable program into memory by entering its
(full) filename in response to the prompt. MULTIMON will then create a new job
and load the program's code, but it will NOT start the job automatically (you
may issue the 'J' command followed by 'S' as parameter if you want to start the
job).
In either case, MULTIMON will read the job's registers and set BP and TP
according to the job's start- and end addresses. Note that in case of a running
job, the register values read will probably not reflect the actual value since
QDOS is a multitasking operating system!
You cannot use this command to specify (pipe) channels or parameters to
EXECutable programs. However, the TK2 command 'ET' allows you to load such
programs in the same way as EXEC/EXEC_W, after which you can examine them by
MULTIMON if you note the job number (JOBS command or 'V' in MULTIMON).

F: Fill a block of memory
-------------------------
This command prompts you to enter the first and last location to be filled with
repeats of a byte, word or longword. For word and longword, the start address
has to be even.

G: Display an expression in decimal
-----------------------------------
This command accepts an expression as input and displays the value of it in
32-bit signed decimal.

H: Display an expression in hexadecimal
---------------------------------------
This command accepts an expression as input and displays the value of it in
32-bit hexadecimal.

I: Set memory pointer indirect
------------------------------
This command sets the Memory Pointer at the address pointed to by the 32-bit
pointer at the given address.
For example, entering 28004 (the system variable SV.CHEAP) will cause the
Memory Pointer to be set at the start of the Common Heap.
Any odd addresses will be rounded down to the next even address.

J: Jump to a location using current register values
---------------------------------------------------
This causes the CPU to jump to the given location, after setting the registers
of the current job to the current values. The job will also be activated if not
already active.
This command can be used to start a job loaded with the 'E' command, by
entering 'S' at the 'J:' prompt. Control to MULTIMON returns after the job has
finished or when a Breakpoint is executed.

K: Copy a block of memory
-------------------------
A block of memory can be copied by entering the start and end address of the
source and entering the address of the destination. Odd addresses are allowed,
and if the destination would overlap the original block the copying is done in
such a way that the initial contents of the original block are preserved.

L: List memory
--------------
This creates a memory dump similar to that created by the F2 command. The dump
may be sent to a file.

M: Set Memory Pointer direct
----------------------------
The Memory Pointer is set to the address which is the result of the expression.
Note that the address is always taken to be absolute. If you want to set the
Memory Pointer to an address relative to the start of the current job, add '+S'
to the expression (e.g. 'M:(A1)+S').

N: Adjust Memory Pointer
------------------------
The Memory Pointer is moved by the number of bytes given by the expression.
E.g. 'N:100' moves the Memory Pointer up by 256 bytes.

O: Toggle Relative Mode ('offset') on or off
--------------------------------------------
Normally, MULTIMON displays addresses as absolute values. In certain
circumstances it may be convenient however to display the addresses as 
relative to the start of the current job. This is the case in S*BASIC which
always addresses its data structures relative to A6 (which points to the start
of the memory reserved for a S*BASIC job).
When Relative mode is enabled, visible by the sign 'REL ON' in the register
window, all addresses shown in the register and disassembly window are
displayed as offsets from the Base Pointer address if (and only if) the
absolute address lies between BP and TP (i.e. within the job's memory space).
In disassemblies generated using the F3 key, these addresses will be displayed
with a suffix (BP) to make clear that they are relative. 
When disassembling using the 'D' command, in order to remain compatible with
assembler syntax, the suffix (BP) will NOT be added to relative addresses.
However, since MULTIMON will generate labels for these addresses there
shouldn't be any confusion with absolute addresses within the same range.

In addition, if address register A0 to A5, when added to BP, points to an
address within the job's address range, the contents of the memory locations
(BP+Ax) to (BP+Ax+7) will be displayed in the register window. This may be
useful when examining S*Basic memory, since all addresses are specified
relative to register A6 (which equals BP in case of S*Basic).

EXAMPLE: If BP=$3C000, TP=$3E000 and A1=$1000, then if MULTIMON is in Relative
mode it will show the memory locations $3D000 to $3D007 next to A1. In Absolute
mode, it would show the contents of locations $1000 to $1007.

Q: Quit MULTIMON
----------------
This exits MULTIMON, removing all breakpoints set. When loaded using LRESPR,
you can re-enter MULTIMON using the 'MON' command in S*Basic.

R: Set a register value
-----------------------
This changes the value of the current register, marked by the register pointer.
Using ALT in conjunction with the arrow keys, you can change the register
pointer and cycle around the registers D0-D7, A0-A7, SR and the
pseudo-registers BP and TP. You cannot change the value of the Supervisor Stack
Pointer (SSP).

S: Search hex string
--------------------
You may enter a string of up to 80 hexadecimal digits, or an ASCII string of up
to 40 bytes enclosed in single quotes, to search for.
MULTIMON will start searching at the current Memory Pointer address. If you
enter an empty string, MULTIMON wil re-issue the search using the last string
entered.

T: Trace (single-step) instruction
----------------------------------
This will execute the instruction at the current Memory Pointer address, which
may be in RAM or ROM. TRAP calls will be single-stepped also. If this is
undesired, you should use the 'X' (eXecute) command at the position of the TRAP
instruction.
Note: On QPC2, you cannot trace code within TRAPs because the Trace bit in the
SR will be reset during the TRAP. For this reason, the instruction following 
the TRAP will also be executed before the job is halted again. This is believed
to be a bug in the 68020 emulation code of QPC2 and the author has been
notified of this. I haven't been able to test this on a real 68020 because I
don't have the appropriate hardware available.

U: Remove breakpoint
--------------------
This removes any breakpoint set at the Memory Pointer location. If no
breakpoint was set here, this command does nothing.

V: QDOS Version and system info
-------------------------------
This command will display a list of jobs currently existing in the system. For
each job, the following information is displayed:

- the job's ID (in hex);
- the job's owner ID (in hex);
- the job's priority (prefixed by 'S' if suspended);
- the job's name (if properly formatted by the job).

In addition, it will display the QDOS or SMS version obtained by the MT.INF
trap, and the free memory reported by the system.

X: eXecute an instruction
-------------------------
This command executes code by setting a Breakpoint after the current
instruction and then issuing a 'J'ump command. This differs from the 'T'race
command in that in case of a branch (e.g. JSR, BSR, TRAP) the underlying code
will be integrally executed until it returns.
As this instruction relies on setting Breakpoints, it will only work in RAM.


APPENDIX 1: 68000 Exceptions
----------------------------
When invoked, MULTIMON will install its own exception table in QDOS using the
MT.TRAPV call. This will also be the case with jobs examined by MULTIMON using
the 'E' command. The original exception table will be restored when you switch
to another job using the 'E' command or quit MULTIMON using the 'Q' command.
NOTE: When you start a job using MULTIMON which defines its own exception
table, this will disable the one set by MULTIMON so the commands which rely on
Breakpoints will not work, as will the 'T'race command.
When an exception occurs which is captured by MULTIMON, the job which caused it
will be suspended. If MULTIMON was waiting for the job (after issuing a 'C',
'J', 'T' or 'X' command), it will be entered and display a message indicating
which exception occurred. The registers will be set according to their values
at the time of the exception and the Memory Pointer will be set to the return
address from the exception. In other cases, a message will be printed on
channel #0 or #1 displaying the exception cause, the register values and the
job ID. You may then use the 'E' command to inspect it.

The following exceptions are implemented. As of version 3.01, exceptions marked
'\*' will be redirected only if the original exception vector pointed directly
to an RTE instruction, else the vector will be copied from the original.

- Address Error
- Illegal Instruction (A- and F-line only if supported by system, e.g. Minerva)
- Division by Zero *
- CHK Exception *
- TRAPV Exception *
- Privilege Violation
- Trace Exception *
- Trap #5...Trap #15 *
- Interrupt Level 7. On standard QLs, this may be triggered by pressing the 
  keys CTRL, ALT and 7 simultaneously. This is not guaranteed to work and might
  leave the machine in an unstable state. Use it only as a last resort.


APPENDIX 2: THE 'C', 'J', 'T' AND 'X' COMMANDS
----------------------------------------------
These commands activate the current job. It is not possible to issue them on
the running copy of MULTIMON itself since this will crash MULTIMON (you will
get an 'invalid job' or similar message). You may however load a second copy of
MULTIMON using the 'E' command and issue these commands on the second copy.


APPENDIX 3: VERSION HISTORY
---------------------------
MULTIMON 1.0 was written in 1986 and one of my first projects to master 68K
Assembly programming on the Sinclair QL.

MULTIMON 2.0 allowed expressions as parameters to commands, as opposed to only
hexadecimal numbers as in 1.0. The 'E' command was extended to allow for
loading jobs into memory from a file, much like the S*Basic EXEC command.
Relative mode was introduced, the 'V' command extended to display a list of
jobs and some bugs in the disassembly code fixed.

MULTIMON 2.1 was released in July 1987 and saw relatively minor bug fixes. The
'E' command now doesn't reject file names which started with 'A' to 'F'. The
hex dump now includes a complete header row, and a DC.W or DC.L on an odd
address during disassembly will be rounded up to the next even address. The
exception code which handles Interrupt Level 7 was improved to increase the
chance of a succesful recovery.

List of fixes and enhancements for MULTIMON v3.00b1, released on 18 April 2018:
-------------------------------------------------------------------------------
- Windows are now correctly drawn in the UQLX emulator with release date before
  2018.
- The register and Memory Pointer windows are now compacter and display the
  contents of the address registers in ASCII as well as in hex. For non-ASCII
  character codes, the display depends on the particular character set
  installed (Minerva has the most extensive character set)
- MULTIMON now correctly displays full 32-bit addresses as 8-digit numbers. In
  order to improve readability, smaller addresses are still displayed using
  fewer digits with a minimum of four.
- Removed dependency on fixed system variables address at $28000. So you can
  now use Minerva's second screen without worry.
- You can now use the Examine command to load non-executable files, such as
  resident extensions or even plain text files. This is so that you can examine
  these files, patch them and save them back (for now you will need to note the 
  start and end addresses and use the SBYTES or SEXEC command from SBasic, but
  a Write command is on my todo-list). Of course, no attempt should be made to
  execute code from these files using the Call, Jump etc. commands because it
  will be executed as a Job which will probably crash the machine!

List of fixes and enhancements for MULTIMON v3.00b2 (not released):
-------------------------------------------------------------------
- Improved check for loading as system extension or executable job.
- It is now possible to run multiple copies of MULTIMON even when loaded
  using HOT_RES (with shared code).
- MULTIMON now uses a guardian window - improves start-up display on Q68 in
  hi-res mode.

List of fixes and enhancements for MULTIMON v3.1, released on 19 February 2024
------------------------------------------------------------------------------
- Reworked exception handling code. MULTIMON used to brutally take over
  execution of jobs when an exception occurred, even when it was not waiting
  for the job to finish! Also, using the Examine command on an existing job
  wasn't really safe as the redirected exception table was stored along with 
  MULTIMON's data space which goes away when you exit MULTIMON. The Quit
  command did not restore the original exception vector table but merely
  cleared out the SV.TRAPV and JB.TRAPV pointers, causing potential problems
  on systems and jobs which depend on them.

  From now on, MULTIMON only redirects the following exception vectors:
  - Address Error
  - Illegal Instruction
  - Privilege Violation
  - Trace Exception
  - Interrupt Level 7

  Others are *only* redirected when the original vector directly points to an
  RTE instruction, else the vector is copied from the original.
  If an exception occurs while MULTIMON is not waiting for the job (e.g. not
  after a Call or Jump command), a message is printed on channel 0 or 1 which
  displays the cause of the exception and the value of the 68000's registers,
  the registers' contents are saved in the original job's header and the job
  is subsequently suspended. You may then inspect its state with the Examine
  command, which points you directly at the offending instruction.

  When MULTIMON is first started, a dummy Job named -TOMB- is created which is
  used to hold an exception vector table and a register storage area for jobs
  which have been suspended after an exception. As it says, it is just a dummy
  job containing only a BRA.S instruction pointing to itself, and MULTIMON only
  uses it to set SV.JBPNT/SYS_JBPT to point to it after handling an exception
  and before rescheduling. The reason for this is because the QDOS/SMSQe
  scheduler insists on storing the job's registers in the current job's header
  after a TRAP #1 or frame interrupt, including storage of the job's Program
  Counter which, by the time the scheduler is invoked, points to MULTIMON's
  exception handling code rather than the address which caused the exception
  (which is correctly saved in the original job's header by the MULTIMON
  exception handler).
  You should of course not activate this dummy job, though doing so will only
  slow down the machine. It should not be removed as the exception table may
  still be in use by other jobs. It only takes up less than 200 bytes and no
  CPU cycles.

- Breakpoints now use the 'illegal' opcode $4AFB rather than TRAP #15. On
  execution the Breakpoint table is searched to determine if a breakpoint was
  really set at this address, else the usual 'Illegal instruction' message is 
  thrown. Also, trying to set a breakpoint in ROM will throw an error.

- 'A'lter and 'S'earch command now accept ASCII strings as wel as hex strings.
  You need to enclose these in single quotes, e.g. 'Hello, world'. The closing
  quote may be omitted. In between the opening and closing quote, literal
  quotes are accepted as normal.

- Fixed erratic display of addresses in 'A'lter memory command.

- After a job has finished, a message 'Job has finished' is now displayed
  rather than a cryptic 'Privilege Violation' message.

- Manual updated and converted to .md for better display on web platforms

APPENDIX 4: Compatibility with QL Emulators
-------------------------------------------
MULTIMON v3.x has been tested with the following emulators:

- QPC2 (Windows)
- SMSQmulator (Java)
- Qemulator (Windows)
- QL2K (Windows)
- UQLX (Linux)
- Q68 (an FPGA-based hardware emulator)

APPENDIX 5: BUGS and Things To Do
---------------------------------
Please use the 'Issues' tab on the GitHub page (https://github.com/janbredenbeek/QL-MultiMon/issues)
to report bugs and feature requests.

Jan Bredenbeek, Hilversum, The Netherlands.

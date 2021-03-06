{{      
************************************************
* InLine PAsm in Spin Demo                v1.0 *
* Author: Beau Schwabe                         *
* Copyright (c) 2010 Parallax                  *
* See end of file for terms of use.            *
************************************************


InLine Assembly? - debatable perhaps, however this allows you to call snippets of PAsm and run them
as if they are a defined PUB or PRI subroutine without having to reload a new COG every time.  This
program starts a single COG engine which is similar to 'other' dispatch type of PAsm programs such as
'graphics.spin'.  What makes this different is that the PAsm that would normally be dispatched within
the PAsm dispatcher program now resides in Spin and because of that can be more dynamic (customized)
from within the Spin environment even making some LMM programming possible.


Revision History:

(sometime before)               - I have been using a form very similar to this for testing small bits of code
                                  for awhile.  There has been some recent talk in the forums so I decided to clean
                                  up what I hav and sumbit it.
                                   
09-13-2010                      - initial release

}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

VAR
long InlinePAsm,ARG0{...,ARG1,ARG2,ARG3, etc.}

PUB SpinCode
    cognew(@PAsmEntry,@InlinePAsm)  'Start Inline PAsm engine - You only need to launch this once



''Example 1
    Inline(@PAsm1)              'Call Inline PAsm:
                                 ' - set all LED's on Propeller Demo Board HIGH
                                 ' - program returns to Spin after LEDs have been set in PAsm

''Example 2
'    Inline(@PAsm2)              'Call Inline PAsm ;
                                 ' - how to make jumps .. wiggles P0 at 5MHz
                                 ' - program remains in PAsm loop does not return back to Spin

''Example 3
'    ARG0 := %11001010
'    Inline(@PAsm3)              'Call Inline PAsm ;
                                 ' - how to pass an argument from Spin to PAsm
                                 ' - program returns to Spin after LEDs have been set in PAsm    

''Example 4
'    Inline(@PAsm4)              'Call Inline PAsm ;
                                 ' - how to pass an argument from PAsm to Spin
                                 ' - program returns to Spin after PAsm changes ARG0                                 

'    dira[23..16]~~
'    outa[23..16]:=ARG0

    repeat    
            
DAT
{{

          Enter valid Assembly code here in this section, there are just a few stipulations/requirements
          you need to consider about how variables are used, and how jumping is achieved.  Because
          addresses and variables are local to each COG and how the IDE computes adresses it is necessary,
          when running 'PAsm code snips' to make relative jumps from a known position.

}}
''################################################################################################
''################################################################################################
''################################################################################################
''################################################################################################




''      InLine PAssembly code example 1
''################################################################################################
PAsm1         long      PAsm1_End-PAsm1        '<-first value must contain InLine PAsm program
                                               '  length in longs
              
                        mov     temp0,          #%11111111
                        shl     temp0,          #16
                        mov     dira,           temp0
                        mov     outa,           temp0

PAsm1_End                                      '<- place this at the end of each InLine PAsm
                                               '   for a convenient way to calculate program
                                               '   length  

''      InLine PAssembly code example 2                                  
''################################################################################################
PAsm2         long      PAsm2_End-PAsm2        '<-first value must contain InLine PAsm program
                                               '  length in longs

        {0}             mov     temp0,          #1
        {1}             mov     dira,           temp0

        {2}             xor     outa,           temp0
        {3}             jmp     #InlineProg+2

''                                            Note: In order to jmp to any location within the InLine
''       │                             │              PAsm code, you must do it with reference to where
''       │                             │              your Inline code starts.  This means that YOU must
''       └─────────────────────────────────────────  keep track of the PC location and add it to
''                                     └───────────  'InlineProg' to get an effective jump
                        
PAsm2_End                                      '<- place this at the end of each InLine PAsm
                                               '   for a convenient way to calculate program
                                               '   length  

''      InLine PAssembly code example 3                                  
''################################################################################################
PAsm3         long      PAsm3_End-PAsm3        '<-first value must contain InLine PAsm program
                                               '  length in longs

                        mov     temp0,          #%11111111  'make first 8 bits of temp0 HIGH                         
                        shl     temp0,          #16         'shift temp0 left by 16
                        mov     dira,           temp0       'use temp0 as a mask to set the
                                                            'direction of the LEDs on the Propeller
                                                            'Demo Board

                        mov     temp0,          par         'First par address contains the size
                                                            'of the InLine PAssmebly program...
                                                            
                        add     temp0,          #4          '...we don't want that so we move to
                                                            'the next long to get the address for ARG0
                                                            
                        rdlong  temp1,          temp0       'This reads the contents of ARG0 into temp1,
                                                            'effectively passing ARG0 into PAsm 

                        shl     temp1,          #16         'This block of code alligns the data we                             
                        mov     outa,           temp1       'passed into PAsm to the position of the
                                                            'LEDs on the Propeller Demo Board so we can
                                                            'see the bit pattern 
                        
PAsm3_End                                      '<- place this at the end of each InLine PAsm
                                               '   for a convenient way to calculate program
                                               '   length  

''      InLine PAssembly code example 4                                  
''################################################################################################
PAsm4         long      PAsm4_End-PAsm4        '<-first value must contain InLine PAsm program
                                               '  length in longs

                        mov     temp1,           #%11100111 '<- Some value we want to pass back to Spin

                        mov     temp0,          par         'First par address contains the size
                                                            'of the InLine PAssmebly program...
                                                            
                        add     temp0,          #4          '...we don't want that so we move to
                                                            'the next long to get the address for ARG0
                                                            
                        wrlong  temp1,          temp0       'This reads the contents of ARG0 into temp1,
                                                            'effectively passing ARG0 into PAsm 
                                                            
PAsm4_End                                      '<- place this at the end of each InLine PAsm
                                               '   for a convenient way to calculate program
                                               '   length                                                             



PRI Inline(StartAddress)                       ''Call Inline PAssembly function
    InlinePAsm := StartAddress                 ' run InLine PAsm code          
    repeat until InlinePAsm == 0               ' wait until code is finished

DAT

''             InLine Assembly Engine starts here
''################################################################################################
''################################################################################################
                        org     0
PAsmEntry               
loop                    rdlong  SpinPAsmAddress,        par    wz        'wait for InLine PAsm
        if_z            jmp     #loop

                        movd    PAsmPointer,            #InlineProg      'Restore/Set the self
                                                                         'modifying pointers 'Destination'
                                                                         'field to the beginning address
                                                                         'of 'InlineProg'                         

''             Load InLine Assembly from Spin
'################################################################################################
                        rdlong  ProgramSize,            SpinPAsmAddress  'determine size of InLine
                                                                         'PAsm code in longs +1. Note:
                                                                         'This value is one more than
                                                                         'it should be (remember Zero
                                                                         'counts) in order to append
                                                                         'the 'jmp  #Done' footer code
                                                                         'at the end of the InLine Pasm
                                                                         'code.    

                        add     SpinPAsmAddress,        #4               'Increment pointer to
                                                                         'start of InLine PAsm code
                                                                                  
                        rdlong  PAsmDatafromSpin,       SpinPAsmAddress  'get first long of PAsm code
                                                                         'from Spin

PAsmPointer             mov     0-0 {<-the destination address gets self modified}, PAsmDatafromSpin
'                                                                       'Self Modify 'InlineProg' at
'                                │                                       'an offset determined by the
'                        ┌───────┘                                       '  'Destination' pointer in
'                        │                                               '  'PAsmPointer'
'                        │                                                      
                        add     PAsmPointer,            DestMask         'increment the 'Destination'
                                                                         'pointer in 'PAsmPointer' to
                                                                         'the next PC position.

                        add     SpinPAsmAddress,        #4               'increment the InLine PAsm
                                                                         'code pointer to the next
                                                                         'instruction
                                                                          
                        rdlong  PAsmDatafromSpin,       SpinPAsmAddress  'get next long of PAsm code
                                                                         'from Spin

                        djnz    ProgramSize,            #PasmPointer     'decrement the Program Size
                                                                         'counter and jump if there
                                                                         'is still InLine code to be
                                                                         'coppied

''             This section places a 'jmp  #Done' at the end of the InLine PAsm code
'################################################################################################

                        mov     FooterCode,             PAsmPointer      'make Copy of 'PAsmPointer'
                                                                         'at 'FooterCode' (Self modify
                                                                         'the nop instruction
                                                                                                          
                        mov     PAsmDatafromSpin,       Footer           'replace the previously read
                                                                         'InLine PAsm instruction from
                                                                         'Spin with the instruction
                                                                         'located at 'Footer' which is
                                                                         'the 'jmp #Done'       
FooterCode              nop     '<- This line gets self modified to append 'jmp  #Done' to the end of
                                'the InLine Pasm code

''            Area defining the location of where the InLine Assembly will be                                                                          
'################################################################################################                                                                                  
InlineProg              long      0[50]  {<- the Inline PAsm program area is reserved to 50 longs,
                                             but you can change that to whatever the program allows
                                             or whatever particular need you have}                 

'' Clear Flag and Jump to the beginning of the InLine Assembly Engine where we can wait for more code                                                                         
'################################################################################################                                                                                  
Done
                        mov     flag,           #0
                        wrlong  flag,           par
                        
                        jmp     #PAsmEntry

Footer                  jmp     #Done           '<- This line never gets executed here.  It's placed
                                                'as a reference so that upon compile time the calculated
                                                'value in this location can be used in the self modifying
                                                'code section to add a 'jmp     #Done' at the end of the
                                                'In-Line PAsm code block.                                                                      

''            Variables used for InLine Assembly engine                                                                          
'################################################################################################                                                                                  

SpinPAsmAddress         {<- note missing long ; this notation causes 'SpinPAsmAddress' and 'flag' to
                            be aliased to the same variable in memory }
                            
flag                    long    0                        

ProgramSize             long    0
PAsmDatafromSpin        long    0
PAsmDataAddress         long    0
DestMask                long    %1_000000000






''            If your In-Line Assembly uses any variables you need to place them here!!!!

'         The reason has to do with the way the variable locations are calculated upon run time.
'         you can add as many as the program will allow, and you can use whatever names you wish
'         as long as they don't conflict with the names used above.             
                                                                          
'################################################################################################                                                                                  
temp0                   long    0 '<--- These are to be referenced from within the Spin Inline Asm
temp1                   long    0 '<--- These are to be referenced from within the Spin Inline Asm

DAT

{{
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    TERMS OF USE: MIT License                                    │                                                            
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and│
│associated documentation files (the "Software"), to deal in the Software without restriction,    │
│including without limitation the rights to use, copy, modify, merge, publish, distribute,        │ 
│sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is    │
│furnished to do so, subject to the following conditions:                                         │
│                                                                                                 │
│The above copyright notice and this permission notice shall be included in all copies or         │
│substantial portions of the Software.                                                            │
│                                                                                                 │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT│
│NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND           │
│NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,     │
│DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,   │
│OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.          │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
}}
{{ filter_rc6f_asm.spin
┌─────────────────────────────────────┬────────────────┬─────────────────────┬───────────────┐
│ IIR Recursive Filter (Float) v0.1   │ BR             │ (C)2009             │  6 Dec 2009   │
├─────────────────────────────────────┴────────────────┴─────────────────────┴───────────────┤
│ Infinite Implulse Response (IIR) Recursive filter, implemented in PASM with floatmath.     │
│                                                                                            │
│ Recommended reading if you want to understand how this filter works: www.dspguide.com      │
│ Chapters 19, 20.                                                                           │
│                                                                                            │
│ y(i)= a0*x(i) + a1*x(i-1) + a2*x(i-2) + a3*x(i-3) + a4*x(i-4) + a5*x(i-5) + a6*x(i-6) + .. │
│           ... + b1*y(i-1) + b2*y(i-2) + b3*y(i-3) + b4*y(i-4) + b5*y(i-5) + b6*y(i-6)      │
│ ai, bi = filter coefficients                                                               │
│ x(i) = filter input at timestep i                                                          │
│ y(i) = filter output at timestip i                                                         │
│                                                                                            │
│ USAGE: starts a cog which continuously polls a memory location looking for a data value    │
│        (negx, $8000_000 is assumed to be "no data", filter cog will ignore).  When a data  │
│        value is detected, cog processes data sample and places the filtered output into    │
│        the next location in hub memory.  Thus, filter in and out MUST be adjacent longs in │
│        hub memory.  This was done to facilitate chaining several filters together, and     │
│        also for simplicity.                                                                │
│                                                                                            │
│ NOTES:                                                                                     │
│ •The design objective for this filter was to make a reasonably high performance IIR        │
│  filter with the greatest possible bandwidth in a single cog.                              │
│ •Typical filter bandwith (using ALL filter coefficients) is 4.8K samples/sec @ 80 MHz.     │
│ •Note that filter throughput will vary considerably depending on the particular filter     │
│  implemented This is because the filter will skip the multiply/accumulate step for any     │
│  filter coefficient that is zero, so the number of coefficients used impacts throughput.   │
│ •This demo provides a timer to enable easy measurement of typical filter throughput to     │
│  give the user an idea of what performance might be attainable from a particular set of    │
│  filter coefficients.                                                                      │
│ •This filter provides no overflow detection, it is up to the user to be sure that the      │
│  data input values and the filter coefficient normalization are reasonable.                │
│                                                                                            │
│ See end of file for terms of use.                                                          │
└────────────────────────────────────────────────────────────────────────────────────────────┘
}}
'FIXME: output is delayed by 1 sample for some reason...

CON    
  SignFlag      = $1
  ZeroFlag      = $2
  NaNFlag       = $8
  #0,int,fp


VAR
  byte cog


PUB start( _inPtr, int_or_fp )
''starts 4-element recursive IIR filter in a cog.
''Usage: filter.start(input_ptr)
''Args:  _inPtr = pointer to hub memory location containing input data (output in next long)
''       int_or_fp =  0->filter input/output data is in integer format; 1->floating point format

  stop
  t2 := int_or_fp
  cog := cognew( @entry, _inPtr ) + 1
  return cog


PUB stop
  if cog
    cogstop( cog~ - 1 )  


pub set_kernel(kern_ptr)
''Moves filter kernel coefficients into the filter object dat space.
''Input arg is pointer to filter coefficients.  This object expects
''filter coeffs to be packed in a block of longs as such:
'' a0,a1..a6,b1,b2..b6

  longmove(@a,kern_ptr,16)


DAT
'--------------------------
'Single precision floating point recursive IIR filter
'--------------------------
                        org
entry                   mov     reserves,#0             'Chip's method for initializing reserves
                        add     entry,d0
                        djnz    t1,#entry

                        cmp     t2,#0   wz              'select integer/floating point IO
                  if_nz mov     in_fmt,#0
                  if_nz mov     out_fmt,#0

                        mov     inPtr,par               'get pointer for filter data input location
                        mov     outPtr,par              'set pointer for filter data output location
                        add     outPtr,#4               '(output assumed to be next long in hub memory) 

                        cmp     a2,#0   wz              'convert any multiplication call having
                   if_z mov     a2x2,skip_a2x2          'a zero coefficient into a nop
                        cmp     a3,#0   wz
                   if_z mov     a3x3,skip_a3x3
                        cmp     a4,#0   wz
                   if_z mov     a4x4,skip_a4x4
                        cmp     a5,#0   wz              'FIXME: inelegant
                   if_z mov     a5x5,skip_a5x5
                        cmp     a6,#0   wz
                   if_z mov     a6x6,skip_a6x6
                        cmp     b1,#0   wz
                   if_z mov     b1y1,skip_b1y1
                        cmp     b2,#0   wz
                   if_z mov     b2y2,skip_b2y2
                        cmp     b3,#0   wz
                   if_z mov     b3y3,skip_b3y3
                        cmp     b4,#0   wz
                   if_z mov     b4y4,skip_b4y4
                        cmp     b5,#0   wz
                   if_z mov     b5y5,skip_b5y5
                        cmp     b6,#0   wz
                   if_z mov     b6y6,skip_b6y6        
'--------------------------                                                                        
'main loop
'on entry: raw data is in hub memory location par
'on exit: filtered data is in par+4
'--------------------------      
top                     mov     fnumA,x1
                        mov     fnumB,a1
a1x1                    call    #_FMul                  'a1*x1
                        mov     acum,fnumA              'reinitialize accumulator
                        
a2x2                    mov     fnumA,x2                'multiply and accumulate
                        mov     fnumB,a2
                        call    #_FMul                  'a2*x2
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
a3x3                    mov     fnumA,x3                
                        mov     fnumB,a3
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
a4x4                    mov     fnumA,x4                
                        mov     fnumB,a4
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
a5x5                    mov     fnumA,x5                
                        mov     fnumB,a5
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
a6x6                    mov     fnumA,x6                
                        mov     fnumB,a6
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
b1y1                    mov     fnumA,y1                
                        mov     fnumB,b1
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
b2y2                    mov     fnumA,y2                
                        mov     fnumB,b2
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
b3y3                    mov     fnumA,y3                
                        mov     fnumB,b3
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
b4y4                    mov     fnumA,y4                
                        mov     fnumB,b4
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
b5y5                    mov     fnumA,y5                
                        mov     fnumB,b5
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
b6y6                    mov     fnumA,y6                
                        mov     fnumB,b6
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     acum,fnumA
                        
buf_update              mov     y6,y5                   'update x-buffer, y-buffer
                        mov     y5,y4                   
                        mov     y4,y3                   'FIXME: inelegant
                        mov     y3,y2                   
                        mov     y2,y1
                        mov     x6,x5
                        mov     x5,x4
                        mov     x4,x3
                        mov     x3,x2
                        mov     x2,x1
                        mov     x1,x0
                        wrlong  nul,inPtr               'zero input register (ready for next data) 
           
loop                    rdlong  fnumA,inPtr             'get new filter data input        
                        cmps    fnumA,nul    wz         'check for nul input
                   if_z jmp     #loop                   'if nul, disregard...loop back
in_fmt                  call    #_FFloat                'convert to floating point format
                        mov     x0,fnumA

a0x0                    mov     fnumB,a0
                        call    #_FMul                  
                        mov     fnumB,acum
                        call    #_FAdd
                        mov     y1,fnumA
                        
out_fmt                 call    #_FRound                'convert result back into integer
                        wrlong  fnumA,outPtr            'write filtered data to hub memory        
'                       wrlong  nul,inPtr               'zero input register (ready for next data)
                        jmp     #top                    'play it again, Sam                   

'------------------------------------------------------------------------------
'Subroutine taken from Float32 object
' _FAdd    fnumA = fnumA + fNumB
' _FAddI   fnumA = fnumA + {Float immediate}
' _FSub    fnumA = fnumA - fNumB
' _FSubI   fnumA = fnumA - {Float immediate}
' changes: fnumA, flagA, expA, manA, fnumB, flagB, expB, manB, t1
'------------------------------------------------------------------------------

_FSubI                  movs    :getB, _FSubI_ret       ' get immediate value
                        add     _FSubI_ret, #1
:getB                   mov     fnumB, 0

_FSub                   xor     fnumB, Bit31            ' negate B
                        jmp     #_FAdd                  ' add values                                               

_FAddI                  movs    :getB, _FAddI_ret       ' get immediate value
                        add     _FAddI_ret, #1
:getB                   mov     fnumB, 0

_FAdd                   call    #_Unpack2               ' unpack two variables                    
          if_c_or_z     jmp     #_FAdd_ret              ' check for NaN or B = 0

                        test    flagA, #SignFlag wz     ' negate A mantissa if negative
          if_nz         neg     manA, manA
                        test    flagB, #SignFlag wz     ' negate B mantissa if negative
          if_nz         neg     manB, manB

                        mov     t1, expA                ' align mantissas
                        sub     t1, expB
                        abs     t1, t1
                        max     t1, #31
                        cmps    expA, expB wz,wc
          if_nz_and_nc  sar     manB, t1
          if_nz_and_c   sar     manA, t1
          if_nz_and_c   mov     expA, expB        

                        add     manA, manB              ' add the two mantissas
                        cmps    manA, #0 wc, nr         ' set sign of result
          if_c          or      flagA, #SignFlag
          if_nc         andn    flagA, #SignFlag
                        abs     manA, manA              ' pack result and exit
                        call    #_Pack  
_FSubI_ret
_FSub_ret 
_FAddI_ret
_FAdd_ret               ret      

'------------------------------------------------------------------------------
'Subroutine taken from Float32 object
' _FMul    fnumA = fnumA * fNumB
' _FMulI   fnumA = fnumA * {Float immediate}
' changes: fnumA, flagA, expA, manA, fnumB, flagB, expB, manB, t1, t2
'------------------------------------------------------------------------------

_FMulI                  movs    :getB, _FMulI_ret       ' get immediate value
                        add     _FMulI_ret, #1
:getB                   mov     fnumB, 0

_FMul                   call    #_Unpack2               ' unpack two variables
          if_c          jmp     #_FMul_ret              ' check for NaN

                        xor     flagA, flagB            ' get sign of result
                        add     expA, expB              ' add exponents
                        mov     t1, #0                  ' t2 = upper 32 bits of manB
                        mov     t2, #32                 ' loop counter for multiply
                        shr     manB, #1 wc             ' get initial multiplier bit 
                                    
:multiply if_c          add     t1, manA wc             ' 32x32 bit multiply
                        rcr     t1, #1 wc
                        rcr     manB, #1 wc
                        djnz    t2, #:multiply

                        shl     t1, #3                  ' justify result and exit
                        mov     manA, t1                        
                        call    #_Pack 
_FMulI_ret
_FMul_ret               ret

'------------------------------------------------------------------------------
'Subroutine taken from Float32 object
' _FDiv    fnumA = fnumA / fNumB
' _FDivI   fnumA = fnumA / {Float immediate}
' changes: fnumA, flagA, expA, manA, fnumB, flagB, expB, manB, t1, t2
'------------------------------------------------------------------------------

_FDivI                  movs    :getB, _FDivI_ret       ' get immediate value
                        add     _FDivI_ret, #1
:getB                   mov     fnumB, 0

_FDiv                   call    #_Unpack2               ' unpack two variables
          if_c_or_z     mov     fnumA, NaN              ' check for NaN or divide by 0
          if_c_or_z     jmp     #_FDiv_ret
        
                        xor     flagA, flagB            ' get sign of result
                        sub     expA, expB              ' subtract exponents
                        mov     t1, #0                  ' clear quotient
                        mov     t2, #30                 ' loop counter for divide

:divide                 shl     t1, #1                  ' divide the mantissas
                        cmps    manA, manB wz,wc
          if_z_or_nc    sub     manA, manB
          if_z_or_nc    add     t1, #1
                        shl     manA, #1
                        djnz    t2, #:divide

                        mov     manA, t1                ' get result and exit
                        call    #_Pack                        
_FDivI_ret
_FDiv_ret               ret

'------------------------------------------------------------------------------
'Subroutine taken from Float32 object
' _FFloat  fnumA = float(fnumA)
' changes: fnumA, flagA, expA, manA
'------------------------------------------------------------------------------
         
_FFloat                 mov     flagA, fnumA            ' get integer value
                        mov     fnumA, #0               ' set initial result to zero
                        abs     manA, flagA wz          ' get absolute value of integer
          if_z          jmp     #_FFloat_ret            ' if zero, exit
                        shr     flagA, #31              ' set sign flag
                        mov     expA, #31               ' set initial value for exponent
:normalize              shl     manA, #1 wc             ' normalize the mantissa 
          if_nc         sub     expA, #1                ' adjust exponent
          if_nc         jmp     #:normalize
                        rcr     manA, #1                ' justify mantissa
                        shr     manA, #2
                        call    #_Pack                  ' pack and exit
_FFloat_ret             ret

'------------------------------------------------------------------------------
'Subroutine taken from Float32 object
' _FTrunc  fnumA = fix(fnumA)
' _FRound  fnumA = fix(round(fnumA))
' changes: fnumA, flagA, expA, manA, t1 
'------------------------------------------------------------------------------

_FTrunc                 mov     t1, #0                  ' set for no rounding
                        jmp     #fix

_FRound                 mov     t1, #1                  ' set for rounding

fix                     call    #_Unpack                ' unpack floating point value
          if_c          jmp     #_FRound_ret            ' check for NaN
                        shl     manA, #2                ' left justify mantissa 
                        mov     fnumA, #0               ' initialize result to zero
                        neg     expA, expA              ' adjust for exponent value
                        add     expA, #30 wz
                        cmps    expA, #32 wc
          if_nc_or_z    jmp     #_FRound_ret
                        shr     manA, expA
                                                       
                        add     manA, t1                ' round up 1/2 lsb   
                        shr     manA, #1
                        
                        test    flagA, #signFlag wz     ' check sign and exit
                        sumnz   fnumA, manA
_FTrunc_ret
_FRound_ret             ret
                                  
'------------------------------------------------------------------------------
'Subroutine taken from Float32 object
' input:   fnumA        32-bit floating point value
'          fnumB        32-bit floating point value 
' output:  flagA        fnumA flag bits (Nan, Infinity, Zero, Sign)
'          expA         fnumA exponent (no bias)
'          manA         fnumA mantissa (aligned to bit 29)
'          flagB        fnumB flag bits (Nan, Infinity, Zero, Sign)
'          expB         fnumB exponent (no bias)
'          manB         fnumB mantissa (aligned to bit 29)
'          C flag       set if fnumA or fnumB is NaN
'          Z flag       set if fnumB is zero
' changes: fnumA, flagA, expA, manA, fnumB, flagB, expB, manB, t1
'------------------------------------------------------------------------------

_Unpack2                mov     t1, fnumA               ' save A
                        mov     fnumA, fnumB            ' unpack B to A
                        call    #_Unpack
          if_c          jmp     #_Unpack2_ret           ' check for NaN

                        mov     fnumB, fnumA            ' save B variables
                        mov     flagB, flagA
                        mov     expB, expA
                        mov     manB, manA

                        mov     fnumA, t1               ' unpack A
                        call    #_Unpack
                        cmp     manB, #0 wz             ' set Z flag                      
_Unpack2_ret            ret

'------------------------------------------------------------------------------
'Subroutine taken from Float32 object
' input:   fnumA        32-bit floating point value 
' output:  flagA        fnumA flag bits (Nan, Infinity, Zero, Sign)
'          expA         fnumA exponent (no bias)
'          manA         fnumA mantissa (aligned to bit 29)
'          C flag       set if fnumA is NaN
'          Z flag       set if fnumA is zero
' changes: fnumA, flagA, expA, manA
'------------------------------------------------------------------------------

_Unpack                 mov     flagA, fnumA            ' get sign
                        shr     flagA, #31
                        mov     manA, fnumA             ' get mantissa
                        and     manA, Mask23
                        mov     expA, fnumA             ' get exponent
                        shl     expA, #1
                        shr     expA, #24 wz
          if_z          jmp     #:zeroSubnormal         ' check for zero or subnormal
                        cmp     expA, #255 wz           ' check if finite
          if_nz         jmp     #:finite
                        mov     fnumA, NaN              ' no, then return NaN
                        mov     flagA, #NaNFlag
                        jmp     #:exit2        

:zeroSubnormal          or      manA, expA wz,nr        ' check for zero
          if_nz         jmp     #:subnorm
                        or      flagA, #ZeroFlag        ' yes, then set zero flag
                        neg     expA, #150              ' set exponent and exit
                        jmp     #:exit2
                                 
:subnorm                shl     manA, #7                ' fix justification for subnormals  
:subnorm2               test    manA, Bit29 wz
          if_nz         jmp     #:exit1
                        shl     manA, #1
                        sub     expA, #1
                        jmp     #:subnorm2

:finite                 shl     manA, #6                ' justify mantissa to bit 29
                        or      manA, Bit29             ' add leading one bit
                        
:exit1                  sub     expA, #127              ' remove bias from exponent
:exit2                  test    flagA, #NaNFlag wc      ' set C flag
                        cmp     manA, #0 wz             ' set Z flag
_Unpack_ret             ret       

'------------------------------------------------------------------------------
'Subroutine taken from Float32 object
' input:   flagA        fnumA flag bits (Nan, Infinity, Zero, Sign)
'          expA         fnumA exponent (no bias)
'          manA         fnumA mantissa (aligned to bit 29)
' output:  fnumA        32-bit floating point value
' changes: fnumA, flagA, expA, manA 
'------------------------------------------------------------------------------

_Pack                   cmp     manA, #0 wz             ' check for zero                                        
          if_z          mov     expA, #0
          if_z          jmp     #:exit1

:normalize              shl     manA, #1 wc             ' normalize the mantissa 
          if_nc         sub     expA, #1                ' adjust exponent
          if_nc         jmp     #:normalize
                      
                        add     expA, #2                ' adjust exponent
                        add     manA, #$100 wc          ' round up by 1/2 lsb
          if_c          add     expA, #1

                        add     expA, #127              ' add bias to exponent
                        mins    expA, Minus23
                        maxs    expA, #255
 
                        cmps    expA, #1 wc             ' check for subnormals
          if_nc         jmp     #:exit1

:subnormal              or      manA, #1                ' adjust mantissa
                        ror     manA, #1

                        neg     expA, expA
                        shr     manA, expA
                        mov     expA, #0                ' biased exponent = 0

:exit1                  mov     fnumA, manA             ' bits 22:0 mantissa
                        shr     fnumA, #9
                        movi    fnumA, expA             ' bits 23:30 exponent
                        shl     flagA, #31
                        or      fnumA, flagA            ' bit 31 sign            
_Pack_ret               ret

'-------------------- constant values -----------------------------------------
'Zero                   long    0                       ' constants
'One                    long    $3F80_0000
NaN                     long    $7FFF_FFFF
Minus23                 long    -23
Mask23                  long    $007F_FFFF
'Mask29                 long    $1FFF_FFFF
'Bit16                  long    $0001_0000
Bit29                   long    $2000_0000
'Bit30                  long    $4000_0000
Bit31                   long    $8000_0000
'--------------------------                                                                            
'initialized data
'--------------------------                                                                           
a                                                       'filter x-coefficients a[0], a[1],...         
a0                      long    0             
a1                      long    0
a2                      long    0
a3                      long    0
a4                      long    0
a5                      long    0
a6                      long    0
b                                                       'filter y-coefficients b[1], b[2],...        
b1                      long    0             
b2                      long    0
b3                      long    0
b4                      long    0
b5                      long    0
b6                      long    0
x_buf
x0                      long    0                       'filter input history buffer
x1                      long    0
x2                      long    0
x3                      long    0
x4                      long    0
x5                      long    0
x6                      long    0
y_buf                                                   'filter output history buffer
y1                      long    0                                 
y2                      long    0
y3                      long    0
y4                      long    0
y5                      long    0
y6                      long    0
skip_a2x2               jmp     #a3x3                   'used to null out unused filter coefficient MACs
skip_a3x3               jmp     #a4x4
skip_a4x4               jmp     #a5x5
skip_a5x5               jmp     #a6x6
skip_a6x6               jmp     #b1y1
skip_b1y1               jmp     #b2y2
skip_b2y2               jmp     #b3y3
skip_b3y3               jmp     #b4y4
skip_b4y4               jmp     #b5y5
skip_b5y5               jmp     #b6y6
skip_b6y6               jmp     #buf_update
nul                     long    negx
d0                      long    $00000200               'destination/source field increments
t1                      long    $1F0 - reserves         '# of reserved registers to clear on startup
t2                      long    0
'-------------------- local variables -----------------------------------------
reserves
't3                     res     1                       ' temporary values
't4                     res     1
't5                     res     1
't6                     res     1
't7                     res     1
't8                     res     1

status                  res     1                       ' last compare status

fnumA                   res     1                       ' floating point A value
flagA                   res     1
expA                    res     1
manA                    res     1

fnumB                   res     1                       ' floating point B value
flagB                   res     1
expB                    res     1
manB                    res     1
'more uninitialized data
acum                    res     1                       'accumulator
inPtr                   res     1                       'filter data input location
outPtr                  res     1                       'filter data output location

fit 496


DAT

{{

┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     TERMS OF USE: MIT License                                       │                                                            
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and    │
│associated documentation files (the "Software"), to deal in the Software without restriction,        │
│including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,│
│and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,│
│subject to the following conditions:                                                                 │
│                                                                                                     │                        │
│The above copyright notice and this permission notice shall be included in all copies or substantial │
│portions of the Software.                                                                            │
│                                                                                                     │                        │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT│
│LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  │
│IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER         │
│LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION│
│WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}  
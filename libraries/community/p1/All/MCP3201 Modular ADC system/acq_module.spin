{{

┌──────────────────────────────────────────┐
│ MPC3201 ADC capture module    1.0        │
│ Author: Frank  Freedman                  │
│ Copyright (c) 2011 Frank Freedman        │
│ See end of file for terms of use.        │
└──────────────────────────────────────────┘

This is a capture module whose only function is
to capture the bits when told to by the clock gen
module. This is done this way so that n cores could
run n ADCs and do whatever they wanted with the bits.
In the curve tracer, these will be used for capturing
and storing to hub values of data points.

}}


var
  long  smp_val  'data valid.
  long  inp_pin  'data input pin
  long  csel     'chip select  used for starting acq window
  long  dacdir   'pin range for outputs to dac

pub acq_init(acq_cog,valid_pin,dat_pin,csel_pin,dacout)

  smp_val := valid_pin
  inp_pin := dat_pin
  csel    := csel_pin
  dacdir  := dacout

coginit(acq_cog, @acq_mod,@smp_val)           'start acq module

dat
ACQ_mod 'read serial ADC and xfer to parallel output
        org   0
initval mov     long_ptr,PAR       ' get base address of shared mem
        mov     base_addx,PAR      ' save base
        rdlong  s_val,long_ptr     ' save sample valid
        add     long_ptr,#4        '
        rdlong  smp_dat,long_ptr   ' save sample input valid pin
        add     long_ptr,#4        '
        rdlong  cselp,long_ptr     ' save csel pin
        add     long_ptr,#4        '
        rdlong  dac_out,long_ptr   ' save DAC output range
'end init
        or      dira,dac_out      ' enable output pins
main    waitpeq cselp,cselp       ' wait for csel high
        waitpne cselp,cselp       ' when csel goes low, start acq capture/store
get_val mov   acqvalue,null     ' clear to 0s
        mov   acqcks,#$00f      ' set to get 15 clock times
acq_bits    waitpeq s_val,s_val ' wait for sample time high
            mov     acq_bld,ina       ' get data bit from input
            test    acq_bld,smp_dat wc  ' see if input pin is high set C
            waitpne s_val,s_val     ' wait for sample to go low
            rcl     acqvalue,#$001    ' rotate in the carry bit
            djnz    acqcks,#acq_bits  ' go get rest of bits
        and   acqvalue,acq_mask       ' mask for lower 12 bits non-zero
        shl   acqvalue,#8      'move to upper bits
        mov   outa,acqvalue       ' putem out
        jmp   #main          ' after all counts,  go back to main and wait.



'preset values
acqclks  long $0000000e               ' bits to sample
acq_mask long $00000FFF         ' 12 bit mask
null     long $00000000         '

'var space
long_ptr      res       1
base_addx     res       1
smp_dat       res       1
s_val         res       1
cselp         res       1
dac_out       res       1
acq_bld       res       1
acqvalue      res       1
acqcks        res       1

fit $1ef                ' don't let PASM grow beyond $1ef

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}

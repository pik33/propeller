{{ ADC_0831_DEMO.spin  - 1.0 - January 2008


┌──────────────────────────────────────────┐
│ Copyright (c) 2008 Jean-Marc Lugrin      │               
│     See end of file for terms of use.    │               
└──────────────────────────────────────────┘

***********************************************************************
Based on an example of
          Larry Freeze   September 2007 (Obex, ADC0831 LM34)
Largely adapted (and hopefully clarified for beginners) by
          Jean-Marc Lugrin  January 2008   
***********************************************************************

The ADC0831 is an 8 bit single input ADC, very simple to use.
This code demonstrate how to read values from the ADC.
It is is simply displayed using FullDuplexSerial, for
example on PropTerm or any terminal emulator.

This code is intended to be a demonstration for beginners.
It is based from an example kindly provided by Larry Freeze,
but I adaped it to be easier to understand and use (at least
this is what I think).

You may want to refer to the datasheet of the ADC0831 to
understand the logic of the code, especially the figure
on ADC0831 timing.

The demo connection I used is as follow  (the pin are different from the
original code, but you can change them at will):


                 ADC0831
              
                                  │  Vcc(+5V)
              ┌───────────────┐   │
   pin 22 ────┤1 -CS   VCC  8 ├───┘                
         ┌────┤2 VIN+  CLK  7 ├─────────    pin 21
         │  ┌─┤3 VIN-  DO   6 ├───────    pin 20 (1K resistor)
         │  ╋─┤4 GND   Vref 5 ├───────┐  
         │   └───────────────┘       │                                    
                                     │
      ┌────────────────────────────┻─  +3.3V (or 5V)   
        10K                              
     

The potentiometer AND the Vref could be connected to the +5V also.
Value of the potentiometre is not critical.
In practice I connected ALL lines to the propeller via a 2.2K
resistors, to be on the safe side. 

The purpose of this object is to repeatedly read and display
the position of the ptoentiometer on the desktop monitor,
via a hyperterminal or PropTerm connection (see Parallax Propeller
Forums or OBEX to get PropTerm).

This object is a template, the code to control an ADC0831 is simple enough
that it is easy to adapt to your needs or extend if required.

NOTE : No delay is used to control the pulse width, as the ADC0831 is assumed to
follow Spin (which takes quite a few uSec per statements.
Max conversion rate is about 2.5KHz for a clock of 80 Mhz.

I have used these pins and connections in this object.
           ADC clk PIN 7 to propeller PIN 21  (preferably through 1K resistor)
           ADC cs  PIN 1 to propeller PIN 22  (preferably through 1K resistor)
           ADC do  PIN 2 to propeller PIN 20  (through 1K resistor)  
}}

CON

  _clkmode = xtal1 + pll16x   ' The code works at any frequency, but the serial line requires the crystal
  _xinfreq = 5_000_000        

 ' Define the pins.  This could be adapted for example to be a set of variable initialized
 ' by a function, so that the object can be used with multiple ADC 
  CLK_PIN     = 21
  CS_BAR_PIN  = 22              ' 'BAR' To remind you that this is an active low pin (idle state is high)
  DO_PIN      = 20

  ' Configuration only required for the example serial output
  RX_PIN      = 31
  TX_PIN      = 30
  BAUD_RATE   = 9600

OBJ 
    SER  : "FullDuplexSerial"    ' Object from the standard Propeller Tool library


    
pub Start  | data

' Connect to serial line to display data
  ser.start(RX_PIN, TX_PIN, 0, BAUD_RATE) 


  ' Initialiszation section
  initialize
 
  waitcnt(clkfreq/10+cnt)         ' Wait a little to make sure the external system is in a stable state
                                  ' (not really required for a potentiometer...)
 
  repeat

    ' Acquire 1 measurement
    data := AcquireValue

    ' At this point the value of 'data' is between 0 and 255
    DisplayValue(data)    

    waitcnt(clkfreq+cnt)          ' 1 second wait


PUB Initialize
{{ Initialize the pins direction and state. Must be called once. }}
  dira[DO_PIN]~                 ' set DO pin as input (is default at start, present for clarity)

  outa[CS_BAR_PIN]~~            ' sets pin -CS high  (you must always first set the value, then enable the output!)
  dira[CS_BAR_PIN]~~            ' sets -CS pin as output (this means disabled !)
 
  outa[CLK_PIN]~                ' sets clock pin low (is default at start, present for clarity)
  dira[CLK_PIN]~~               ' sets pin as output


PRI AcquireValue | data         ' data could also be a byte VARiable
{{ Aquiring data requires to assert CS, pulse the clock once to start aquisition, then
   pulse the clock 8 times to read each bit after the descending edge of the clock.
  The chip is driven by the clock signal we generate, so timing is not critical. }}
  
  data := 0                     ' This will accumulate the resulting value
  outa[CS_BAR_PIN]~             ' sets pin -CS low to activate the chip    

  outa[CLK_PIN]~~               ' pulse the clock, first high      
  outa[CLK_PIN]~                ' then low, this starts the conversion

  'Read 8 bits, MSB first.
  ' Althoug the datasheet I have says that LSB is not available on the ADC0831, it is present on my chip 
  repeat 8              
    data <<= 1                  ' Multiply data by two
    outa[CLK_PIN]~~             ' pulse the clock, first high      
    outa[CLK_PIN]~              ' then low, this makes the next bit available on DO
    data += ina[DO_PIN]         ' Add it to the current value
           
  outa[CS_BAR_PIN]~~            ' Terminated, deselect the chip
  return data   

PRI DisplayValue(value)
{{ Do something with the value. Here it is printed on screen.
   You should be able to see the values from 0 to 255 when
   turning the potentiometer.
   In real life you may want to scale and offset the value to
   represent some common unit of what you measure (voltage,
   temperature, ...}}
   
  ser.str(string("Value =   %"))    
  ser.bin(value,8)              'display binary value 
  ser.str(string("     "))     
  ser.dec(value)                'display decimal 
  ser.str(string($0D, $0A))

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
             
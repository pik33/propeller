{{
1)What it does and 2)why you care.
1.This program generates a standard tachometer signal for automobiles scaled to the angular position of a pot.
2.Its over 100 degrees outside now, and gas is still over $3.00 per gallon.
While developing automotive instrumentation it allows me to work in my air conditioned space and save fuel.  

Original Author: Mike Rector, KF4IXM, base:MCP3208_DEMO.spin
Version: 1.1
Copyright (c) Mike Rector, KF4IXM
See end of file for Terms of Use.
File: Desktach.spin (top object) Modified & renamed 7/5/2011 by Stan Cloyd for use with uController products.
                  
This demo demonstrates the Microchip MCP3208 8 channel adc chip on the ADC
module in socket A connected to the SpinStudio Propeller board (uController.com). 
It uses the MCP3208.spin object Written by Chip Gracey and outputs the adc
value (0-4096) of all 8 channels (labeled as 0-7) in Parallax Serial Terminal.
The Datasheet of the MCP3208 can be found here:
http://ww1.microchip.com/downloads/en/devicedoc/21298c.pdf
The SpinStudio ADC module link is here:
http://ucontroller.com/documentation/adcdoc.pdf
The SinStudio Propeller board link is here:
http://ucontroller.com/documentation/mainboarddoc.pdf
}}

CON
    _clkmode = xtal1 + pll16x                           
    _xinfreq = 5_000_000
    
VAR
  long rpm                            'crankshaft angular velocity
  long Frequency                      'internal combustion engine tachometer signal(simulated) 
  
OBJ     'no modifications were needed in the three supporting objects. Thanks guys!

adc     : "MCP3208"                   'controls & reads A/D sampling chip
pst     : "Parallax Serial Terminal"  'transmitts data to PC monitor
freq    : "Synth"                     'generates square waves per rpm on counters A and B.

CON
dpin    = 1       'both din and dout of the mcp3208 are connected to this pin on the SpinStudio board with ADC module in socket A.
cpin    = 0       'the clock pin of the mcp3208 is connected to this pin on the SpinStudio board with ADC module in socket A.
spin    = 2       'the chip select pin of the mcp3208 is connected to this pin on the SpinStudio board with ADC module in socket A.
tpin    = 16      'tachometer output pin on prototyping module (A) in socket C.  With an LM324AN the square wave is amplified to 0-12 volts.
                  'pins 17-19 reserved for future use.  Three op-amps remain available on the chip/board.
npin    = 20      'optional audio feed-back speaker output pin on prototyping module (E) in socket C.
                  'the piezo speaker from Parallax parts is doing the job here. cog 0, counter B
pub go
pst.start(115200)               'Start the Parallax Serial Terminal object at 115200 baud
adc.start(dpin, cpin, spin, 255)'Start the MCP3208 object and enable all 8 channels as single-ended inputs.
repeat
  pst.Str(String(pst#cs, pst#NL, pst#HM, "adc channel 0= "))                    'launch and enable PST to see the numbers
  pst.dec(adc.in(0))                                                            'channel zero shorted to ground to verify zero count
  {{pst.Str(String(pst#NL, "adc channel 1= "))                                  'outputs 1-6 n.i.u.(commented out)
  pst.dec(adc.in(1))                                                            'rotate pot clock-wise to increase RPM
  pst.Str(String(pst#NL, "adc channel 2= "))
  pst.dec(adc.in(2))
  pst.Str(String(pst#NL, "adc channel 3= "))
  pst.dec(adc.in(3))
  pst.Str(String(pst#NL, "adc channel 4= "))
  pst.dec(adc.in(4))
  pst.Str(String(pst#NL, "adc channel 5= "))
  pst.dec(adc.in(5))
  pst.Str(String(pst#NL, "adc channel 6= "))
  pst.dec(adc.in(6))
  }}
  pst.Str(String(pst#NL, "adc channel 7= "))                                    'raw count 4096 = 5 volts
  pst.dec(adc.in(7))
  pst.Str(String(pst#NL, "Engine RPM = "))                                      'rpm scaled to standard 8-grand tachometer
  rpm := adc.in(7) * 8000 / 4094
  pst.dec(rpm)
  pst.Str(String(pst#NL, "Frequency (hertz) = "))
  Frequency := rpm/30                                                           'Fequency scaled to 4-cylinder, 4-stroke ICE
  pst.dec(Frequency)
  Freq.Synth("A",tpin,Frequency)                        'Synth({Counter"A" or Counter"B"},Pin, Freq)
  Freq.Synth("B",npin,Frequency)                        'comment this line out to disable speaker 
  waitcnt(clkfreq/10 + cnt)                             '10Hz screen refresh
{{

┌──────────────────────────────────────────────────────────────────────────────────────┐
│                           TERMS OF USE: MIT License                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this  │
│software and associated documentation files (the "Software"), to deal in the Software │ 
│without restriction, including without limitation the rights to use, copy, modify,    │
│merge, publish, distribute, sublicense, and/or sell copies of the Software, and to    │
│permit persons to whom the Software is furnished to do so, subject to the following   │
│conditions:                                                                           │                                            │
│                                                                                      │                                               │
│The above copyright notice and this permission notice shall be included in all copies │
│or substantial portions of the Software.                                              │
│                                                                                      │                                                │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,   │
│INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A         │
│PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT    │
│HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION     │
│OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE        │
│SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                                │
└──────────────────────────────────────────────────────────────────────────────────────┘
}}
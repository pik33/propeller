{{

******************************************
* QuickStart Push-On Push-Off Demo  v2.0 *
*                                        *
* Author: Beau Schwabe                   *
* Copyright (c) 2011 Parallax            *
* See end of file for terms of use.      *
******************************************

Revision History:
  Version 1.0   - (06-06-2011) - original file created
  
  
  Version 2.0   - (07-06-2011) - 1-pin Sigma-Delta-ADC implementation for better noise immunity.

                               - Push-On / Push-Off implemented for easier BYTE reads of the
                                'buttons' that are pressed.   

Theory of Operation:
                                                                                                    
This program implements a 1-pin Sigma-Delta-ADC for each of the I/O pins.  Each ADC is capable of
detecting two distinct thresholds.  This creates a hysteresis to the 1.4V threshold of the I/O
providing greater noise immunity to external influences.


   3.3V ──── VDD

   2.2V ──── ADC threshold 2

                         I/O threshold ──── 1.4V

   1.1V ──── ADC threshold 1
 
     0V ──── GND
     
                                                                                                    
The Idea of a 1-pin Sigma-Delta-ADC is to sample the pin as an input, and then very briefly make
the pin an output in the opposite state. i.e. if the input reads a "0", then the output is made a
"1" and vise versa.  The resting state is a condition where the output state of the ADC is a "1" or
"0" every other iteration.  If the input is pulled to GND or VDD, then the output of the ADC would
be two consecutive states that are the same.  In the case with the QuickStart, since the buttons
would be pulled to ground, the two consecutive states would both be 1's ... opposite of the GND
detected by the input.  In another implementation, you could pull to VDD and have two consecutive
0's instead, but the way the QuickStart is designed, the Pull-down is to GND.  
                    
The ADC's function in this example is to keep track of how many times the I/O voltage needed to be
'bumped' in the same direction.  Under normal circumstances, the ADC's returned value would be a "1"
indicating the I/O value is somewhere between threshold 1 and threshold 2.  If you externally pull
the I/O to GND, then the ADC's value would be a "2".  Likewise a "0" if you pulled the I/O to VDD.
The distinction between a "1" and a "2" from the ADC is the key in order to determine a button press
or not.  This while at the same time creates the necessary hysteresis that helps to reject noise.


Please Note:

When programming the QuickStart, make sure that the surface that the QuickStart is sitting on is NOT
conductive.  This includes surfaces you may not think are conductive, such as polyurethane which
can be highly electrostatic.  This can cause programming problems under these conditions.
  

}}
  
CON

  _CLKMODE = XTAL1 + PLL16X
  _CLKFREQ = 80_000_000


OBJ

  Buttons     :      "Touch Buttons 2"    '' Push ON / Push OFF                  


PUB Main

    Buttons.start                         ' Launch the touch buttons driver
    dira[23..16]~~                        ' Set the LEDs as outputs
    repeat
      outa[23..16] := Buttons.State       ' Light the LEDs when touching the corresponding buttons 

CON
{{
┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     TERMS OF USE: MIT License                                     │                                                            
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and  │
│associated documentation files (the "Software"), to deal in the Software without restriction,      │
│including without limitation the rights to use, copy, modify, merge, publish, distribute,          │
│sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is      │
│furnished to do so, subject to the following conditions:                                           │
│                                                                                                   │
│The above copyright notice and this permission notice shall be included in all copies or           │
│ substantial portions of the Software.                                                             │
│                                                                                                   │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT  │
│NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND             │
│NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,       │
│DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,                   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE        │
│SOFTWARE.                                                                                          │     
└───────────────────────────────────────────────────────────────────────────────────────────────────┘
}}    
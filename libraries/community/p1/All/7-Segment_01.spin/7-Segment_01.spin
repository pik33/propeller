{{

 7-Segment_01.spin
 Program to count from 0-9 with 7-segment LEDs

 Created 2011-08-02 by Greg Denson

 Copyright (c) 2011 Greg Denson - See MIT License and Terms of Use at bottom of this program listing
 
 This program will count from 0 to 9 on a single 7-Segment LED, and then start over again, and continue to loop through the count

 This is another of the simple demo programs that I have worked on and shared.  As usual, it is aimed at the beginner in an
 effort to help them get started with some aspect of using the Propeller.  In this case, it is a first effort at using a
 7-segment LED
}}


CON
  _CLKMODE = XTAL1 + PLL2X      ' The system clock frequency setup (crystal frequency on the propeller board with a PLL multipler of 2)
  _XINFREQ = 5_000_000          ' The frequency of the crystal on the Propeller board.
                                '
  waiting  = 10_000_000         ' Define the, approximately, 1 second waiting time for each number that is displayed
                                ' This is due to the 5 MHz crystal frequency and the PLL of 2X (2 times)
                                ' So, 5,000,000 cycles per second times 2 = 10 million cycles per second.
                                ' Thus the wait period of 10 million cyles is equal to about 1 second
                                
{{
___________________________________________________________________________________________________________________________

HOOKING UP THE HARDWARE...

Connections from the Propeller chip to the 7-Segment LED are shown below:                                                       

IMPORTANT NOTE:  Since LED segments are turned on when the output pin is LOW or 0, you must send a zero to the output pin
                 in order to turn each segment on.  You must send a '1' or HIGH to the segments you want to turn off.
___________________________________________________________________________________________________________________________

7-Segment Pinout:
The 7-segment LED that I used has 5 connection pins across the top of the LED, and 5 pins across the bottom.  They are
arranged and named in the following manner:

1     2     3     4      5   <-- Top Row of Pin Connections to the Propeller  (In other words, connect 'A' to Prop Pin 1.)
A     B    +V     C      D   <-- Top Segments and Their Names

6     7     8     9     10   <-- Bottom Row of Pin Connections to the Propeller
H     G    +V     F      E   <-- Bottom Segments
___________________________________________________________________________________________________________________________

LED Diagram:
This diagrams shows which segment each of the above pins controls.  So, the pin with letter 'A' above controls the
segment marked 'A' in this diagram: 
     __C__
  B |     |D
    |__A__|
  H |     |F
    |__G__|   oE    'E' controls the right side decimal point.  I represented it with a small 'o' because the period is hard to see.

IMPORTANT NOTE:  Notice that Pin 3 in the top row, and Pin 8 in the bottom row are BOTH marked as +V.  That is not a typo!  There is no 
direct ground connection on this type of LED. the segments are connected to Ground or LOW when the program sets the output pin to LOW to 
turn the segment on.  So, both rows of pins have, in their center, a common anode, or commond +V connection.  Both must be connect to 
positive voltage.  My particular LED calls for +5 Volts.  Yours might be some other voltage, possibly +3.3 Volts, so check the specifications
for your LED.
___________________________________________________________________________________________________________________________

Here's how I made the above connections to my Parallax Professional Development Board:
These could be arranged differently, but the use of Prop pins 0-7 worked out well for me.

Prop     LED
Pin:     Segment:
7          A
6          B
5          C
4          D
3          E
2          F
1          G
0          H
___________________________________________________________________________________________________________________________

Here are the segments you want to use for creating each of the numerals from zero to nine:

            LED
Numeral     Segments     Prop Pins to set to LOW for each segment (all other pins are set to HIGH so their segments are OFF)

0           BCDFGH       6,5,4,2,1,0
1           DF           4,2  
2           ACDGH        7,5,4,1,0
3           ACDFG        7,5,4,2,1   
4           ABDF         7,6,4,2
5           ABCFG        7,6,5,2,1
6           ABDFGH       7,6,4,2,1,0
7           CDF          5,4,2
8           ABCDFGH      7,6,5,4,2,1,0
9           ABCDF        7,6,5,4,2
___________________________________________________________________________________________________________________________

Power Connections:
Remember to connect Pins 3 and 8 of the LED (the middle pins on the top and bottom rows of LED pins) to +V with a jumper.
In other words, connect V+ pins to the positive power strips on your breadboard.
If you aren't using a breadboard, just be sure to connect those +V pins to the +V pins on your Propeller in some manner.

___________________________________________________________________________________________________________________________

So, finally, here's how the connections look from the LED to the Propeller:

  LED PINS                  PROPELLER PINS (Professional Development Board or other Propeller Board)
                 ───┐      ┌───
          A    1    │─────│ Pin 7
Top       B    2    │─────│ Pin 6
Row of   +V    3    │─────│ +V  (5V or 3.3V?  Check the specs for your LED)
Pins      C    4    │─────│ Pin 5
          D    5    │─────│ Pin 4
                    │      │
          E    6    │─────│ Pin 3
Bottom    F    7    │─────│ Pin 2
Row of   +V    8    │─────│ +V  (5V or 3.3V?  Check the specs for your LED)
Pins      G    9    │─────│ Pin 1
          H   10    │─────│ Pin 0 
                 ───┘      └───

ANOTHER IMPORTANT NOTE:  If your 7-Segment LED is not in the same type of package as mine, you will need to create  your own
                         pin diagram - like the one above.  For example, if your pins are along the side instead of across the
                         top and bottom, just find which pins on the LED equate to segments A through H, and which are the power pins,
                         and then create a similar diagram to help with your hook ups.  I did look at a few of the other designs
                         on the Internet, and most have the common Anodes in the center of each side.  However, the pin numbers
                         are associated with different segments (letters A-H or A-G in some cases.) 
}}

PUB Go
  dira[0..7]~~                  ' Sets pins 0-7 as output lines with ~~
  outa[0..7]~~                  ' Sets all the pins, 0-7, to HIGH, thus turning off all the LED segments

  repeat                        ' Repeat forever (no number after repeat).
    wait                        ' An initial wait period of about 1 second.

    
    ' ZERO                      ' This first group of code lines displays a zero 
    turnOn_Seg(0, 0)            ' Comment lines, like the one above, tell you what digit the lines will display
    turnOn_Seg(1, 0)            ' Each set of lines from here on down displays a different digit on the 7-segment LED
    turnOn_Seg(2, 0)            ' Each line is a call to the turnOn_Seg object below, which will turn on and off the 
    turnOn_Seg(3, 1)            ' appropriate segments to create the number that is needed.
    turnOn_Seg(4, 0)            ' Each turnOn_Seg call sends two numbers (4, 0 for example).  The first number is the 
    turnOn_Seg(5, 0)            ' Propeller pin connected to the LED segment to be manipulated, and the second number is
    turnOn_Seg(6, 0)            ' the value to send to that pin:  0 = LOW or off, and 1 = HIGH or on.
    turnOn_Seg(7, 1)            ' NOTE: In understanding these values, don't forget that OFF at the pin actually turns
    wait                        '       the segment ON.  So, turnOn_Seg(7, 1) turns OFF the segment connected to Pin 7
                                '       of the Propeller chip.  But, turnOn_Seg(2, 0) turns ON the segment connected to Pin 2.    
                               
                                    
    ' ONE                       ' This group displays a '1'
    turnOn_Seg(0, 1)
    turnOn_Seg(1, 1)            
    turnOn_Seg(2, 0)             
    turnOn_Seg(3, 1)              
    turnOn_Seg(4, 0)            
    turnOn_Seg(5, 1)            
    turnOn_Seg(6, 1)             
    turnOn_Seg(7, 1)
    wait                         ' The 'wait' lines call up the wait routine below, and cause each number to remain on for 1 second. 


                                 
    ' TWO                        ' This group displays a '2'
    turnOn_Seg(0, 0)
    'wait
    turnOn_Seg(1, 0)             ' Another thing to note about these groups of lines... 
    'wait                        ' You've probably noticed that they actually turn on or off one segment at a time, not all
    turnOn_Seg(2, 1)             ' of the segments at once!  If the Propeller chip was slow, that would be annoying, as you
    'wait                        ' watched one segment after another come on to make each digit.  Thankfully, the Propeller
    turnOn_Seg(3, 1)             ' is very fast at moving from one segment to the other.  It is so fast that it appears to
    'wait                        ' turn on all of the new segments at once each time it displays a new number.
    turnOn_Seg(4, 0)             
    'wait                        ' To have some fun, I put wait statements between each segment's turnon command, so that I could
    turnOn_Seg(5, 0)             ' watch them come on, one at a time.  If you want to try this with your '2' digit, then 
    'wait                        ' un-comment the 'wait' calls at left.  When you've finished watching, comment them out again, or
    turnOn_Seg(6, 1)             ' or just delete the 'wait' lines.  See the note just below, and be sure you don't remove the 
    'wait                        ' final 'wait' line from the '2' group since it should stay there to keep your '2' visible.
    turnOn_Seg(7, 0)
    wait                         ' This ensures the '2' stays visible for about one second.  If you play with the wait statements
                                 ' inserted above, remember to NOT disable this wait statement when you disable the others.  If you
                                 ' do, you probably won't see the 2 fly past your eyes at all!  You'll jump from 1 to 3 in a flash.
                                 
    ' THREE                      ' This group displays a '3'
    turnOn_Seg(0, 1)
    turnOn_Seg(1, 0)
    turnOn_Seg(2, 0)
    turnOn_Seg(3, 1)
    turnOn_Seg(4, 0)
    turnOn_Seg(5, 0)
    turnOn_Seg(6, 1)
    turnOn_Seg(7, 0)
    wait


        
    ' FOUR                       ' This group displays a '4'
    turnOn_Seg(0, 1)
    turnOn_Seg(1, 1)
    turnOn_Seg(2, 0)
    turnOn_Seg(3, 1)
    turnOn_Seg(4, 0)
    turnOn_Seg(5, 1)
    turnOn_Seg(6, 0)
    turnOn_Seg(7, 0)
    wait


        
    ' FIVE                       ' This group displays a '5'
    turnOn_Seg(0, 1)
    turnOn_Seg(1, 0)
    turnOn_Seg(2, 0)
    turnOn_Seg(3, 1)
    turnOn_Seg(4, 1)
    turnOn_Seg(5, 0)
    turnOn_Seg(6, 0)
    turnOn_Seg(7, 0)
    wait


        
    ' SIX                        ' This group displays a '6'
    turnOn_Seg(0, 0)
    turnOn_Seg(1, 0)
    turnOn_Seg(2, 0)
    turnOn_Seg(3, 1)
    turnOn_Seg(4, 1)
    turnOn_Seg(5, 0)
    turnOn_Seg(6, 0)
    turnOn_Seg(7, 0)
    wait


        
    ' SEVEN                      ' This group displays a '7'
    turnOn_Seg(0, 1)
    turnOn_Seg(1, 1)
    turnOn_Seg(2, 0)
    turnOn_Seg(3, 1)
    turnOn_Seg(4, 0)
    turnOn_Seg(5, 0)
    turnOn_Seg(6, 1)
    turnOn_Seg(7, 1)
    wait


        
    ' EIGHT                      ' This group displays a '8'
    turnOn_Seg(0, 0)
    turnOn_Seg(1, 0)
    turnOn_Seg(2, 0)
    turnOn_Seg(3, 1)
    turnOn_Seg(4, 0)
    turnOn_Seg(5, 0)
    turnOn_Seg(6, 0)
    turnOn_Seg(7, 0)
    wait


        
    ' NINE                       ' This group displays a '9'
    turnOn_Seg(0, 1)
    turnOn_Seg(1, 1)
    turnOn_Seg(2, 0)
    turnOn_Seg(3, 1)
    turnOn_Seg(4, 0)
    turnOn_Seg(5, 0)
    turnOn_Seg(6, 0)
    turnOn_Seg(7, 0)
    wait                         ' And again, wait a second while we look at the '9' - before we start all over again.


PRI turnOn_Seg(outputpin, value)      ' This routine takes an pin number and value (0 or 1) to turn each LED segment on or off.
  outa[outputpin] := value            ' REMEMBER: The pin must go LOW to turn on the LED segment, and HIGH to turn it off.


PRI wait                               ' This routine causes a delay so that we get a second to see each number displayed.
  waitCnt(waiting + cnt)               ' The length of the wait period is Delay is specified by the waitPeriod constant, above.

{{ MIT License:
Copyright (c) 2011 Greg Denson 

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following
conditions: 

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. 

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                                                 

}}    
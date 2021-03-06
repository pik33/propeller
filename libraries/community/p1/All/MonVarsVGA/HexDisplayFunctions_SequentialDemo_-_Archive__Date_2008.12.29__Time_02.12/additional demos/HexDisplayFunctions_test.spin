{{

┌──────────────────────────────────────────┐
│ Demo program for MonVarsVGA              │
│ Author: Eric Ratliff                     │               
│ Copyright (c) 2008 Eric Ratliff          │               
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘

HexDisplayFunctions_test.spin, to test operation of object that makes display of bytes in hex longs easy
                               also to test result of no locks available and to measure cogs required
by Eric Ratliff 2008.12.27

}}

CON _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  DisplaySize_long = 296        ' count of longs in display area that we are using

  ' spacing on screen
  bytes_per_longLog = Monitor#NumBytesInLongLog ' expect value of 2, because Propeller has 4 bytes per long
  longs_per_line = Monitor#VarsPerRow                   
  bytes_per_line = longs_per_line << bytes_per_longLog

  ' offsets for test sets, determines where they show up on the screen
  a = 0                                                                         ' line number in display         byte test offset        
  b = 9                                                                         '                                full line display offset
  c = 12                                                                        '                                string test offset      
  d = 28                                                                        '                                long test offset        
  a_long = a * Monitor#VarsPerRow                                               ' long offsets into display
  b_long = b * Monitor#VarsPerRow                                               '
  c_long = c * Monitor#VarsPerRow                                               '
  d_long = d * Monitor#VarsPerRow                                               '
  a_byte = a_long << bytes_per_longLog                                          ' byte offsets into display
  b_byte = b_long << bytes_per_longLog                                          '
  c_byte = c_long << bytes_per_longLog
  NumCogsToHog = 4              ' 4 is OK, 5 prevents first launch attempt
  StackSize=10                  ' how big to make each stack for each hogged cog
  DoHogCogs=true
  
OBJ
  Monitor :     "MonVarsVGA"

VAR
  long MonArray[DisplaySize_long]
  long volation_amount          ' a temporary, units depend on oncontext
  long TheByteIndex             ' a temporary, byte into long, from left to right is 0,1,2,3
  long ShortenedSize            ' a temporary, reduced display size for testing too high indicies
  long HoggedCogs[NumCogsToHog]
  long Stacks[NumCogsToHog*StackSize]
  long StartResult

PUB go
''test main
  'LockHog ' consume all locks to see how object behaves, should complain with message in upper right corner and not do some functions
  if DoHogCogs  ' are we testing result of grabbing too many cogs to let VGA & monitor run?
    CogHog      ' grab a limited number of cogs to do nothing, denies cogs for next processes to test result
    'CogUnHog   ' test of unhogging

  ' inhibit opening paint of numbers
  Monitor.PreBlankVariables(@MonArray,0,DisplaySize_long-1)                     
  ' start showing signed long ints on the VGA monitor in Hex format
  StartResult := Monitor.UHexStart(Monitor#DevBoardVGABasePin,@MonArray,DisplaySize_long)
  MonArray[6] := StartResult

  ' test byte functions, start on line "a"
  Monitor.PutByte(@MonArray,a_byte+11,$a0)                                      ' expect byte in right position of index 2 long of line a+0
  '                                                                               expect byte in right position of index 2 long of line a+1
  Monitor.SafePutByte(@MonArray,DisplaySize_long,a_byte+1*bytes_per_line+11,$a1)
  '                                                                               attempt to write byte before beginning of array on line a+6
  volation_amount := 1
  Monitor.SafePutByte(@MonArray[(6+a)*longs_per_line],DisplaySize_long-((6+a)*longs_per_line),-volation_amount,$a6)
  '                                                                               attempt to write byte after end of array on line a+7
  volation_amount := 1
  Monitor.SafePutByte(@MonArray,a_long+(7+1)*longs_per_line,a_byte+((7+1)*bytes_per_line-1)+volation_amount,$a7)



  ' fill one line to define screen width, on ling "b"
  Monitor.SafePutMeasuredString(@MonArray,DisplaySize_long,b_byte,@S1,bytes_per_line)



  ' test string functions, start on line "c"
  ' expect string to start at first long of line c+0 and see 'unlikely values' at end
  Monitor.SafePutMeasuredString(@MonArray,DisplaySize_long,c_byte+0*bytes_per_line,@S0,5)
  ' expect string to start at first long of line c+1 and see 'neutral values' at end
  Monitor.SafePutMeasuredFrontierString(@MonArray,DisplaySize_long,c_byte+1*bytes_per_line,@S0,5)
  ' show string on basis of length measured by presence of null terminator, on line c+2
  Monitor.SafePutMeasuredFrontierString(@MonArray,DisplaySize_long,c_byte+2*bytes_per_line,@S0,strsize(@S0))


  ' attempt to show a string beginning at negative index, on line c+4
  volation_amount := 1
  Monitor.SafePutMeasuredFrontierString(@MonArray[(4+c)*longs_per_line],DisplaySize_long-((4+c)*longs_per_line),-volation_amount,@S0,5)
  
  ' atempt to show string 1 into 'last long of display, expect truncation at end of line on line c+5
  TheByteIndex := 0
  Monitor.SafePutMeasuredFrontierString(@MonArray,c_long+((5+1)*longs_per_line),c_byte+5*bytes_per_line+(bytes_per_line-1<<bytes_per_longLog)+TheByteIndex,@S0,9)
  ' atempt to show string 2 into 'last long of display, expect truncation at end of line on line c+6
  TheByteIndex := 1
  Monitor.SafePutMeasuredFrontierString(@MonArray,c_long+((6+1)*longs_per_line),c_byte+6*bytes_per_line+(bytes_per_line-1<<bytes_per_longLog)+TheByteIndex,@S0,9)
  ' atempt to show string 3 into 'last long of display, expect truncation at end of line on line c+7
  TheByteIndex := 2
  Monitor.SafePutMeasuredFrontierString(@MonArray,c_long+((7+1)*longs_per_line),c_byte+7*bytes_per_line+(bytes_per_line-1<<bytes_per_longLog)+TheByteIndex,@S0,9)
  ' atempt to show string 4 into 'last long of display, expect truncation at end of line on line c+8, note 3rd byte shows that it is 'unlikely' value not neutralized
  TheByteIndex := 3
  Monitor.SafePutMeasuredFrontierString(@MonArray,c_long+((8+1)*longs_per_line),c_byte+8*bytes_per_line+(bytes_per_line-1<<bytes_per_longLog)+TheByteIndex,@S0,9)
  ' attempt to show end of string starting beyond end of array, at line c+9
  ' expect nothing to show
  volation_amount := 1
  TheByteIndex := 3+volation_amount
  ShortenedSize := c_long+((9+1)*longs_per_line)
  Monitor.SafePutMeasuredFrontierString(@MonArray,ShortenedSize,((ShortenedSize-1)<<bytes_per_longLog)+TheByteIndex,@S0,9)

  ' some minimal test of the sring put routine that does not neurtalize the last byte
  ' show string on line c+11
  Monitor.SafePutMeasuredString(@MonArray,DisplaySize_long,c_byte+11*bytes_per_line,@S0,9)


  ' long test function, start on line "d"
  ' show long at beginning of line d+0
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+0*longs_per_line,$d0000000)
  ' attempt to show long at negative index on line d+1
  volation_amount := 1
  Monitor.SafePutLong(@MonArray[d_long+(1*longs_per_line)],DisplaySize_long-(d_long+(1*longs_per_line)),-volation_amount,$d0000001)
  ' attempt to show long at beyond end of array at line d+2
  volation_amount := 1
  ShortenedSize := d_long+((2+1)*longs_per_line)
  Monitor.SafePutLong(@MonArray,ShortenedSize,ShortenedSize-1+volation_amount,$d0000002)
  ' show same miscelaenous values as in other demo starting on line d+4
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+0,-2_000_000_000)
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+1,10)
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+2,-15)
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+3,-25)
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+4,-2111111111)
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+5,2111111111)
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+6,32767)
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+7,-32768)
  Monitor.SafePutLong(@MonArray,DisplaySize_long,d_long+4*longs_per_line+8,2_000_000_000)

  ' show some readable annotation in an area of the screen where we never expect variable value to change
  ' second argument is column index, third argument is row index
  Monitor.LiveString( STRING("HexDisplayFunctions_test.spin"),47,36)

  if DoHogCogs  ' are we testing result of grabbing too many cogs to let VGA & monitor run?
    if StartResult
      repeat  ' hang here forever
    else
      CogUnHog ' release the tied up cogs
      ' now try to show numbers
      Monitor.UHexStart(Monitor#DevBoardVGABasePin,@MonArray,DisplaySize_long)
      Monitor.LiveString( STRING("did not launch on first attempt, not enough cogs available"),53,1)
      repeat  ' hang here forever
  else
    repeat ' hang here forever

PRI LockHog
' grab all available locks
  repeat 8
    LOCKNEW

PRI CogHog|CogIndex
  repeat CogIndex from 0 to NumCogsToHog-1
    HoggedCogs[CogIndex] := cognew(DummmyFunction,@Stacks[CogIndex*StackSize])+1

PRI CogUnHog|CogIndex 
  repeat CogIndex from 0 to NumCogsToHog-1
    if HoggedCogs[CogIndex]     ' did we get this cog?
      cogstop(HoggedCogs[CogIndex]-1)

PRI DummmyFunction
  repeat  ' hang here forever

DAT

S0 byte $01,$02,$03,$04,$05,$00,$07,$08,$09
S1 byte $00,$01,$02,$03,   $04,$05,$06,$07,   $08,$09,$0a,$0b,   $0c,$0d,$0e,$0f,   $10,$11,$12,$13,   $14,$15,$16,$17,   $118,$19,$1a,$1b,  $1c,$1d,$1e,$1f

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
{{ Demo.spin

Illustrates use of SN754410 object. See SN754410.spin for instructions.

Copyright (c) Javier R. Movellan, 2008
Distribution and use: MIT License (see below)

Revision History:
        Version 1.03   - March 12 2008 added MIT terms of use
        Version 1.02   - March 12 2008' chnaged to -100 to 100 velocity standard
        Version 1.00   - March 11 2008   original file created


}}
VAR long stack[90]
    long p  ' controls speed from 0 to 100
    long d  ' controls direction 0 or 1
CON
  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000

   ' Configuration only required for the example serial output                                                                  
  RX_PIN      = 31
  TX_PIN      = 30
  BAUD_RATE   = 9600

OBJ
  motor : "SN754410"
  SER  : "FullDuplexSerial"    ' Object from the standard Propeller Tool library
   
PUB main
' Connect to serial line to display data
  ser.start(RX_PIN, TX_PIN, 0, BAUD_RATE)

  motor.start

  motor.setp(100) 
  repeat  while motor.getp > -1001
    motor.setp(motor.getp -0) '  each second reduce the speed
    ser.str(string("Speed = ")) ' Display current speed and direction in serial port   
    ser.dec(motor.getp)
    ser.str(string($0D, $0A))
    waitcnt(clkfreq+cnt) ' wait for one second
    
  motor.setp(0)

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
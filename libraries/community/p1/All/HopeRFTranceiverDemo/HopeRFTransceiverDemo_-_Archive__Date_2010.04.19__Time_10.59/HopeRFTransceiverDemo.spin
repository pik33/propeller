{{
                      HOPERF HM-TR 433Mhz Transceiver test program
                                  Author: Ray Tracy
                             Copyright (c) 2010 Ray Tracy
                        * See end of file for terms of use. *
                   ┌─────────────────────────────────────────────────┐
                   │                                                 └─┐
                   │   HOPERF HM-TR TTL  433Mhz Transceiver          ┌─┘ Antenna
                   │                                                 │
                   │ VCC DTx GND DRx CFG ENA                         │
               +5  │  1   2   3   4   5   6                          │          
                  └──┬───┬───┬───┬───┬───┬──────────────────────────┘   
               │      │   │   │   │   │   │     
               └──────┘   │      │      │
                          │       │       └─────────── Enable (EnaPin)
                          │       │                 
                          │       └─────────── Tx from Prop (TxPin)
                          │       
                          └───────────  Rx To Prop (RxPin)

     Note: #1 Tx from the Prop goes to DRx on the module
              Rx to the Prop goes to DTx on the module.
           #2 The HM-TR is really half duplex and automatically
              switches to receive after send. 

  I have setup two HopeRF HM-TR modules wired as above on the Propeller demo board with
  the I/O pin assignments shown below. Two cogs Labeled A & B are started.  Cog A talks
  to board A. Cog B talks to board B.  You may select one of two different test modes
  by changing the comments in the Main routine below. See the appropriate modules for
  details of the test performed.
  
}}
CON
  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000

' Board A Pin Assignments
  ARxPin   = 2      
  ATxPin   = 1      
  AEnable  = 0      
' Board B Pin Assignments
  BRxPin   = 5        
  BTxPin   = 4       
  BEnable  = 3

  Led1     = 16
  Led2     = 19
   
OBJ
   Sr[2] : "SendRcve433"
   Mr[2] : "MasterSlave433"
      
PUB Main
   Sr[0].Start(ARxPin, ATxPin, AEnable, True)         ' Board A Sender
   Sr[1].Start(BRxPin, BTxPin, BEnable, False)        ' Board B Receiver
'   Mr[0].Start(ARxPin, ATxPin, AEnable, True)         ' Board A Master
'   Mr[1].Start(BRxPin, BTxPin, BEnable, False)        ' Board B Slave
   Repeat
      
DAT
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
     
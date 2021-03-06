{
********************************************
    Test ADC0834 Demo
********************************************
    Charlie Dixon (CDSystems) (C)2007 
********************************************
}
CON
  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000

VAR
    long  x, y     

OBJ
    tv    :     "TV"
    gr    :     "Graphics"
    Num   :     "Numbers"
    adc   :     "CD_ADC0834"
        
PUB DIAL | i,dx,dy,Temp,okay

    'start tv
    tv.start(12)
    gr.start
    adc.start(0)

'**************************************************************************************************
' Main Program Loop to get and display ADC data to TV Screen
'**************************************************************************************************

    repeat
      
      Temp := adc.GetADC(0)
      
      Temp := adc.GetADC(1)
      
      Temp := adc.GetADC(2)
      
      Temp := adc.GetADC(3)
DAT
     {<end of object code>}
     
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
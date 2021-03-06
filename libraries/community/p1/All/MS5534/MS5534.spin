{{MS5534.spin}}
'' Copyright (c) 2008 Vladisalv Magditch
''     See end of file for terms of use.

'' Communication with MS5534 (Intersema)
'' Write  to   DIN  on reasing SCLK
'' Sample from DOUT on failing SCLK

''Reset sequence:
''SCLK
''DOUT                      
'' DIN
''Code     A   │   A   │   A   │   A   │   0   │
''Code for reset $AAAA0

''Measurement data read-out sequence:
''SCLK                         
''DOUT  conversion ~33mS       
'' DIN       
''Code     F   │   4   │   0   │                         msb:7 6 5 4 3 2 1 0 lsb:7 6 5 4 3 2 1 0
''Code for pressure    $F40;
''Code for temperature $F20;

''Calibration data read-out sequence:
''SCLK      
''DOUT      
'' DIN      
''Code     E   │   A   │   8    msb:7 6 5 4 3 2 1 0 lsb:7 6 5 4 3 2 1 0
''Code for W1 $EA8;   W1 coefficients C1 & C5I
''Code for W2 $EB0;   W2 coefficients C5II & C6
''Code for W3 $EC8;   W3 coefficients C4 & C2I
''Code for W4 $ED0;   W4 coefficients C3 & C2II

              
CON
   _1us = 1_000_000
   _W1 = $0157 '(revers from $EA8 for shift thrue last significant bit)
   _W2 = $00D7 '(revers from $EB0 for shift thrue last significant bit)
   _W3 = $0137 '(revers from $EC8 for shift thrue last significant bit)
   _W4 = $00B7 '(revers from $ED0 for shift thrue last significant bit)
   _Pression = $002F '(revers from $F40 for shift thrue last significant bit)
   _Temperature =$004F  '(revers from $F20 for shift thrue last significant bit) 

   
VAR
 long  Stack[9]             'Stack space for new cog
 long clkcycles, clkcycles_us
 
 byte  Cog                            'Hold ID of cog in use, if any 
 byte  sclk           ' Serial CLocK Pin / To  MS5534 
 byte  dout           ' Data OUT Pin   / From  MS5534 
 byte   din           ' Data IN Pin  / To  MS5534

 word inlet           ' reception
 word mem             ' calcul reminder
 word BitMap          ' Bit-pattern of calibration data
                     
 word SENST1          ' Coefficient 1 of calibration data - Pressure sensitivity
 word OFFT1           ' Coefficient 2 of calibration data - Pressure offset
 word TCS             ' Coefficient 3 of calibration data - Temp. coeff. of press. sens.
 word TCO             ' Coefficient 4 of calibration data - Temp. coeff. of press. offset
 word Tref            ' Coefficient 5 of calibration data - Reference Temperature
 word TEMPSENS        ' Coefficient 6 of calibration data - Temp. coeff. of temp. sens.
 word D1              ' Measure pressure value
 word D2              ' Measure temperature value

 long UT1             ' Calibration temperature
 long dT              ' Difference between actual and reference temperature
 long TEMP            ' Actual temperature
 long OFF             ' Offset at actual temperature
 long SENS            ' Sensitivity at actual temperature
 long X               ' Sensitivity at actual temperature
 long P               ' Actual pressure

    
PUB Init( inSCLK, inDOUT, inDIN )

  clkcycles_us := ( clkfreq / _1us  ) #> 381  
  
  sclk := inSCLK
  dout := inDOUT
  din  := inDIN

  dira[sclk]~~           'set to output
  dira[din]~~            'set to output           
  delay_us(5)
  
''Reset Instrument
  writeByte($55)
  writeByte($55)
  writeByte($0)
  outa[sclk]~~           'set to 1         
  delay_us(5)
  outa[sclk]~            'set to 0
  delay_us(5)
  
 ''Read and un-mape Calibration Data 
 BitMap := Value( _W1,0 )
 mem~
 if (BitMap & $0001) == 1
   mem := $0400
 SENST1 := BitMap >> 1             ' Pressure sensitivity 

 BitMap := Value( _W2,0 )
 TEMPSENS := BitMap & $003f        ' Temp. coeff. of temp. sens.
 Tref := (BitMap >> 6 ) | mem      ' Reference Temperature

 BitMap := Value( _W3,0 )
 TCO := BitMap >> 6                ' Temp. coeff. of press. offset 
 mem := (BitMap & $003F) << 6

 BitMap := Value( _W4,0 )
 OFFT1 :=  (BitMap & $003F) | mem  ' Pressure offset
 TCS := BitMap >> 6                ' Temp. coeff. of press. sens.

 UT1 := 8 * Tref + 20224           ' Calibration temperature 

PUB TAct(void)
 D2 := Value( _Temperature, 1 )
 if (D2 < UT1)
   mem := ( D2 - UT1 ) >> 7
   dT := ( D2 - UT1 ) - ( mem * mem ) >> 2
   TEMP := ( 200 + dT * (( TEMPSENS + 50 ) >> 10 ) + dT >> 8 ) / 10
 else
   dT := ( D2 - UT1 )
   TEMP := ( 200 + dT * (( TEMPSENS + 50 ) >> 10 )) / 10   
 return(TEMP) 

PUB PAct(void)
 D1 := Value( _Pression, 1 )
 OFF :=  OFFT1 << 2 + (( TCO - 512 ) * dT ) >> 12
 SENS := SENST1 + ( TCS * dT ) >> 10 + 24576
 X := ( SENS * ( D1 - 7168 )) >> 14 - OFF
 P := ( X * 100 ) >> 5 + 25000    ' 0.01mbar resolution
 return(P)                                                                      

PUB Cx(num)
case num
   1 : return(SENST1)          ' Coefficient 1 of calibration data - Pressure sensitivity
   2 : return(OFFT1)           ' Coefficient 2 of calibration data - Pressure offset
   3 : return(TCS)             ' Coefficient 3 of calibration data - Temp. coeff. of press. sens.
   4 : return(TCO)             ' Coefficient 4 of calibration data - Temp. coeff. of press. offset
   5 : return(Tref)            ' Coefficient 5 of calibration data - Reference Temperature
   6 : return(TEMPSENS)        ' Coefficient 6 of calibration data - Temp. coeff. of temp. sens.
   7 : return(UT1)             ' Calibration temperature 
   8 : return(dT)              ' Difference between actual and reference temperature
   9 : return(TEMP)            ' Actual temperature
  10 : return(OFF)             ' Offset at actual temperature
  11 : return(SENS)            ' Sensitivity at actual temperature 
  12 : return(X)               ' Sensitivity at actual temperature
  13 : return(P)               ' Actual pressure  
    

PRI Value( Cmd, Wait ) | i , ii
  Addr( Cmd )  
  if Wait == 0
    outa[sclk]~~           'set to 1         
    delay_us(2)
    outa[sclk]~            'set to 0
    delay_us(2)
  else
    waitpeq(0, |<dout,0)   ' wait for end of conversion
  inlet~                         
  repeat i from 0 to 15    '15->0
    outa[sclk]~~          'set to 1
    ii := 15 - i         
    if ina[dout] == 1
      inlet |= |<ii       ' set bit
    outa[sclk]~           'set to 0           
    delay_us(2)          

  return(inlet)
 
PRI Addr( Cmd ) | i
  repeat i from 0 to 11    
    outa[din] := Cmd       
    Cmd >>= 1
    outa[sclk]~~          'set to 1         
    delay_us(2)
    outa[sclk]~           'set to 0 
    delay_us(2)
    
PRI writeByte( Code ) | i  

  repeat i from 0 to 7    
    outa[din] := Code       
    Code >>= 1
    outa[sclk]~~          'set to 1         
    delay_us(2)
    outa[sclk]~           'set to 0           
    delay_us(2)
     
PUB delay_us( period )
  clkcycles := ( clkcycles_us * period ) #> 381
  waitcnt(clkcycles + cnt)                                   ' Wait for designated time

PUB lpf (Act, Awg, Coeff) | tmp ' coeff = 100 <=> 100%
 tmp := Awg  
 long[Awg] := (( Act * Coeff ) + ( tmp * ( 100 - Coeff ))) / 100
  

{{
                            TERMS OF USE: MIT License                                                           

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
}}
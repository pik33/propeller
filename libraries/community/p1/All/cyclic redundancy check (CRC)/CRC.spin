{{

                **************************************************
                          CRC V1.0       Cyclic redundancy check 
                **************************************************
                   coded by Jason Wood jtw.programmer@gmail.com        
                ************************************************** 

                  ┌──────────────────────────────────────────┐
                  │ Copyright (c) 2008 Jason T Wood          │               
                  │     See end of file for terms of use.    │               
                  └──────────────────────────────────────────┘
                         
}}
PUB CRC8_str ( key ) : CRC | j, x

{{

  Determins the CRC8 Value of a String at address "key"

OBJ

  BS2 : "BS2_Functions"
  
PUB Main

  BS2.Debug_Dec ( CRC.CRC8_bin ( string( "Testing" ) ) )
  BS2.Debug_Str ( String(13) )

}}

  CRC := 0

  repeat strsize(key)
    
    X := byte[key++]
    
    repeat 7
      j := 1 & (X ^ CRC)
      
      CRC := (CRC / 2) & $FF
                        
      X := (X / 2) & $FF

      IF (j <> 0)
        CRC := CRC ^ $8C
        
PUB CRC8_bin ( key, len ) : CRC | j, x
{{

  Determins the CRC8 Value of a byte array at address "key"
  who's length is equle to "len" - 1.

OBJ

  BS2 : "BS2_Functions"
  
VAR

  byte crcTst[7]
  
PUB Main

  crcTst[0] := 80 
  crcTst[1] := 101 
  crcTst[2] := 115 
  crcTst[3] := 116 
  crcTst[4] := 105 
  crcTst[5] := 110 
  crcTst[6] := 103

  BS2.Debug_Dec ( CRC.CRC8_bin ( @crcTst , 7 ) )
  BS2.Debug_Str ( String(13) )

}}

  CRC := 0

  repeat len - 1
    
    x := byte[key++]
    
    repeat 7
      j := 1 & (x ^ CRC)
      
      CRC := (CRC / 2) & $FF

      x := (x / 2) & $FF

      IF (j <> 0)
        CRC := CRC ^ $8C



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
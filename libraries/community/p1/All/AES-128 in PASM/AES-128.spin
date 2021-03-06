{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       AES-128 in PASM (C) 2010-08-27 Eric Ball                                               │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                    TERMS OF USE: Parallax Object Exchange License                                            │                                                            
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

PUB start
  SBoxPtr := @SBox
  ISBoxPtr := @InvSBox
  RESULT := COGNEW( @KeyExpand, @KeyExpand )
DAT
                          ORG      0

{{
AES-128 Key Expansion:
key[3..0] is 128 bit key (four 32 bit words)
for i = 4 to 43
  temp = key[i-1]
  if ( i mod 4 == 0 )
    temp = SubWord( RotWord( temp ) ) XOR Rcon[i/4]
  key[i] = temp XOR key[i-4]

RotWord is rotate by 8 bits
out[3,2,1,0] = in[0,3,2,1]

SubWord is a lookup table for each byte in word
out[x] = Sbox[ in[x] ]

Rcon[n] is 1<<(n-1) in Rijndael's finite field 
}}

KeyExpand                 ' expand Key[3..0] to Key[43..4] (round key[0..9])
                          MOV      GFx2var, #1                        ' initialize Rcon
                          MOVS     KEs1, #Key+3                       ' initialize
                          MOVS     KEs2, #Key+0                        
                          MOVD     KEd3, #Key+4                        
                          MOV      RoundNum, #40
KEs1                      MOV      in, Key+3+0                        ' in := key[i-1]
                          ADD      KEs1, #1                           ' next key word
                          AND      RoundNum, #3             wz,nr     ' if ( i mod 4 ) == 0
            if_nz         JMP      #KEs2                              
                          CALL     #SubWord                           ' out := SubWord( RotWord( in ) )
                          XOR      out, GFx2var                       ' out ^= Rcon[i/4]
KEs2                      XOR      out, Key+0                         ' out ^= key[i-4]
                          ADD      KEs2, #1                           ' next key word
KEd3                      MOV      Key+4, out                         ' key[i] = out
                          ADD      KEd3, D1                           ' next key word
                          AND      RoundNum, #2             wz,nr     ' z = !RoundNum.1
                          SHR      RoundNum, #1             wc,nr     ' c = RoundNum.0
            if_z_and_c    CALL     #GFx2                              ' if RoundNum & 3 == 1 advance Rcon
                          DJNZ     RoundNum, #KEs1

{{
AES-128 Cipher:
state = in
AddRoundKey( state, key[0] )
for round = 1 to 9
  SubBytes( state )
  ShiftRows( state )
  MixColumns( state )
  AddRoundKey( state, key[round] )
SubBytes( state )
ShiftRows( state )
AddRoundKey( state, key[10] )
out = state

AddRoundKey:    XOR with key
out[x] = in[x] XOR key[n][x]

SubBytes is a lookup table operation for each byte in state
out[x] = SBox[ in[x] ]

ShiftRows:
out[0]=in[0]    out[4]=in[4]    out[8]=in[8]    out[C]=in[C]
out[1]=in[5]    out[5]=in[9]    out[9]=in[D]    out[D]=in[1]
out[2]=in[A]    out[6]=in[E]    out[A]=in[2]    out[E]=in[6]
out[3]=in[F]    out[7]=in[3]    out[B]=in[7]    out[F]=in[B]

MixColumns:
out[3..0] = MixColumn in[3..0]
out[7..4] = MixColumn in[7..4]
out[B..8] = MixColumn in[B..8]
out[F..C] = MixColumn in[F..C]

MixColumn based on ideas from "An Efficient Architecture for the AES Mix Columns Operation" by Hua Li and Zac Friggstad

out[0] = 2*in[0] + 2*in[1] + in[1] + in[2] + in[3]
out[1] = 2*in[1] + 2*in[2] + in[2] + in[3] + in[0]
out[2] = 2*in[2] + 2*in[3] + in[3] + in[0] + in[1]
out[3] = 2*in[3] + 2*in[0] + in[1] + in[0] + in[2]
where 2* is multiplication by 2 in Rijndael's finite field and + is exclusive or
}}

EnCipher
                          MOV      istate, Data                       ' istate := Data
                          MOV      istate+1, Data+1
                          MOV      istate+2, Data+2
                          MOV      istate+3, Data+3
                          XOR      istate, Key                        ' AddRoundKey( istate, key[0] )
                          XOR      istate+1, Key+1
                          XOR      istate+2, Key+2
                          XOR      istate+3, Key+3
                          MOVS     ECs2, #Key+4                       ' reset round key
                          MOV      RoundNum, #9                       ' 9 rounds
ECloop                    CALL     #ShiftRows                         ' istate = ShiftRows( SubBytes( istate ) )
                          MOVS     ECs1, #istate                      ' istate = AddRoundKey( MixColumns( istate ) )
                          MOVD     ECd1, #istate                       
                          MOV      loop1, #4                          ' for each column AddRoundKey( MixColumn( key[round+n] )
ECs1                      MOV      in, istate+0                        
                          ADD      ECs1, #1                            
                          MOV      GFx2var, in
                          CALL     #GFx2                              ' GFx2var[3,2,1,0] = 2 * in[3,2,1,0]
                          MOV      out, GFx2var                       ' out[3,2,1,0] := 2 * in[0,3,2,1]
                          ROR      out, #8                             
                          XOR      out, GFx2var                       ' out[3,2,1,0] ^= 2 * in[3,2,1,0]
                          ROR      in, #8                              
                          XOR      out, in                            ' out[3,2,1,0] ^= in[0,3,2,1]
                          ROR      in, #8                              
                          XOR      out, in                            ' out[3,2,1,0] ^= in[1,0,3,2]
                          ROR      in, #8                              
                          XOR      out, in                            ' out[3,2,1,0] ^= in[2,1,0,3]
ECs2                      XOR      out, Key+4+0                        
                          ADD      ECs2, #1                            
ECd1                      MOV      istate+0, out                       
                          ADD      ECd1, D1                            
                          DJNZ     loop1, #ECs1                        
                          DJNZ     RoundNum, #ECloop                   
                          CALL     #ShiftRows                         ' istate = ShiftRows( SubBytes( istate )
                          XOR      istate, Key+40                     ' AddRoundKey( istate, key[10] )
                          XOR      istate+1, Key+41                    
                          XOR      istate+2, Key+42
                          XOR      istate+3, Key+43

{{
AES-128 InvCipher
state = in
AddRoundKey(state, key[10])
for round = 9 to 1
  InvShiftRows(state)
  InvSubBytes(state)
  AddRoundKey(state, key[round])
  InvMixColumns(state)
InvShiftRows(state)
InvSubBytes(state)
AddRoundKey(state, key[0])
out = state

InvShiftRows:
out[0]=in[0]    out[4]=in[4]    out[8]=in[8]    out[C]=in[C]
out[1]=in[D]    out[5]=in[1]    out[9]=in[5]    out[D]=in[9]
out[2]=in[A]    out[6]=in[E]    out[A]=in[2]    out[E]=in[6]
out[3]=in[7]    out[7]=in[B]    out[B]=in[F]    out[F]=in[3]

AddRoundKey:    XOR with key
out[x] = in[x] XOR key[n][x]

InvSubBytes is a lookup table operation for each byte in state
out[x] = InvSBox[ in[x] ]

InvMixColumns:
out[3..0] = InvMixColumn in[3..0]
out[7..4] = InvMixColumn in[7..4]
out[B..8] = InvMixColumn in[B..8]
out[F..C] = InvMixColumn in[F..C]

InvMixColumn based on ideas from "An Efficient Architecture for the AES Mix Columns Operation" by Hua Li and Zac Friggstad

out[0] = 8*in[0] + 8*in[1] + 8*in[2] + 8*in[3] + 4*in[0] + 4*in[2] + 2*in[0] + 2*in[1] + in[1] + in[2] + in[3]
out[1] = 8*in[0] + 8*in[1] + 8*in[2] + 8*in[3] + 4*in[1] + 4*in[3] + 2*in[1] + 2*in[2] + in[2] + in[3] + in[0]
out[2] = 8*in[0] + 8*in[1] + 8*in[2] + 8*in[3] + 4*in[2] + 4*in[0] + 2*in[2] + 2*in[3] + in[3] + in[0] + in[1]
out[3] = 8*in[0] + 8*in[1] + 8*in[2] + 8*in[3] + 4*in[3] + 4*in[1] + 2*in[3] + 2*in[0] + in[1] + in[0] + in[2]
where n* is multiplication by n in Rijndael's finite field and + is exclusive or
}}

DeCipher                  ' assume Key Expansion already done and block to be decrypted in instate
                          XOR      istate, Key+40                     ' AddRoundKey( istate, key[10] )
                          XOR      istate+1, Key+41
                          XOR      istate+2, Key+42
                          XOR      istate+3, Key+43
                          MOVS     DCs2, #Key+39                      ' reset round key
                          MOV      RoundNum, #9                       ' 9 rounds
DCloop                    CALL     #InvShiftRows                      ' istate = SubBytes( InvShiftRows( istate ) )

                          MOVS     DCs1, #istate+3                    ' istate = MixColumns( AddRoundKey( istate ) )
                          MOVD     DCd3, #istate+3                     
                          MOV      loop1, #4                          ' for each column MixColumn( AddRoundKey( key[round+n] )
DCs1                      MOV      in, istate+3                       ' work backwards through columns
                          SUB      DCs1, #1
DCs2                      XOR      in, Key+39                         ' so the key can be worked backwards too
                          SUB      DCs2, #1
                          MOV      GFx2var, in
                          CALL     #GFx2                              ' GFx2var[3,2,1,0] = 2 * in[3,2,1,0]
                          MOV      out, GFx2var                       ' out[3,2,1,0] := 2 * in[0,3,2,1]
                          ROR      out, #8                             
                          XOR      out, GFx2var                       ' out[3,2,1,0] ^= 2 * in[3,2,1,0]
                          ROR      in, #8                              
                          XOR      out, in                            ' out[3,2,1,0] ^= in[0,3,2,1]
                          ROR      in, #8                              
                          XOR      out, in                            ' out[3,2,1,0] ^= in[1,0,3,2]
                          ROR      in, #8                              
                          XOR      out, in                            ' out[3,2,1,0] ^= in[2,1,0,3]
                          CALL     #GFx2                              ' GFx2var[3,2,1,0] = 4 * in[3,2,1,0]
                          XOR      out, GFx2var                       ' out[3,2,1,0] ^= 4 * in[3,2,1,0]
                          ROR      GFx2var, #16
                          XOR      out, GFx2var                       ' out[3,2,1,0] ^= 4 * in[1,0,3,2]
                          CALL     #GFx2                              ' GFx2var[3,2,1,0] = 8 * in[1,0,3,2]
                          XOR      out, GFx2var                       ' out[3,2,1,0] ^= 8 * in[1,0,3,2]
                          ROR      GFx2var, #8
                          XOR      out, GFx2var                       ' out[3,2,1,0] ^= 8 * in[2,1,0,3]
                          ROR      GFx2var, #8
                          XOR      out, GFx2var                       ' out[3,2,1,0] ^= 8 * in[3,2,1,0]
                          ROR      GFx2var, #8
                          XOR      out, GFx2var                       ' out[3,2,1,0] ^= 8 * in[0,3,2,1]
DCd3                      MOV      istate+3, out                       
                          SUB      DCd3, D1                            
                          DJNZ     loop1, #DCs1                        

                          DJNZ     RoundNum, #DCloop                   
                          CALL     #InvShiftRows                      ' istate = SubBytes( ShiftRows( istate )
                          XOR      istate, Key+0                      ' AddRoundKey( istate, key[0] )
                          XOR      istate+1, Key+1                     
                          XOR      istate+2, Key+2
                          XOR      istate+3, Key+3

' end of main routines    
Endless                   JMP      #Endless

SubByte                  ' SBout := Sboxptr[in>>8]
                          ROR      in, #8                             ' All users needed this anyway
                          MOV      SBout, in                          ' copy to result
                          AND      SBout, #$FF                        ' mask off LSB
                          ADD      SBout, SBoxptr                     ' add HUB base pointer
                          RDBYTE   SBout, SBout                       ' retrieve byte
SubByte_ret               RET

SubWord                   ' out[4] = SubBytes( RotWord( in[4] ) )
                          CALL     #SubByte 
                          MOV      out, SBout
                          CALL     #SubByte
                          SHL      SBout, #8
                          OR       out, SBout
                          CALL     #SubByte
                          SHL      SBout, #16
                          OR       out, SBout
                          CALL     #SubByte
                          SHL      SBout, #24
                          OR       out, SBout
SubWord_ret               RET

ShiftRows                 ' istate[16] := ShiftRows( SubBytes( istate[16] ) )
                          MOV      ostate+1, #0                       ' ostate[0] is never read
                          MOV      ostate+2, #0
                          MOV      ostate+3, #0
                          MOVS     SRs1, #istate
                          MOVS     SRs2, #8
                          MOVD     SRd3, #ostate+3
                          MOVD     SRd4, #istate
                          MOV      loop1, #4
SRs1                      MOV      in, istate+0
                          ADD      SRs1, #1
                          MOV      loop2, #4
SRloop                    CALL     #SubByte
SRs2                      ROL      SBout, #8+0
                          ADD      SRs2, #8
SRd3                      OR       ostate+3+0, SBout
                          SUB      SRd3, D1
                          DJNZ     loop2, #SRloop
SRd4                      MOV      istate+0, SBout
                          ADD      SRd4, D1
                          ADD      SRd3, D5                           ' reset & advance 1
                          DJNZ     loop1, #SRs1
                          OR       istate+1, ostate+1
                          OR       istate+2, ostate+2
                          OR       istate+3, ostate+3
ShiftRows_ret             RET

InvShiftRows              ' istate[16] := SubBytes( ShiftRows( istate[16] ) )
                          MOV      ostate, #0
                          MOV      ostate+1, #0
                          MOV      ostate+2, #0
                          MOV      ostate+3, #0
                          MOVS     ISs1, #istate
                          MOVD     ISd3, #ostate
                          MOVD     ISd4, #istate
                          MOV      loop1, #4
ISs1                      MOV      in, istate+0
                          ADD      ISs1, #1
                          MOVS     ISs2, #0
                          MOV      loop2, #4
ISloop                    MOV      out, in
                          AND      out, #$FF
                          ADD      out, ISBoxPtr
                          RDBYTE   out, out
                          SHR      in, #8
ISs2                      SHL      out, #0
                          ADD      ISs2, #8
ISd3                      OR       ostate+0, out
                          ADD      ISd3, D1
                          DJNZ     loop2, #ISloop
                          SUB      ISd3, D3                           ' reset & advance 1
ISd4                      MOV      istate+0, #0
                          ADD      ISd4, D1
                          DJNZ     loop1, #ISs1
                          OR       istate, ostate
                          OR       istate+1, ostate+1
                          OR       istate+2, ostate+2
                          OR       istate+3, ostate+3
InvShiftRows_ret          RET

' multiply four 8 bit values by 2 in Rijndael's finite field
GFx2                      ' GFx2var[4] <<= 1
                          SHL      GFx2var, #1              wc        ' multiply by two, save 8th bit of MSbyte
                          AND      GFx2var, #$100           wz,nr     ' test 8th bit of LSbyte
            if_nz         XOR      GFx2var, #$11B                     ' reduce / modulus
                          AND      GFx2var, L10000          wz,nr     ' repeat for each byte
            if_nz         XOR      GFx2var, L11B00           
                          AND      GFx2var, L1000000        wz,nr
            if_nz         XOR      GFx2var, L11B0000
            if_c          XOR      GFx2var, L1B000000                 ' reduce MSbyte
GFX2_ret                  RET

' constants
D1                        LONG     1<<9                               ' increment destination register number
D3                        LONG     3<<9
D5                        LONG     5<<9
L10000                    LONG     $00010000                          ' GFx2 masks and divisors
L11B00                    LONG     $00011B00
L1000000                  LONG     $01000000
L11B0000                  LONG     $011B0000
L1B000000                 LONG     $1B000000
' SPIN variables
SBoxPtr                   LONG     -1
ISBoxPtr                  LONG     -1
' encoding data (test data from FIPS 197)
'Data                     BYTE     $32, $43, $f6, $a8, $88, $5a, $30, $8d, $31, $31, $98, $a2, $e0, $37, $07, $34
'Key                      BYTE     $2b, $7e, $15, $16, $28, $ae, $d2, $a6, $ab, $f7, $15, $88, $09, $cf, $4f, $3c
Data                      BYTE     $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $aa, $bb, $cc, $dd, $ee, $ff
Key                       BYTE     $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
RoundKeys                 RES      40                                 ' RoundKeys must follow Key
' state storage
ostate                    RES      4                                  ' istate must follow ostate
istate                    RES      4
' general purpose variables, Subroutine variables & I/O
RoundNum                  RES      1
GFx2var                   RES      1
SBout                     RES      1
in                        RES      1
out                       RES      1
loop1                     RES      1
loop2                     RES      1

SBox                      BYTE     $63, $7c, $77, $7b, $f2, $6b, $6f, $c5, $30, $01, $67, $2b, $fe, $d7, $ab, $76
                          BYTE     $ca, $82, $c9, $7d, $fa, $59, $47, $f0, $ad, $d4, $a2, $af, $9c, $a4, $72, $c0
                          BYTE     $b7, $fd, $93, $26, $36, $3f, $f7, $cc, $34, $a5, $e5, $f1, $71, $d8, $31, $15
                          BYTE     $04, $c7, $23, $c3, $18, $96, $05, $9a, $07, $12, $80, $e2, $eb, $27, $b2, $75
                          BYTE     $09, $83, $2c, $1a, $1b, $6e, $5a, $a0, $52, $3b, $d6, $b3, $29, $e3, $2f, $84
                          BYTE     $53, $d1, $00, $ed, $20, $fc, $b1, $5b, $6a, $cb, $be, $39, $4a, $4c, $58, $cf
                          BYTE     $d0, $ef, $aa, $fb, $43, $4d, $33, $85, $45, $f9, $02, $7f, $50, $3c, $9f, $a8
                          BYTE     $51, $a3, $40, $8f, $92, $9d, $38, $f5, $bc, $b6, $da, $21, $10, $ff, $f3, $d2
                          BYTE     $cd, $0c, $13, $ec, $5f, $97, $44, $17, $c4, $a7, $7e, $3d, $64, $5d, $19, $73
                          BYTE     $60, $81, $4f, $dc, $22, $2a, $90, $88, $46, $ee, $b8, $14, $de, $5e, $0b, $db
                          BYTE     $e0, $32, $3a, $0a, $49, $06, $24, $5c, $c2, $d3, $ac, $62, $91, $95, $e4, $79
                          BYTE     $e7, $c8, $37, $6d, $8d, $d5, $4e, $a9, $6c, $56, $f4, $ea, $65, $7a, $ae, $08
                          BYTE     $ba, $78, $25, $2e, $1c, $a6, $b4, $c6, $e8, $dd, $74, $1f, $4b, $bd, $8b, $8a
                          BYTE     $70, $3e, $b5, $66, $48, $03, $f6, $0e, $61, $35, $57, $b9, $86, $c1, $1d, $9e
                          BYTE     $e1, $f8, $98, $11, $69, $d9, $8e, $94, $9b, $1e, $87, $e9, $ce, $55, $28, $df
                          BYTE     $8c, $a1, $89, $0d, $bf, $e6, $42, $68, $41, $99, $2d, $0f, $b0, $54, $bb, $16

InvSBox                   BYTE     $52, $09, $6a, $d5, $30, $36, $a5, $38, $bf, $40, $a3, $9e, $81, $f3, $d7, $fb
                          BYTE     $7c, $e3, $39, $82, $9b, $2f, $ff, $87, $34, $8e, $43, $44, $c4, $de, $e9, $cb
                          BYTE     $54, $7b, $94, $32, $a6, $c2, $23, $3d, $ee, $4c, $95, $0b, $42, $fa, $c3, $4e
                          BYTE     $08, $2e, $a1, $66, $28, $d9, $24, $b2, $76, $5b, $a2, $49, $6d, $8b, $d1, $25
                          BYTE     $72, $f8, $f6, $64, $86, $68, $98, $16, $d4, $a4, $5c, $cc, $5d, $65, $b6, $92
                          BYTE     $6c, $70, $48, $50, $fd, $ed, $b9, $da, $5e, $15, $46, $57, $a7, $8d, $9d, $84
                          BYTE     $90, $d8, $ab, $00, $8c, $bc, $d3, $0a, $f7, $e4, $58, $05, $b8, $b3, $45, $06
                          BYTE     $d0, $2c, $1e, $8f, $ca, $3f, $0f, $02, $c1, $af, $bd, $03, $01, $13, $8a, $6b
                          BYTE     $3a, $91, $11, $41, $4f, $67, $dc, $ea, $97, $f2, $cf, $ce, $f0, $b4, $e6, $73
                          BYTE     $96, $ac, $74, $22, $e7, $ad, $35, $85, $e2, $f9, $37, $e8, $1c, $75, $df, $6e
                          BYTE     $47, $f1, $1a, $71, $1d, $29, $c5, $89, $6f, $b7, $62, $0e, $aa, $18, $be, $1b
                          BYTE     $fc, $56, $3e, $4b, $c6, $d2, $79, $20, $9a, $db, $c0, $fe, $78, $cd, $5a, $f4
                          BYTE     $1f, $dd, $a8, $33, $88, $07, $c7, $31, $b1, $12, $10, $59, $27, $80, $ec, $5f
                          BYTE     $60, $51, $7f, $a9, $19, $b5, $4a, $0d, $2d, $e5, $7a, $9f, $93, $c9, $9c, $ef
                          BYTE     $a0, $e0, $3b, $4d, $ae, $2a, $f5, $b0, $c8, $eb, $bb, $3c, $83, $53, $99, $61
                          BYTE     $17, $2b, $04, $7e, $ba, $77, $d6, $26, $e1, $69, $14, $63, $55, $21, $0c, $7d
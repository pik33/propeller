{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 SNEcog - SN76489 emulator V0.6 (C) 2011 by Johannes Ahlebrand                                │
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
CON PAL = 3_579_545.0, NTSC = 3_546_893.0
  
  PSG_FREQUENCY     = PAL   ' Clock frequency input on the emulated SN chip
  VOLUME_CORRECTION = 0.9   ' Volume correction value (0.0 - 1.0)
    
'SMS, Genesis and Game Gear
  NOISE_TAP = %1001
  NOISE_MSB = 15

'SG-1000, OMV, SC-3000H, BBC Micro and Colecovision
'  NOISE_TAP = %11
'  NOISE_MSB = 14

'Tandy 1000
'  NOISE_TAP = %10001
'  NOISE_MSB = 14
 
CON

 ' WARNING !!  Don't alter the constants below unless you know what you are doing

  SAMPLE_RATE           = 176_400 ' (4 x CD quality)           ' Sample rate of SNEcog (176 kHz is maximum for an 80 Mhz propeller)
  OSC_FREQ_CALIBRATION  = trunc(1.50 * PSG_FREQUENCY)          ' Calibration of the oscillator frequency
  MAX_AMPLITUDE         = float(POSX / 4)                      ' maxInt32value / numberOfChannels (this makes room for maximum "swing" on all channels) 
  AMPLITUDE_DAMP_FACTOR = 0.7941                               ' This gives a 2db drop per amplitude level (like the real thing)

  AMPLITUDE_LEVEL_0 = MAX_AMPLITUDE     * VOLUME_CORRECTION
  AMPLITUDE_LEVEL_1 = AMPLITUDE_LEVEL_0 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_2 = AMPLITUDE_LEVEL_1 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_3 = AMPLITUDE_LEVEL_2 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_4 = AMPLITUDE_LEVEL_3 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_5 = AMPLITUDE_LEVEL_4 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_6 = AMPLITUDE_LEVEL_5 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_7 = AMPLITUDE_LEVEL_6 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_8 = AMPLITUDE_LEVEL_7 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_9 = AMPLITUDE_LEVEL_8 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_A = AMPLITUDE_LEVEL_9 * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_B = AMPLITUDE_LEVEL_A * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_C = AMPLITUDE_LEVEL_B * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_D = AMPLITUDE_LEVEL_C * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_E = AMPLITUDE_LEVEL_D * AMPLITUDE_DAMP_FACTOR
  AMPLITUDE_LEVEL_F = 0.0
 
PUB start(right, left, useShadowRegisters)
' ┌──────────────────────────────────────────────────────────────┐
' │                Starts SNEcog in a single cog                 │
' ├──────────────────────────────────────────────────────────────┤
' │ Returns a pointer to the first SN register in hub memory     │
' │ on success; otherwise returns 0.                             │
' │                                                              │ 
' │ right - The pin to output the right channel to. 0 = Not used │
' │                                                              │
' │ left - The pin to output the left channel to. 0 = Not used   │
' ├──────────────────────────────────────────────────────────────┤  
' │NOTE!! The "Shadow registers" are latched register values!!   │
' │You need to call "flipRegisters" to update the real registers │
' │(This was originally implemented to make "vgm's" sound right) │   
' └──────────────────────────────────────────────────────────────┘

  if useShadowRegisters
    writeRegister_p := @shadowRegisters
  else
    writeRegister_p := @SNregisters
  
  arg1 := $18000000 | left
  arg2 := $18000000 | right
  res1 := ((1<<right) | (1<<left))&!1
  sampleRate := clkfreq/SAMPLE_RATE
  cog := cognew(@SNEMU, @SNregisters) + 1

  resetRegisters
  
  if cog
    return @SNregisters                                     
  else
    return 0

PUB stop
' ┌──────────────────────────────────────────────────────────────┐
' │                         Stops SNEcog                         │
' └──────────────────────────────────────────────────────────────┘
  if cog
    cogstop(cog~ -1)
    cog := 0
    
PUB setRegister(data) 
  if data&128
    reg := (data >> 4)&%111   
    word[writeRegister_p + (reg << 1)] := data&%1111
  else
    word[writeRegister_p + (reg << 1)] |= ((data&%111111) << 4) 

  if reg == 6              ' | This is ONLY needed to make the "shadow registers" work properly with "noise reset"
    noiseReset := true     ' | and is NOT needed if writing directly to the normal registers
                           ' | Feel free to remove these lines if that's the case     
    
PUB flipRegisters
' ┌──────────────────────────────────────────────────────────────┐
' │Writes all the values from the shadow regs to the normal regs │
' ├──────────────────────────────────────────────────────────────┤  
' │NOTE!! This method is ONLY needed when shadow registers are   │
' │used                                                          │ 
' └──────────────────────────────────────────────────────────────┘
   if noiseReset                        
     word[writeRegister_p + 12] &= 255  
     noiseReset := false                
   else                                  
     word[writeRegister_p + 12] |= 256   
          
   updateRegisters(writeRegister_p)
   
PUB updateRegisters(source)
' ┌──────────────────────────────────────────────────────────────┐
' │                  Update all 8 SN registers                   │
' ├──────────────────────────────────────────────────────────────┤
' │ source - A pointer to an array containing 16 bytes to update │
' │          the 8 SN registers with.                            │
' └──────────────────────────────────────────────────────────────┘
  longmove(@SNregisters, source, 4)

PUB resetRegisters
' ┌──────────────────────────────────────────────────────────────┐
' │                   Reset all 8 SN registers                   │
' └──────────────────────────────────────────────────────────────┘
  longfill(@SNregisters, -1, 4)

PUB setFreq(channel, frequency) | addr
' ┌──────────────────────────────────────────────────────────────┐
' │             Sets the frequency of a SN channel               │
' ├──────────────────────────────────────────────────────────────┤
' │ channel - The SN channel to set (0 - 3)                      │
' │                                                              │
' │ frequency - The 10bit frequency value (0 - 1023)             │
' └──────────────────────────────────────────────────────────────┘
  word[writeRegister_p + (channel << 2)][0] := frequency  

PUB setVolume(channel, frequency) 
' ┌──────────────────────────────────────────────────────────────┐
' │             Sets the frequency of a SN channel               │
' ├──────────────────────────────────────────────────────────────┤
' │ channel - The SN channel to set (0 - 3)                      │
' │                                                              │
' │ frequency - The 10bit frequency value (0 - 1023)             │
' └──────────────────────────────────────────────────────────────┘
  word[writeRegister_p + (channel << 2)][1] := frequency  
    
PUB play(channel, frequency, volumeLevel) | addr
' ┌──────────────────────────────────────────────────────────────┐
' │           Sets the attributes of an SN channel               │
' ├──────────────────────────────────────────────────────────────┤
' │ channel - The SN channel to set (0 - 3)                      │
' │                                                              │
' │ frequency - The 10bit frequency value (0 - 1023)             │
' │                                                              │
' │ volumeLevel - A value betwen 0 and 15 (lo value = hi volume) │ 
' ├──────────────────────────────────────────────────────────────┤ 
' │ NOTE!! Channel 0 - 2 are square waves and channel 3 is noise │ 
' ├──────────────────────────────────────────────────────────────┤ 
' │ NOTE!! The noise channel has got a 2bit freq value (0 - 3)   │ 
' │ Setting the noise freq to %X11 enables channel 2's frequency │ 
' │ register to operate the noise channel frequency.             │ 
' │ By setting the third freq bit high/low, a white or periodic  │
' │ noise can be selected. (High = White, Low = Periodic)        │
' └──────────────────────────────────────────────────────────────┘
  addr := writeRegister_p + (channel << 2)
  word[addr][0] := frequency  
  word[addr][1] := volumeLevel

dat org 0
'
'                Assembly SN emulator
'
SNEMU         mov      SN_Address, par                      ' Init
              mov      dira, res1
              mov      ctra, arg1
              mov      ctrb, arg2
              mov      waitCounter, cnt
              add      waitCounter, sampleRate
              
mainLoop      call     #getRegisters                        ' Main loop
              call     #SN                                  
              call     #mixer
              jmp      #mainLoop
              
'
' Read all SN registers from hub memory and convert
' them to more convenient representations.
'
getRegisters  mov       tempValue, SN_Address
              rdword    frequency1, tempValue               ' reg 0
              and       frequency1, mask10bit
              add       tempValue, #2                
              rdword    amplitude1, tempValue               ' reg 1
              shl       frequency1, #22
              add       tempValue, #2 
              rdword    frequency2, tempValue               ' reg 2
              and       frequency2, mask10bit
              add       tempValue, #2                
              rdword    amplitude2, tempValue               ' reg 3
              shl       frequency2, #22  
              add       tempValue, #2 
              rdword    frequency3, tempValue               ' reg 4
              and       frequency3, mask10bit
              add       tempValue, #2                
              rdword    amplitude3, tempValue               ' reg 5
              shl       frequency3, #22   
              add       tempValue, #2 
              rdword    noiseFreq, tempValue                ' reg 6
              mov       noiseFeedback, noiseFreq               
              or        noiseFreq, #256
              wrword    noiseFreq, tempValue                ' Write back reg 6, with bit 8 set, to handle "noise reset"
              and       noiseFreq, #3    
              add       tempValue, #2                
              rdword    amplitudeN, tempValue               ' reg 7
              cmp       noiseFreq, #3                    wz '|
        if_nz add       noiseFreq, #1                       '|
        if_nz shl       noiseFreq, #26                      '| These 4 lines handles selection of "external" noise frequency on/off  
        if_z  mov       noiseFreq, frequency3               '|
getRegisters_ret ret

'
SN'                  Calculate SN samples
'
AmpN          mov      arg1, amplitudeN
              call     #getAmplitude
              test     noiseFeedback, #256               wz ' If bit 8 is zero; Reset noise register
  if_z        mov      noiseValue, #1
Noise1        sub      oscCounterN, noiseSubValue        wc ' Noise generator
  if_nc       jmp      #Amp1
              add      oscCounterN, noiseFreq
'─────────────────────────────────────────────────────────── 
              test     noiseFeedback, #4                 wz ' Is it periodic or white noise ?
  if_nz       test     noiseValue, noiseTap              wc ' C = White noise !
  if_z        test     noiseValue, #1                    wc ' C = Periodic noise !
              muxc     noiseValue, noiseMSB                
              shr      noiseValue, #1                    wc
              negnc    outN, res1 
'───────────────────────────────────────────────────────────
Amp1          mov      arg1, amplitude1
              call     #getAmplitude
Square1       sub      oscCounter1, oscSubValue          wc ' Square wave generator 1
  if_c        add      oscCounter1, frequency1                
  if_c        xor      oscState1, #1                     wz
  if_c        negz     out1, res1                                
'─────────────────────────────────────────────────────────── 
Amp2          mov      arg1, amplitude2
              call     #getAmplitude
Square2       sub      oscCounter2, oscSubValue          wc ' Square wave generator 2
  if_c        add      oscCounter2, frequency2               
  if_c        xor      oscState2, #1                     wz
  if_c        negz     out2, res1    
'───────────────────────────────────────────────────────────              
Amp3          mov      arg1, amplitude3
              call     #getAmplitude
Square3       sub      oscCounter3, oscSubValue          wc ' Square wave generator 3
  if_c        add      oscCounter3, frequency3              
  if_c        xor      oscState3, #1                     wz
  if_c        negz     out3, res1
SN_ret        ret

' 
'      Mix channels and update FRQA/FRQB PWM-values
'
mixer         mov      tempValue, val31bit                  ' <- DC offset  
              add      tempValue, outN                      ' |
              add      tempValue, out1                      ' | Mix the signed samples 
              add      tempValue, out2                      ' |
              add      tempValue, out3                      ' |
              waitcnt  waitCounter, sampleRate              ' Wait until the right time to update
              mov      FRQA, tempValue                      ' the PWM values in FRQA/FRQB
              mov      FRQB, tempValue                       
mixer_ret     ret

' 
'    Get amplitude value  r1 = amplitudTable[arg1] 
'
getAmplitude  and      arg1, #15
              add      arg1, #amplitudeTable             
              movs     :indexed, arg1                  
              nop
:indexed      mov      res1, 0
getAmplitude_ret ret

' 
'    Variables, tables, masks and reference values
'  
amplitudeTable      long trunc(AMPLITUDE_LEVEL_0)
                    long trunc(AMPLITUDE_LEVEL_1)
                    long trunc(AMPLITUDE_LEVEL_2)
                    long trunc(AMPLITUDE_LEVEL_3)
                    long trunc(AMPLITUDE_LEVEL_4)
                    long trunc(AMPLITUDE_LEVEL_5)
                    long trunc(AMPLITUDE_LEVEL_6)
                    long trunc(AMPLITUDE_LEVEL_7)
                    long trunc(AMPLITUDE_LEVEL_8)
                    long trunc(AMPLITUDE_LEVEL_9)
                    long trunc(AMPLITUDE_LEVEL_A)
                    long trunc(AMPLITUDE_LEVEL_B)
                    long trunc(AMPLITUDE_LEVEL_C)
                    long trunc(AMPLITUDE_LEVEL_D)
                    long trunc(AMPLITUDE_LEVEL_E)
                    long trunc(AMPLITUDE_LEVEL_F)
 
arg1                long 0
arg2                long 0
res1                long 0
mask10bit           long $3ff
val31bit            long $80000000
sampleRate          long 0

noiseMSB            long 1 <<(NOISE_MSB + 1)
noiseValue          long 1 << NOISE_MSB
noiseTap            long NOISE_TAP
oscSubValue         long OSC_FREQ_CALIBRATION
noiseSubValue       long OSC_FREQ_CALIBRATION >> 1
oscState1           long 1
oscState2           long 1
oscState3           long 1
oscStateN           long 1
oscCounter1         res  1
oscCounter2         res  1
oscCounter3         res  1
oscCounterN         res  1
amplitude1          res  1
amplitude2          res  1
amplitude3          res  1
amplitudeN          res  1
frequency1          res  1
frequency2          res  1
frequency3          res  1
noiseFreq           res  1
noiseFeedback       res  1
sampleOut           res  1
out1                res  1
out2                res  1
out3                res  1
outN                res  1
waitCounter         res  1
tempValue           res  1
SN_Address          res  1 
                    fit

VAR
  
  byte noiseReset
  byte cog
  long reg  
  long writeRegister_p  
  long SNregisters[4]      '(= 8 word registers) 
  long shadowRegisters[4]  '(= 8 word registers)


  
' SN76489 registers
' -----------------
 
' Reg bits function
' -----------------------------------
' 00  9..0 channel 1 freq
' 01  3..0 channel 1 attunation
' 02  9..0 channel 2 freq
' 03  3..0 channel 2 attunation
' 04  9..0 channel 3 freq
' 05  3..0 channel 3 attunation
' 06  4..0 noise control
' 07  7..0 noise attunation
''**************************************
''
''  uOLED-96-PROP Display Driver, 8 bit Ver. 00.5
''
''  Timothy D. Swieter, E.I.
''  www.brilldea.com
''
''  Copyright (c) 2008 Timothy D. Swieter, E.I.
''  See end of file for terms of use. 
''
''  Updated: March 18, 2008
''
''Description:
''This program is for the 4D Systems uOLED-96-Prop.  This
''is an ASM display driver for clock 8-bit per pixel data
''to the 96x64 display
''
''Data is sent from the Propeller to the uOLED by an 8-bit
''wide data bus.  This driver is capable of 256 colors (RRRGGGBB).
''
''There is a method to find out how long a frame is taking to
''clock out.  This routine, with the stat calculation runs about
''6 ms to update the OLED memory (~166 FPS!)
''
''Reference:
''      uOLED-96-PROP_Users_Manual_Rev1.1.pdf by 4D Systems
''      uOLED-96-PROP_V4.spin (driver written by 4D Systems)
''      Solomon Systech SSD1331 datasheet (SSD1331.pdf)
''      Game Programming for the Propeller Powered Hydra by Andre LaMothe
''
''Revision Notes:
'' 0.1 Begin coding
'' 0.4 ASM coding of the driver, added commands to be sent via ASM
'' 0.5 Optimized driver to clock out an entire long once pulled from memory (4 pixels at a time instead of 1)
''     added the frameStat method
''
''TO DO:
'' - add config hooks for pixel count width and height
'' - add a way to use the driver stand alone (always sending data) or only sends data when triggered
''
''
'**************************************
CON               'Constants to be located here
'***************************************
'  System Definitions      
'***************************************

  _OUTPUT       = 1             'Sets pin to output in DIRA register
  _INPUT        = 0             'Sets pin to input in DIRA register  
  _HIGH         = 1             'High=ON=1=3.3v DC
  _ON           = 1
  _LOW          = 0             'Low=OFF=0=0v DC
  _OFF          = 0
  _ENABLE       = 1             'Enable (turn on) function/mode
  _DISABLE      = 0             'Disable (turn off) function/mode

'***************************************
'  uOLED Interface to Propeller      
'***************************************

' _OLED_Data    = 7..0          'OLED Data lines (This line is here for reference, not for code)
  _OLED_CS      = 8             'OLED chip select (low = select)
  _OLED_RESET   = 9             'OLED reset (low = reset)
  _OLED_DorC    = 10            'OLED data or command select (low = command, high = data)
  _OLED_WR      = 11            'OLED write             
  _OLED_RD      = 12            'OLED read
  _OLED_VCCE    = 13            'OLED VCC enable

'***************************************
'  SSD1331 Register Definitions      
'***************************************
  _SET_COLUMN_ADDRESS   =       $15
  _SET_ROW_ADDRESS      =       $75
  _SET_CONTRAST_RED     =       $81
  _SET_CONTRAST_GREEN   =       $82
  _SET_CONTRAST_BLUE    =       $83
  _SET_CONTRAST_MASTER  =       $87
  _CONTRAST_RED_2ND     =       $8A
  _CONTRAST_GREEN_2ND   =       $8B
  _CONTRAST_BLUE_2ND    =       $8C
  _REMAP_COLOUR_SETTINGS=       $A0
  _DISPLAY_START_LINE   =       $A1
  _DISPLAY_OFFSET       =       $A2
  _DISPLAY_NORMAL       =       $A4
  _DISPLAY_ALL_ON       =       $A5
  _DISPLAY_ALL_OFF      =       $A6
  _DISPLAY_INVERSE      =       $A7
  _MUX_RATIO            =       $A8
  _MASTER_CONFIGURE     =       $AD
  _DISPLAY_OFF          =       $AE
  _DISPLAY_ON           =       $AF
  _POWERSAVE_MODE       =       $B0
  _PHASE_PRECHARGE      =       $B1
  _CLOCK_FREQUENCY      =       $B3
  _SET_GRAYSCALE        =       $B8
  _RESET_GRAYSCALE      =       $B9
  _PRECHARGE_RGB        =       $BB
  _SET_VCOMH            =       $BE
  _NOP                  =       $E3
  _LOCK_COMMAND         =       $FD

  _DRAW_LINE            =       $21
  _DRAW_RECTANGLE       =       $22
  _COPY_AREA            =       $23
  _DIM_WINDOW           =       $24
  _CLEAR_WINDOW         =       $25
  _FILL_ENABLE_DISABLE  =       $26
  _SCROLL_SETUP         =       $27
  _STOP_SCROLL          =       $2E
  _START_SCROLL         =       $2F

  _256_COLOURS          =       $32                     '%0100_0000
  _65K_COLOURS          =       $72                     '%0100_1000


'**************************************
VAR               'Variables to be located here
'**************************************

  'Processor
  long OLED_cog                 'Cog flag/ID

  'The next 4 variables are read into the ASM routine, passed by pointer
  long MemDispPtr               'A pointer to the beginning of the bitmap screen in HUB RAM
  long CSpin                    'Pin number - so pin can be used in new cog
  long DorCpin                  'Pin number - so pin can be used in new cog
  long WRpin                    'Pin number - so pin can be used in new cog
  long RESpin                   'Pin number - so pin can be used in new cog
  long VCCEpin                  'Pin number - so pin can be used in new cog
  long RDpin                    'Pin number - so pin can be used in new cog
  long FrameTime                'Variable holding time of last frame update

  
'**************************************
OBJ               'Object declaration to be located here
'**************************************

  'None
  
'**************************************
PUB start(_MemDisp) : okay
'**************************************
'' Start the ASM display driver after doing a Spin initialize
'' Setup I/O pins, initiate variables, starts a cog
'' returns cog ID (1-8) if good or 0 if no good

  stop                                                  'Keeps two cogs from running at the same time

  'Initilize Variables
  MemDispPtr := _MemDisp                                'Copy pointer passed from main program
  CSpin := _OLED_CS                                     'Store I/Os in variables for ASM to access
  DorCpin := _OLED_DorC
  WRpin := _OLED_WR
  RESpin := _OLED_RESET
  VCCEpin := _OLED_VCCE
  RDpin := _OLED_RD

  'Start a cog with assembly routine
  okay:= OLED_cog:= cognew(@ENTRY, @MemDispPtr) + 1     'Returns 0-8 depending on success/failure

  
'**************************************
PUB stop
'**************************************
'' Stops ASM display driver - frees a cog

  if OLED_cog                                           'Is cog non-zero?

  'Initialize I/O
    dira[7..0] := $FF                                   'Set data as outputs, 8-bits wide
    dira[_OLED_CS] := _OUTPUT                           'Set cs as output
    dira[_OLED_RESET] := _OUTPUT                        'Set reset as output
    dira[_OLED_DorC] := _OUTPUT                         'Set DorC as output
    dira[_OLED_WR] := _OUTPUT                           'Set write as output
    dira[_OLED_VCCE] := _OUTPUT                         'Set VCCE as output

    outa[_OLED_DorC] := _HIGH                           'Set the pins high (keeps ASM from being able to control the OLED
    outa[_OLED_RD] := _HIGH
    outa[_OLED_WR] := _HIGH
    outa[_OLED_CS] := _HIGH
    outa[_OLED_VCCE] := _HIGH

    cogstop(OLED_cog~ - 1)                              'Stop the cog and then make value of flag zero
    powerDown                                           'Perform a power down sequence in Spin

  'Release I/O
    dira[7..0] := $00                                   'Set data as inputs
    dira[_OLED_CS] := _INPUT                            'Set cs as input
    dira[_OLED_RESET] := _INPUT                         'Set reset as input
    dira[_OLED_DorC] := _INPUT                          'Set DorC as input
    dira[_OLED_WR] := _INPUT                            'Set write as input
    dira[_OLED_VCCE] := _INPUT                          'Set VCCE as input

    outa[_OLED_DorC] := _LOW                            'Set the pins low
    outa[_OLED_RD] := _LOW
    outa[_OLED_WR] := _LOW
    outa[_OLED_CS] := _LOW
    outa[_OLED_VCCE] := _LOW


'**************************************
PUB frameStat : value
'**************************************
'' Returns the time (ms) that it took to paint the last screen to the OLED memory

  value := FrameTime/(clkfreq/1_000)


'**************************************
PRI powerDown
'**************************************
'' Power down of OLED display based on datasheet

  writeCMD(_DISPLAY_OFF)                                'Send the display off command
  outa[_OLED_VCCE] := _OFF                              'Turn off the OLED VCC voltage
  pauseMSec(100)                                        'Observe a waiting period before next action


'**************************************
PRI writeCMD (cmd)
'**************************************
'' Send a one byte command to OLED Display

  outa[_OLED_DorC] := _LOW                              'Set line for command
  outa[_OLED_CS] := _LOW                                'Select the OLED display
  outa[_OLED_WR] := _LOW                                'Prepare to write to the register
  outa[7..0] := cmd.byte[0]                             'Send the 8-bit data
  outa[_OLED_WR] := _HIGH                               'Latch in the command
  outa[_OLED_CS] := _HIGH                               'Deselect OLED display  
  outa[_OLED_DorC] := _HIGH                             'Restore state - data


'**************************************
PRI pauseMSec(Duration)
'**************************************
'' Pause execution in milliseconds.
'' Duration = number of milliseconds to delay
  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)


'**************************************
DAT
'**************************************
' Assembly Language display driver for uOLED-96-PROP
' copy HUB RAM bit-mapped memory to OLED Graphics RAM
'
                        org
'
'Start of routine
ENTRY                   mov t0, par                     'Load address of parameter list into t1 (par contains address)

                        rdlong memptr, t0               'Read value of dispMemptr from main memory

                        add t0, #4                      'Increament address pointer by four bytes      
                        rdlong CSp, t0                  'Read value of CSpin from main memory
                        mov CSmask, #1                  'Load mask with a 1          
                        shl CSmask, CSp                 'Create mask for the proper I/O pin by shifting

                        add t0, #4                      'Increament address pointer by four bytes
                        rdlong DorCp, t0                'Read value of DorCpin from main memory
                        mov DorCmask, #1                'Load mask with a 1          
                        shl DorCmask, DorCp             'Create mask for the proper I/O pin by shifting
                        
                        add t0, #4                      'Increament address pointer by four bytes
                        rdlong WRp, t0                  'Read value of WRpin from main memory
                        mov WRmask, #1                  'Load mask with a 1          
                        shl WRmask, WRp                 'Create mask for the proper I/O pin by shifting

                        add t0, #4                      'Increament address pointer by four bytes
                        rdlong RESp, t0                 'Read value of RESpin from main memory
                        mov RESmask, #1                 'Load mask with a 1          
                        shl RESmask, RESp               'Create mask for the proper I/O pin by shifting

                        add t0, #4                      'Increament address pointer by four bytes
                        rdlong VCEp, t0                 'Read value of VCCEpin from main memory
                        mov VCEmask, #1                 'Load mask with a 1          
                        shl VCEmask, VCEp               'Create mask for the proper I/O pin by shifting

                        add t0, #4                      'Increament address pointer by four bytes
                        rdlong RDp, t0                  'Read value of RDpin from main memory
                        mov RDmask, #1                  'Load mask with a 1          
                        shl RDmask, RDp                 'Create mask for the proper I/O pin by shifting

                        add t0, #4                      'Increament address pointer by four bytes
                        mov FrmTm, t0                   'Move pointer value for the Frame Per Second measurement

                        mov t1, #0                      'Initialize t1 (ensure it is zero)
                        or t1, CSmask                   'Create a composite mask for all pins (or them into t1)
                        or t1, DorCmask                 '
                        or t1, WRmask                   '
                        or t1, RESmask                  '
                        or t1, VCEmask                  '
                        or t1, RDmask                   '
                        or t1, #$ff                     'Data lines on pins 0..7
                        mov dira, t1                    'Set CS, DorC, WR, RES, VCCE and data as outputs

                        or outa, CSmask                 'Set the CSpin high
                        or outa, DorCmask               'Set the DorCpin high
                        or outa, WRmask                 'Set the WRpin high
                        or outa, RDmask                 'Set the WRpin high
                        andn outa, RESmask              'Set the RESpin low
                        andn outa, VCEmask              'Set the VCEpin low

                        call #INITIALIZE                'Initialize the display

                                                        'Data sent left to right, top to bottom
ScrnStart               mov s0, cnt                     'Get the current count for statistics
                        CALL #STATCALC                  'Go calculate the statistics
                        mov rowcnt, #0                  'Reset the row counter
:row                    mov colcnt, #0                  'Reset the column counter
:col                    mov offset, colcnt              'Load the current column in offset
                        shr offset, #2                  'Divide by 4 (4 pixels wide is a tile)
                        shl offset, #6                  'Multiply by 64 (lines on the display)
                        add offset, rowcnt              'Add in the row we are working with, offset is in long
                        shl offset, #2                  'Multiply by 4, offset is now in bytes (for HUB RAM)
                        add offset, memptr              'Offset is now the entire HUB RAM address

                        rdlong t3, offset               'Get a long from HUB RAM, 4 pixels
                        mov t2, #4                      'Load the counter for four bytes per long to clock out
:bytechck               mov cdata, t3                   'Move the data over for sending
                        call #SENDDATA                  'Send the data
                        shr t3, #8                      'Shift the long from memory right by eight to get next byte
                        djnz t2, #:bytechck             'Check if there is a next byte, if so repeat
                        
                        cmp colcnt, colpixel    wz      'Test if all the columns have been written (0 to 95), but colpixel is 92 because of long clocking
              if_nz     add colcnt, #4                  'No, add another four columns (four pixels in a long
              if_nz     jmp #:col                       'No, clock out another column
                        
                                                        'Run the row test if colcnt = colpixel (all columns clocked out)
                        cmp rowcnt, rowpixel    wz      'Test if all the rows have been written (0 to 63)
              if_nz     add rowcnt, #1                  'No, add another row
              if_nz     jmp #:row                       'No, clock out another row
                        jmp #ScrnStart                  'Yes - do it all over again                                                                                      


'Routine to do the clocking of the display data
SENDDATA                or outa, DorCmask               'Ensure the data/command line is high
                        andn outa, CSmask               'Ensure the OLED display is selected by putting line low
                        andn outa, WRmask               'set the write line low
                        andn outa, #$FF                 'Clear the data on the output lines
                        and cdata, #$FF
                        or outa, cdata                  'Set the data on the output lines
                        or outa, WRmask                 'Latch in the write                        
SENDDATA_ret            ret                             'Return to calling program

'Routine to do the clocking of the display command
SENDCMD                 andn outa, DorCmask             'Ensure the data/command line is low
                        andn outa, CSmask               'Ensure the OLED display is selected by putting line low
                        andn outa, WRmask               'set the write line low
                        andn outa, #$FF                 'Clear the command on the output lines
                        or outa, cdata                  'Set the command on the output lines
                        or outa, WRmask                 'Latch in the write                        
SENDCMD_ret             ret                             'Return to calling program

'Routine to intialize the LCD with the proper commands and parameters
'The intialization routine is based on the 4D Systems uOLED driver
INITIALIZE              'Perform line reset
                        andn outa, RESmask              'Set the reset line low (resets the display)
                        mov r0, #$1FF                   'move clock ticks into R0
                        add r0, cnt                     'add in the current clock state
                        waitcnt r0, #0                  'pause
                        or outa, RESmask                'Set the reset line high (displays starts to init)

                        'Power on VCCE
                        andn outa, VCEmask              'Set the VCCE pin low (no voltage)
                        mov cdata, DISPLAY_OFF          'Ensure the display is off via software
                        call #SENDCMD                   '
                        or outa, VCEmask                'Set the VCCE pin high (voltage)
                        mov r0, #$1FF                   'move clock ticks into R0
                        add r0, cnt                     'add in the current clock state
                        waitcnt r0, #0                  'pause

                        'Send a barrage of commands for initializing
                        mov cdata, DISPLAY_NORMAL       'Normal display
                        call #SENDCMD                   '
                        
                        mov cdata, CLOCK_FREQUENCY      'Clock & frequency
                        call #SENDCMD                   '
                        mov cdata, #$F0                 'Data for above command
                        call #SENDCMD                   '
                        
                        mov cdata, DISPLAY_OFFSET       'Set display offset
                        call #SENDCMD                   '
                        mov cdata, #$00                 'Data for above command
                        call #SENDCMD                   '
                        
                        mov cdata, MUX_RATIO            'Duty
                        call #SENDCMD                   '
                        mov cdata, #63                  'Data for above command (Yes, this is decimal)
                        call #SENDCMD                   '

                        mov cdata, MASTER_CONFIGURE     'Master Configure
                        call #SENDCMD                   '
                        mov cdata, #$8E                 'Data for above command
                        call #SENDCMD                   '
                        
                        mov cdata, DISPLAY_START_LINE   'Master Configure
                        call #SENDCMD                   '
                        mov cdata, #$00                 'Data for above command
                        call #SENDCMD                   '
   
                        mov cdata, REMAP_COLOUR_SETTINGS'Set re-map color/depth
                        call #SENDCMD                   '
                        mov cdata, COLORS256            'Data for above command
                        call #SENDCMD                   '

                        mov cdata, SET_CONTRAST_MASTER  'Set master contrast
                        call #SENDCMD                   '
                        mov cdata, #$0F                 'Data for above command
                        call #SENDCMD                   '

                        mov cdata, SET_CONTRAST_RED     'Set contrast current for A
                        call #SENDCMD                   '
                        mov cdata, #$FF                 'Data for above command
                        call #SENDCMD                   '

                        mov cdata, SET_CONTRAST_GREEN   'Set contrast current for B
                        call #SENDCMD                   '
                        mov cdata, #$FF                 'Data for above command
                        call #SENDCMD 

                        mov cdata, SET_CONTRAST_BLUE    'Set contrast current for C
                        call #SENDCMD                   '
                        mov cdata, #$FF                 'Data for above command
                        call #SENDCMD
              
                        mov cdata, PRECHARGE_RGB        'Set pre-charge voltage of color A B C
                        call #SENDCMD                   '
                        mov cdata, #$3E                 'Data for above command
                        call #SENDCMD

                        mov cdata, SET_VCOMH            'Set VcomH
                        call #SENDCMD                   '
                        mov cdata, #$3E                 'Data for above command
                        call #SENDCMD

                        mov cdata, POWERSAVE_MODE       'Set power saving mode
                        call #SENDCMD                   '
                        mov cdata, #$00                 'Data for above command
                        call #SENDCMD

                        mov cdata, PHASE_PRECHARGE      'Set pre & dis charge
                        call #SENDCMD                   '
                        mov cdata, #$11                 'Data for above command
                        call #SENDCMD

                        mov cdata, DISPLAY_ON           'Set display on
                        call #SENDCMD                   '
                                                        'The following commands set parameters, but also ensure starting point on display
                        mov cdata, SET_COLUMN_ADDRESS   'set column address command (and moves cursor)
                        call #SENDCMD
                        mov cdata, #$00
                        call #SENDCMD
                        mov cdata, #$5F
                        call #SENDCMD
                        mov cdata, SET_ROW_ADDRESS      'set row address command (and moves cursor)
                        call #SENDCMD
                        mov cdata, #$00
                        call #SENDCMD
                        mov cdata, #$3F
                        call #SENDCMD

INITIALIZE_ret         ret                              'Return to calling program

'Routine to calculate the statistic of the driver performance
STATCALC                mov r1, s0                      'Move the start time for a frame
                        sub r1, s1                      'Subtract the start time of the previous frame (includes stat calc)
                        wrlong r1, FrmTm                'Write the value to the HUB RAM

                        mov s1, s0                      'Store the latest frame start time to the previous start time

STATCALC_ret            ret                             'Return to calling program

                        
'Initialized Data
colpixel                long 92                 'zero based, OLED is 96 x 64, but because of column count by four, this is 92
rowpixel                long 63                 'zero based

'Initalized Commands for SSD1331
SET_COLUMN_ADDRESS      long $15
SET_ROW_ADDRESS         long $75
SET_CONTRAST_RED        long $81
SET_CONTRAST_GREEN      long $82
SET_CONTRAST_BLUE       long $83
SET_CONTRAST_MASTER     long $87
CONTRAST_RED_2ND        long $8A
CONTRAST_GREEN_2ND      long $8B
CONTRAST_BLUE_2ND       long $8C
REMAP_COLOUR_SETTINGS   long $A0
DISPLAY_START_LINE      long $A1
DISPLAY_OFFSET          long $A2
DISPLAY_NORMAL          long $A4
DISPLAY_ALL_ON          long $A5
DISPLAY_ALL_OFF         long $A6
DISPLAY_INVERSE         long $A7
MUX_RATIO               long $A8
MASTER_CONFIGURE        long $AD
DISPLAY_OFF             long $AE
DISPLAY_ON              long $AF
POWERSAVE_MODE          long $B0
PHASE_PRECHARGE         long $B1
CLOCK_FREQUENCY         long $B3
SET_GRAYSCALE           long $B8
RESET_GRAYSCALE         long $B9
PRECHARGE_RGB           long $BB
SET_VCOMH               long $BE
NNOP                    long $E3
LOCK_COMMAND            long $FD

COLORS256               long $32                '256 colors, 8bit (%RRR_GGG_BB)
COLORS65K               long $72

'Uninitialized Data
t0            res 1                             'temporary variable 0
t1            res 1                             'temporary variable 1
t2            res 1                             'temporary variable 2
t3            res 1                             'temporary variable 3

r0            res 1                             'temporary variable for use in subroutines
r1            res 1                             'temporary variable for use in subroutines

s0            res 1                             'temporary for statistics
s1            res 1                             'temporary for statistics                             

CSp           res 1                             'Value of pin assignment
CSmask        res 1                             'Mask of pin assignment
DorCp         res 1                             'Value of pin assignment
DorCmask      res 1                             'Mask of pin assignmenr          
WRp           res 1                             'Value of pin assignement
WRmask        res 1                             'Mask of pin assignment
RESp          res 1                             'Value of pin assignment
RESmask       res 1                             'Mask of pin assignment
VCEp          res 1                             'Value of pin assignment
VCEmask       res 1                             'Mask of pin assignment
RDp           res 1                             'Value of pin assignment
RDmask        res 1                             'Mask of pin assignment

rowcnt        res 1                             'Counter of rows for processing
colcnt        res 1                             'Counter of columns for processing
pxmask        res 1                             'Mask of pixel to process
offset        res 1                             'Offset for use with memptr to read HUB RAM
memptr        res 1                             'Pointer to HUB RAM of display memory
cdata         res 1                             'byte variable to hold color data to be sent to OLED

FrmTm         res 1                             'Pointer to FPS measurement

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
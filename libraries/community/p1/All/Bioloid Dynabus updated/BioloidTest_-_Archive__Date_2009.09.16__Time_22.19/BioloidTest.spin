'BIOLOID SERIAL EXAMPLE 1.0
'Modified HJKiela sept 09
'Further developed with Scan, Status, etc
'Based on the work of 

'Demo of 1Mbps serial R/W interface for connecting Propeller to Robotis Bioloid CM5/AX12
'Inaki Castillo Jan-2007

'OBJs used:

'BIO_SEND
'BIO_RECEIVE

'OBJs used for demo purposes:

'TV_TERMINAL (c) Parallax
'TV (c) Parallax
'Graphics (c) Parallax 
'Numbers (c) Jeff Martin


'You must call RX.Start and TX.Start (in this order) with two PINs as arguments:
' The first argument is the PIN you want to use for READ(RX)/WRITE(TX)
' Note that PINs RX and TX must be wired to the bus using a 1Kto100K resistor.
' The bus must be held HIGH to 5V if you intent to act as master
' See schematics below

' The second argument is the PIN you want to use for control. it is any PIN that may be left disconnected or you can use it for an external control circuit
' This second pin must be the same for RX and TX initialization! In other case it wont work as expected.

'NOTE: 80Mhz is mandatory! I use a 5Mhz XTAL with 16X multiplier

{
 MASTER mode arrangement with DIR control pin unwired
 
     10K
+5V─────┳────┳─────────────AX12-DATA
           │    │
         1K    1K        ┌──AX12-GND
           │    │          │
           TX   RX   DIR  Vss

The POWER line at 10V can be taken out of the Bioloid battery directly although I recommend for experiment purposes to use
the CM5 brick as the power source. I have found it to be very useful to switch back to CM5 to check parameters and commands.
You will need the I/O expansion bus board(included with Bioloid Kit).
Just connect the CM5 to this board and use a Bioloid cable to attach the AX12-DATA and GND pins to Propeller side, as shown in the schematics.
You can use a genuine Bioloid type connector on the Propeller side or, if you don't have one, you may need to peel up a Bioloid cable to connect
it to the Propeller side.
Please keep ATENTION to how GND, 10V and DATA pins are arranged. Remember 10V is the center PIN!

        /│
        │  │   │   │  |
        └──┼───┼───┼──┘
           │   │   │
          GND  10V  DATA
           
}
{
TO DO STUFF:

  - Multiple COG contention for reading and writing
  - Allow Unknown length readings (for slave mode)
  - Speed up writing 
  - Flush routine of the read buffer seems to have a bug

}

CON
'Set 80Mhz
  _clkmode=xtal1+pll16x
  _xinfreq = 5000000

'' Serial port 
   CR = 13
   LF = 10
   TXD = 31
   RXD = 30
   Baud = 115200

'IMPORTANT: Initialize this constants according to your circuit
  TX_PIN = 0

'Some servos I am using for test
  AX12a = 6
  AX12b = 2
  AX12c = 4
  MaxServo = 10  

'Some useful definitions for AX12 management  
AX12_COMMAND_PING  = 1
AX12_COMMAND_READ  = 2  
AX12_COMMAND_WRITE = 3
AX12_COMMAND_REG_WRITE=4
AX12_COMMAND_ACTION=5
AX12_COMMAND_RESET=6
AX12_COMMAND_SYNC_WRITE=$83


'Dynamixel registers       Address,Length, MinValue, MaxValue, Default.
AX12_REGISTER_MODEL        = $0     '1,0,1023   ,12
AX12_REGISTER_FIRMWARE     = $2     '1,0,1023   ,0
AX12_REGISTER_RETURN_TIME  = $5     '1,0,254    ,
AX12_REGISTER_CW_ANGLE_LIMIT = $6   '2,0,1023   ,1
AX12_REGISTER_CWW_ANGLE_LIMIT = $8  '2,0,1023   ,1
AX12_REGISTER_MAX_TORQUE  = $E      '2,0,1023   ,$BEFF
AX12_REGISTER_ALARM_LED   = $11     '1,0.1      ,4
AX12_REGISTER_ALARM_SHTDN = $12     '1,0.1      ,4
AX12_REGISTER_LED = $19             '1,0.1      ,0
AX12_REGISTER_CW_MARGIN = $1A       '1,0,254    ,               
AX12_REGISTER_CCW_MARGIN= $1B       '1,0,254    ,
AX12_REGISTER_CW_SLOPE = $1C        '1,1,254    ,
AX12_REGISTER_CCW_SLOPE= $1D        '1,1,254    ,
AX12_REGISTER_GOAL_POSITION = $1E   '2,0,1023   ,
AX12_REGISTER_MOVING_SPEED = $20    '2,0,1023   ,
AX12_REGISTER_TORQUE_LIMIT  = $22   '2,0,1023   ,$3ff
AX12_REGISTER_PRESENT_POSITION = $24'2,0,1023   ,
AX12_REGISTER_PRESENT_SPEED = $26   '2,0,1023   ,
AX12_REGISTER_PRESENT_LOAD = $28    '2,0,1023   ,
AX12_REGISTER_PRESENT_VOLTAGE = $2A '1,0,255    ,
AX12_REGISTER_PRESENT_TEMP = $2B    '1,0,255    ,
AX12_REGISTER_REGISTERED_INSTR = $2c'1,0,255    ,0
AX12_REGISTER_MOVING = $2E          '1,0,1      ,
AX12_REGISTER_PUNCH = $30           '2,0,1023   ,32

AXS1_REGISTER_BUZZER_TIME = $29
AXS1_REGISTER_BUZZER_INDEX= $28
AXS1_REGISTER_DISTANCE_CENTER= $1B
AXS1_REGISTER_LIGHT_CENTER= $1E
AXS1_REGISTER_IR_REMOCON_READY= $2E 
AXS1_REGISTER_IR_REMOCON_DATA = $30

VAR
LONG b
BYTE BufReceive[16]
BYTE Pos[2]
BYTE i
BYTE a
BYTE k
BYTE CommandReceive[16]
BYTE CommandTemplate[16]
BYTE arguments[16]
Byte AXStatus[MaxServo], AXID[Maxservo], Nservo
byte  byteArray[50]


OBJ
  dBus :  "DynAsmBus"
  Ser:    "FullDuplexSerial"
  Num :   "Numbers"
  t:      "Timing"  
PUB Main  | tt, ii

'Initialize OBJs
''Serial communication Setup
  Ser.start(TXD, RXD, 0, Baud)    '' Initialize serial communication to the PC through the USB connector
'    Num.Init
    'RX.Start(RX_PIN,DIR_PIN)
    'TX.Start(TX_PIN,DIR_PIN)
  dBus.Start(TX_Pin, 1_000_000)
  t.Pause1ms(2000)
'Initialize vars 
'countReceive:=0

'Here starts the code
' ser.Str(string("Starting...",CR))
' ser.int(clkfreq/10)

  Repeat ii from 0 to Maxservo-1 'Init servo status
    AXStatus[ii]:=0
    AxID[ii]:=$FF

  PingScan     'Scan available servo's and register them
  ShowServo    'Show available servo's

 repeat
{ ser.str(string("Clk $"))
' tt := 1*(clkfreq/12 * 1000)                         ''1ms timeout
  tt := 2*(clkfreq/12/1000)                           ''1ms timeout
  ser.dec(tt)
  ser.tx(" ")
  ser.hex(tt,8)
  ser.tx(CR)         }

 ' Test_Sensor
'   TestStatus  
'Test LED
  Test_LED
   TestStatus  
'Test for reading current position; rotate the wheel with your hand while test is in progress
   Test_SetPosition
   TestStatus
  
'PING test  
  Test_PING

{  ser.str(string("Status ID, Error:"))
  ser.dec(CommandReceive[3])
  ser.tx(" ") 
  ser.bin(CommandReceive[5],8)   
  ser.tx(CR)  }
  Sleep(200)

'A simple loop of write & read of SetGoalPositionCommand
 ' Test_SetGoalPosition

 ' Sleep(200)


'--------------------------------------------------------------------------------------------
PRI Test_LED    'Blink leds

  ser.Str(string("LED test",CR))
  i:=0
  repeat while i<10
    LED(ax12a,1)
    LED(ax12b,1)
    LED(ax12c,0)
    Sleep(100)
    LED(ax12a,0)
    LED(ax12b,0)
    LED(ax12c,1)
    Sleep(100)
    i++
 { repeat 5
    LED(ax12a,0)
    LED(ax12b,0)
    LED(ax12c,0)
    Sleep(100)
    LED(ax12a,1)
    LED(ax12b,0)
    LED(ax12c,0)
    Sleep(100)
    LED(ax12a,0)
    LED(ax12b,1)
    LED(ax12c,0)
    Sleep(100)
    LED(ax12a,0)
    LED(ax12b,0)
    LED(ax12c,1)
    Sleep(100)    }

  LED(ax12c,0)

'--------------------------------------------------------------------------------------------
PRI Test_PING | ii   'Ping available servo's

 { ser.Str(string("Scan ... "))
  nServo:=PingScan  'Scan for servo's
  ser.Str(string("Found : "))
  ser.dec(nServo)   }
  ii:=0
  ser.Str(string("PING test. avl servo's :",CR))
  
  repeat while ii<nServo
    if Ping(AXID[ii])
      ser.Str(string(" Fnd: "))
      ser.dec(AXID[ii])
    else   
      ser.Str(string(" NOT Fnd: "))
      ser.dec(AXID[ii])
    ii++ 

  ser.tx(CR)

'--------------------------------------------------------------------------------------------
PRI Test_SetPosition
'A simple loop of write & read of SetGoalPositionCommand

  ser.Str(string("Setting GoalPosition",CR))
  i:=0
  TestStatus
  SetPosition(AX12b, 200,0)
' Sleep(500)
  SetPosition(AX12b, 200,0)

  SetSpeed(Ax12a,50)
  SetSpeed(Ax12b,30)
  SetSpeed(Ax12c,100)
  repeat 3
    TestStatus
    repeat until MoveReady(AX12a)
    repeat until MoveReady(AX12b)
    repeat until MoveReady(AX12b)
    SetPosition(AX12a, 400,1)
    SetPosition(AX12c, 1000,1)
    SetPosition(AX12b, 500,1)
    ser.Str(string("Pos set "))
    t.Pause1ms(1000)
    Action
    ser.Str(string("Action ",CR))
'    Sleepus(20)
'   ReadString(6,1)
  
    Sleep(500)
    repeat until MoveReady(AX12a)
    repeat until MoveReady(AX12b)
    repeat until MoveReady(AX12b)

    TestStatus 
    SetPosition(AX12a, 100,1)
    SetPosition(AX12b, 100,1)
    SetPosition(AX12c, 100,1)
    ser.Str(string("Pos set "))
    t.Pause1ms(1000)
    Action
    ser.Str(string("Action ",CR))
    
'    Sleepus(20)
'   ReadString(6,1)
    i++
    Sleep(500)


'--------------------------------------------------------------------------------------------

PRI TestStatus
'A simple loop to test status

  ser.Str(string("Get status",CR))
  i:=0
  ser.Str(string("Ax12a "))
  ser.dec(ax12a)
  ShowStatus(AX12a)
  ser.Str(string(CR,"Ax12b "))
  ser.dec(ax12b)
  ShowStatus(AX12b)
  ser.Str(string(CR,"Ax12c "))
  ser.dec(ax12c)
  ShowStatus(AX12c)

'--------------------------------------------------------------------------------------------
PRI ShowStatus(ID)| lIndex, Load, Temp, Voltage, Speed, Firmware, Model, Position 'Get servo status, temp, current, speed, position, voltage, errors, etc

  Load:=GetLoad(ID)
  Speed:=GetSpeed(ID)
  Position:=GetPosition(ID)  

  Temp:=GetTemp(ID)
  Voltage:=GetVoltage(ID)
  Firmware:=GetFirmware(ID)
  Model:=GetModel(ID)
  
  ser.str(string("Load "))
  Ser.dec (Load)
  ser.tx(" ")    
  ser.str(string("Temp "))
  Ser.dec (Temp)
  ser.tx(" ")    
  ser.str(string("Voltage "))
  Ser.dec (Voltage)
  ser.tx(" ")
  ser.str(string("Speed "))
  Ser.dec (Speed)
  ser.tx(" ")
  ser.str(string("Firmware "))
  Ser.dec (Firmware)
  ser.tx(" ")
  ser.str(string("Model "))
  Ser.dec (Model)
  ser.tx(" ")
  ser.str(string("Position "))
  Ser.dec (Position)
  lIndex:=FindIndex(ID)
  if !(lIndex==$FF)
    ser.tx(" ")
    ser.str(string("Error %"))
    Ser.bin(AXStatus[lIndex],8)

  ser.tx(CR)

'--------------------------------------------------------------------------------------------
PRI FindIndex(ID): Index | ii   'Find index for ID
  ii:=0
  Index:=$FF  'not found
  repeat while ii<NServo
    If ID==AXID[ii]
      Index:=ii
    ii++  

'--------------------------------------------------------------------------------------------
PUB PingScan | ii, jj    'Scan network for available servo's and return number of servo's found
  ii:=0
  jj:=0
  NServo:=0
' ser.str(string(CR,"Scan Servo's in network : "))
' ser.dec(255)
  repeat while ii <255
    if Ping(ii)
'      AXStatus[jj]:=1
      AXID[jj]:=ii
'     ser.dec(AXID[jj])
'     ser.tx(" ")
      jj++
      NServo++
   ii++
Return jj       'Return number of servo's found

'--------------------------------------------------------------------------------------------
PUB ShowServo |ii 'Show found servo's
  ii:=0
  ser.str(string("Servo's found # "))
  ser.dec(nServo)
  ser.str(string(" -> : "))
  repeat ii from 0 to nServo-1
    ser.dec(ii)
    ser.tx(":")
    ser.dec(AXID[ii])
    ser.tx(" ")
    
  ser.tx(CR)
    
'--------------------------------------------------------------------------------------------

PUB MoveReady(ID)| MovingR 'Check if movement finished
  Readdata(ID, AX12_REGISTER_MOVING, 1)
' bb := dBus.GetAxBuffer(6) << 8
  MovingR := dBus.GetAxBuffer(5)==0
'  ser.str(string("MoveR "))
'  Ser.dec (MovingR)
'  ser.tx(CR)
Return MovingR

'--------------------------------------------------------------------------------------------
PUB StopMove(ID): lPos 'Stop running move of selected servo
  lPos:=GetPosition(ID)
  SetPosition(ID,lPos,0)

'--------------------------------------------------------------------------------------------
PUB StopAll | ii   ' Stop motion in all servo's
  repeat ii from 0 to nServo-1
    StopMove(AXID[ii])
                    
'--------------------------------------------------------------------------------------------
PUB GetModel(ID): Model | bb        'Get model
  Readdata(ID, AX12_REGISTER_MODEL, 2)
  bb := dBus.GetAxBuffer(6) << 8
  bb := dBus.GetAxBuffer(5) '==0
  Model:=bb

'--------------------------------------------------------------------------------------------
PUB GetFirmware(ID): Firmware | bb 'Get firmware
  Readdata(ID, AX12_REGISTER_FIRMWARE, 1)
  bb := dBus.GetAxBuffer(5) '==0
  Firmware:=bb

'--------------------------------------------------------------------------------------------
PUB GetSpeed(ID): Speed | bb    'Get speed
  Readdata(ID, AX12_REGISTER_PRESENT_SPEED, 2)
  bb := dBus.GetAxBuffer(6) << 8
  bb += dBus.GetAxBuffer(5)'==0
  Speed:=bb

'--------------------------------------------------------------------------------------------
PUB GetLoad(ID): Load | bb      'Get temp
  Readdata(ID, AX12_REGISTER_PRESENT_LOAD, 2)
  bb := dBus.GetAxBuffer(6) << 8
  bb += dBus.GetAxBuffer(5) '==0
  Load:=bb

'--------------------------------------------------------------------------------------------
PUB GetTemp(ID): Temp | bb      'Get servo load
  Readdata(ID, AX12_REGISTER_PRESENT_TEMP, 1)
  bb := dBus.GetAxBuffer(5) '==0
  Temp:=bb

'--------------------------------------------------------------------------------------------
PUB GetVoltage(ID): Voltage | bb    'Get supply voltage
  Readdata(ID, AX12_REGISTER_PRESENT_VOLTAGE, 1)
  bb := dBus.GetAxBuffer(5) '==0
  Voltage:=bb

'--------------------------------------------------------------------------------------------
PUB GetPosition(ID): CurrentPos  | bb     'Get current position

  Readdata(ID, AX12_REGISTER_PRESENT_POSITION, 2)
  bb := dBus.GetAxBuffer(6) << 8
  bb += dBus.GetAxBuffer(5)
' Ser.str ((Num.toStr(b,Num#DEC4)))
  CurrentPos:=bb

'--------------------------------------------------------------------------------------------
PUB Wheel(ID,OnOff)  'Set Wheel mode on/off
 { IF OnOff==1
    arguments[0]:=AX12_COMMAND_WRITE
    arguments[1]:=AX12_REGISTER_CW_MARGIN      
    arguments[2]:=0                       'cw 0
    ComposeBioloidCommand(ID, 8-4, @arguments ,@CommandTemplate)
    TX.tx_string(@CommandTemplate, 8)
    arguments[0]:=AX12_COMMAND_WRITE
    arguments[1]:=AX12_REGISTER_CWw_MARGIN      
    arguments[2]:=0                       'cwW 0
    ComposeBioloidCommand(ID, 8-4, @arguments ,@CommandTemplate)
    TX.tx_string(@CommandTemplate, 8)
  else
    arguments[0]:=AX12_COMMAND_WRITE
    arguments[1]:=AX12_REGISTER_CW_MARGIN      
    arguments[2]:=0                       'cw 0
    ComposeBioloidCommand(ID, 8-4, @arguments ,@CommandTemplate)
    TX.tx_string(@CommandTemplate, 8)
    arguments[0]:=AX12_COMMAND_WRITE
    arguments[1]:=AX12_REGISTER_CWw_MARGIN      
    arguments[2]:=0                       'cwW 0
    ComposeBioloidCommand(ID, 8-4, @arguments ,@CommandTemplate)
    TX.tx_string(@CommandTemplate, 8) }

'------------------------------ User functions -----------------------------------------------
PUB Ping(ID): Found | mode, pl, cs, len, rmode 'Ping servo and get status
  len := $02
'  cs := (id + len + i_Ping)^$FF
  cs := (ID + len + AX12_COMMAND_PING)^$FF
  
  dBus.SetAxBuffer(0, $FF)
  dBus.SetAxBuffer(1, $FF)
  dBus.SetAxBuffer(2, ID)
  dBus.SetAxBuffer(3, len)
  dBus.SetAxBuffer(4, AX12_COMMAND_PING)
  dBus.SetAxBuffer(5, cs)

  pl := len + $04
  mode := GetResponseMode(AX12_COMMAND_PING)
  
  'Execute
  dBus.ExecuteCommand(pl,mode)

' ser.str(string("PW"))
' ser.dec(dbus.GetTimeOut)
' ser.tx(" ")
  
  repeat while ((rmode:= dbus.getmode) & $0f) 'wait for response complete (mode 0)
'   ser.dec(rmode)
'   ser.tx(" ")

  if (rmode & $80)                'check error bit
    Found:=FALSE
'   Ser.str(string("No Response from "))
'   ser.dec(ID)
'   ser.tx(CR)
  else
    Found:=TRUE
    AXStatus[ID]:=dBus.GetAxBuffer(4)  'Store error status
'   ShowResponseBuffer
    
    
'--------------------------------------------------------------------------------------------

PUB LED(ID,onoff)

byteArray[0]:=onoff
WriteData(ID, AX12_REGISTER_LED, 1)

'--------------------------------------------------------------------------------------------
PUB SetPosition(ID, Position, RA)     'Set new position. RA=0, asyncronous direct writedata. RA=1, WriteReg and Action 

'CommandSetGoalPosition BYTE $ff,$ff,$0D,$05,$03,$1E,$00,$02,$CA

  ser.str(string("Set P "))
  ser.dec(ID)
  ser.tx(" ")
  ser.dec(Position)
  ser.tx(" ")
  byteArray[0]:= position & $FF
  byteArray[1]:= (position >> 8) & $FF
  If RA==0
    WriteData(ID, AX12_REGISTER_GOAL_POSITION, 2)
  else  
    WriteReg(ID, AX12_REGISTER_GOAL_POSITION, 2)
                    
'--------------------------------------------------------------------------------------------
PUB SetSpeed(ID, Speed)   ' Set Spped for current and next move
'CommandSetMovingSpeed BYTE $ff,$ff,$0D,$05,$03,$1E,$00,$02,$CA

  byteArray[0]:= Speed & $FF
  byteArray[1]:= (Speed >> 8) & $FF
  WriteData(ID, AX12_REGISTER_MOVING_SPEED, 2)

'--------------------------------------------------------------------------------------------
PUB SetPunch(ID, Punch, RA)

'CommandSetGoalPosition BYTE $ff,$ff,$0D,$05,$03,$1E,$00,$02,$CA

  ser.str(string("Set Punch "))
  ser.dec(ID)
  ser.tx(" ")
  ser.dec(Punch)
  ser.tx(" ")
  byteArray[0]:= Punch & $FF
  byteArray[1]:= (Punch >> 8) & $FF
  WriteData(ID, AX12_REGISTER_PUNCH, 2)

'------------------------------ Basic Read and Write buffer preparation ----------------------
PUB ReadData(id, startAddr, bytesToRead) | len, cs, pl, mode, rmode
'cs := ID + Length + Instruction + Param1 +... Param N)
'Read Data (ID, Length, Instuction, <Parameters[start address, bytes to read]>, Check Sum)

  len := $04
  cs := (id + len + AX12_COMMAND_READ + startAddr + bytesToRead)^$FF
    
  dBus.SetAxBuffer(0, $FF)
  dBus.SetAxBuffer(1, $FF)
  dBus.SetAxBuffer(2, id)
  dBus.SetAxBuffer(3, len)
  dBus.SetAxBuffer(4, AX12_COMMAND_READ)
  dBus.SetAxBuffer(5, startAddr)
  dBus.SetAxBuffer(6, bytesToRead)
  dBus.SetAxBuffer(7, cs)
  
  pl := len + $04
  mode := GetResponseMode(AX12_COMMAND_READ)
  
  'Execute
  dBus.ExecuteCommand(pl, mode)

 { ser.str(string("RW"))
  ser.dec(dbus.GetTimeOut)
  ser.tx(" ") }
  repeat while ((rmode:= dbus.getmode) & $0f) 'wait for response complete (mode 0)
 {  ser.dec(rmode)

  if (rmode & $80)                'check error bit
    Ser.str (string("No Response."))   
  else
    'ShowResponseBuffer }

  AXStatus[ID]:=dBus.GetAxBuffer(4)  'Store error status
    
Result:=!(rmode & $80)

'--------------------------------------------------------------------------------------------
PUB ReadTest(id, startAddr, bytesToRead) | len, cs, pl, mode, rmode, errors
'cs := ID + Length + Instruction + Param1 +... Param N)
'Read Data (ID, Length, Instuction, <Parameters[start address, bytes to read]>, Check Sum)
errors := 0

  Ser.str (string("Read Loop.."))    
  repeat 10000
    len := $04
    cs := (id + len + AX12_COMMAND_READ + startAddr + bytesToRead)^$FF
    
    dBus.SetAxBuffer(0, $FF)
    dBus.SetAxBuffer(1, $FF)
    dBus.SetAxBuffer(2, id)
    dBus.SetAxBuffer(3, len)
    dBus.SetAxBuffer(4, AX12_COMMAND_READ)
    dBus.SetAxBuffer(5, startAddr)
    dBus.SetAxBuffer(6, bytesToRead)
    dBus.SetAxBuffer(7, cs)
  
    pl := len + $04
    mode := GetResponseMode(AX12_COMMAND_READ)
  
  'Execute
    dBus.ExecuteCommand(pl, mode)

' ser.str(string("RTW"))
' ser.dec(dbus.GetTimeOut)
' ser.tx(" ")
    repeat while ((rmode:= dbus.getmode) & $0f) 'wait for complete (mode 0)
'   ser.dec(rmode)

 { if (rmode & $80)               'check error bit
    Ser.str(string("No Response."))
    Ser.dec((Num.toStr(errors++,Num#DEC4)))      
  else
    'ShowResponseBuffer   }
  AXStatus[ID]:=dBus.GetAxBuffer(4)  'Store error status

Result:=!(rmode & $80)     

'--------------------------------------------------------------------------------------------
PUB WriteData(ID, startAddr, N) | len, pl, cs, mode, tempSum, idx, idx2, rmode
  'N+3 because you need to add the start address parameter
  len := N + 3
  idx := 0
  idx2 := 0
  tempSum := 0
  
  dBus.SetAxBuffer(idx++, $FF)
  dBus.SetAxBuffer(idx++, $FF)
  dBus.SetAxBuffer(idx++, ID)
  dBus.SetAxBuffer(idx++, len)
  dBus.SetAxBuffer(idx++, AX12_COMMAND_WRITE) 'i_WriteData)
  dBus.SetAxBuffer(idx++, startAddr)
  'get all data bytes to send
  repeat N
    tempSum += byteArray[idx2]
    dBus.SetAxBuffer((idx), byteArray[idx2])
    idx++
    idx2++
    
  'CheckSum  
  cs := (id + len + AX12_COMMAND_WRITE + startAddr + tempSum)^$FF
  'Set checksum
  dBus.SetAxBuffer((idx), cs)

  'Packet length and mode
  pl := len + $04
  mode := GetResponseMode(AX12_COMMAND_WRITE)
  
  'Execute
  dBus.ExecuteCommand(pl, mode)

{ ser.str(string("WW"))
  ser.dec(dbus.GetTimeOut)
  ser.tx(" ")}
  repeat while ((rmode:= dbus.getmode) & $0f) 'wait for complete (mode 0)
 '  ser.dec(rmode)

{ if (rmode & $80)                'check error bit
    Ser.str(string("No Response."))   
  else
    ShowResponseBuffer}

  {byteArray[0]:= position & $FF
  byteArray[1]:= (position >> 8) & $FF
  WriteData(ID, AX12_REGISTER_GOAL_POSITION, 2)}

  AXStatus[ID]:=dBus.GetAxBuffer(4)  'Store error status

Result:=!(rmode & $80)     
 
'--------------------------------------------------------------------------------------------
PUB WriteReg(ID, startAddr, N) | len, pl, cs, mode, tempSum, idx, idx2, rmode
  'N+3 because you need to add the start address parameter
  len := N + 3
  idx := 0
  idx2 := 0
  tempSum := 0
  
  dBus.SetAxBuffer(idx++, $FF)
  dBus.SetAxBuffer(idx++, $FF)
  dBus.SetAxBuffer(idx++, ID)
  dBus.SetAxBuffer(idx++, len)
  dBus.SetAxBuffer(idx++, AX12_COMMAND_REG_WRITE)
  dBus.SetAxBuffer(idx++, startAddr)
  'get all data bytes to send
  repeat N
    tempSum += byteArray[idx2]
    dBus.SetAxBuffer((idx), byteArray[idx2])
    idx++
    idx2++
    
  'CheckSum  
  cs := (id + len + AX12_COMMAND_REG_WRITE + startAddr + tempSum)^$FF
  'Set checksum
  dBus.SetAxBuffer((idx), cs)

  'Packet length and mode
  pl := len + $04
  mode := GetResponseMode(AX12_COMMAND_REG_WRITE)
  
  'Execute
  dBus.ExecuteCommand(pl, mode)

  repeat while ((rmode:= dbus.getmode) & $0f) 'wait for complete (mode 0)

  AXStatus[ID]:=dBus.GetAxBuffer(4)  'Store error status

Result:=!(rmode & $80)     

'--------------------------------------------------------------------------------------------
PUB Action | mode, pl, cs, len, id, rmode       'Set servo's into action
  len := $02
  id := $FE
  cs := (id + len + AX12_COMMAND_ACTION)^$FF
  
  dBus.SetAxBuffer(0, $FF)
  dBus.SetAxBuffer(1, $FF)
  dBus.SetAxBuffer(2, id)
  dBus.SetAxBuffer(3, len)
  dBus.SetAxBuffer(4, AX12_COMMAND_ACTION)
  dBus.SetAxBuffer(5, cs)

  pl := len + $04
  mode := GetResponseMode(AX12_COMMAND_ACTION)
  
  'Execute
  dBus.ExecuteCommand(pl,mode)
  repeat while ((rmode:= dbus.getmode) & $0f) 'wait for complete (mode 0)
  
  if (rmode & $80)                'check error bit
    Ser.str (string("No Response."))   
  else
    'ShowResponseBuffer
    
'--------------------------------------------------------------------------------------------
PRI GetResponseMode(instructionType) : mode
  case instructionType
    AX12_COMMAND_PING       : mode := 1
    AX12_COMMAND_READ       : mode := 1
    AX12_COMMAND_WRITE      : mode := 1        
    AX12_COMMAND_REG_WRITE  : mode := 2
    AX12_COMMAND_ACTION     : mode := 2
    AX12_COMMAND_RESET      : mode := 1
    AX12_COMMAND_SYNC_WRITE : mode := 2
    other                   : mode := 0

'--------------------------------------------------------------------------------------------

PRI ShowResponseBuffer | pl, idx, col, line
  line:= 2
  col := 0
  pl :=  dBus.GetAxBuffer($03) + 3
    ser.str(string("ShowR "))
    ser.dec(pl)
    ser.tx(" ")
    repeat idx from 0 to pl 
      Ser.hex (dBus.GetAxBuffer(idx),2)
      ser.tx(" ")
    ser.tx(CR)


'--------------------------------------------------------------------------------------------
PUB Torque(ID,onoff)

{  arguments[0]:=AX12_COMMAND_WRITE
  arguments[1]:=AX12_REGISTER_TORQUE_ENABLE
  arguments[2]:=onoff   'Torque OFF
  ComposeBioloidCommand(ID, 8-4, @arguments ,@CommandTemplate)
  TX.tx_string(@CommandTemplate, 8)
                                       }
'--------------------------------------------------------------------------------------------
{PUB SetPosition(ID, position, RA)  'Set new servo position. RA=0 direct RA=1 Wait for Action command

'CommandSetGoalPosition BYTE $ff,$ff,$0D,$05,$03,$1E,$00,$02,$CA
  if RA==0
    arguments[0]:=AX12_COMMAND_WRITE
    arguments[1]:=AX12_REGISTER_GOALPOSITION
    arguments[2]:=position & $FF
    arguments[3]:=(position >> 8) & $FF
  else  
    arguments[0]:=AX12_COMMAND_REG_WRITE
    arguments[1]:=AX12_REGISTER_GOALPOSITION
    arguments[2]:=position & $FF
    arguments[3]:=(position >> 8) & $FF

'  ComposeBioloidCommand(ID, 9-4, @arguments ,@CommandTemplate)
  ComposeBioloidCommand(ID, 9-4, @arguments ,@CommandTemplate)

  TX.tx_string(@CommandTemplate, 9)
  sleep(10)
  RX.rxflush
  sleep(10)
  RX.rx_string(@commandReceive, 6, 1)

  Sleep(10)     }


'--------------------------------------------------------------------------------------------
PRI Sleep(ms)
  waitcnt(clkfreq/1000 * ms + cnt)
  
'--------------------------------------------------------------------------------------------
PRI Sleepus(us)
  waitcnt(clkfreq/1000000 * us + cnt)

'--------------------------------------------------------------------------------------------
PRI SleepForReadReady
  waitcnt(clkfreq/1000 * 1 + cnt)

'----------------------------------Still to be done HJK --------------------------------------------

{PRI Test_Sensor |distance


'ser.out(0)
ser.Str(string("Testing factory made sounds on AXS1"))
'ser.out($D)

repeat i from 0 to 26
  if i==$11
    i:=$12
  if i==3
    i:=15  
  ser.Str(string("Sound "))
  ser.Str(Num.toStr(i,Num#IHEX))
 'TV.Out(13)
  AXS1_Out(ax12a,AX12_COMMAND_WRITE,AXS1_REGISTER_BUZZER_TIME,255)
  Sleepus(16)
  RX.rxflush 
  AXS1_Out(ax12a,AX12_COMMAND_WRITE,AXS1_REGISTER_BUZZER_INDEX,i)
  Sleepus(16)
  RX.rxflush 
  Sleep(2500)


'ser.out(0)
ser.Str(string("Reading center distance sensor. Put your hand in front of AXS1 and move it back and forth"))
'ser.out($D)
Sleep(1500)

repeat i from 0 to 200
  AXS1_Out(ax12a,AX12_COMMAND_READ, AXS1_REGISTER_DISTANCE_CENTER, 1)
  Sleepus(32)
  RX.rx_string(@commandReceive, 7, 1)
  Sleep(1)
  distance := commandReceive[5]
  if distance == $FF
    ser.Str(string("Too near!"))
  else
    if distance < 7 
      ser.Str(string("Too far!"))
    else
      ser.Str(Num.toStr(distance,Num#IHEX))
      'SetGoalPosition(AX12_ID, distance)
      'Sleepus(20)
      'RX.rxflush
      SetPosition(AX12a, distance*2,0)
      SetPosition(AX12b, distance*2,0)
      Sleepus(20)
      ReadString(6,1)
      Sleep(100)     

 ' TV.Out($D)
  Sleep(125)

'ser.out(0)
ser.Str(string("Testing center light sensor. Place a light in front of AXS1 and move it around"))
'ser.out($D)

repeat i from 0 to 200
  AXS1_Out(ax12a,AX12_COMMAND_READ, AXS1_REGISTER_LIGHT_CENTER, 1)
  Sleepus(32)
  RX.rx_string(@commandReceive, 7, 1)
  Sleep(1)
  distance := commandReceive[5]
  if distance == $FF
    ser.Str(string("Too Bright!"))
  else
    if distance < 7 
      ser.Str(string("Too Dark!"))
    else
      ser.Str(Num.toStr(distance,Num#IHEX))
    
 ' TV.Out($D)
  Sleep(125)


'ser.out(0)
ser.Str(string("Testing IR remote control. Use your IR remote to send commands"))
'ser.out($D)

repeat i from 0 to 200
  AXS1_Out(ax12a,AX12_COMMAND_READ, AXS1_REGISTER_IR_REMOCON_READY, 1)
  Sleepus(32)
  RX.rx_string(@commandReceive, 7, 1)
  Sleep(1)
  distance := commandReceive[5]
  if distance==2
    ser.Str(string("Data detected"))
    AXS1_Out(ax12a,AX12_COMMAND_READ, AXS1_REGISTER_IR_REMOCON_DATA, 2)
    Sleepus(32)
    RX.rx_string(@commandReceive, 8, 1)
    distance := commandReceive[5]
    ser.Str(Num.toStr(distance,Num#IHEX))
 '   ser.Out($D)
    Sleep(100)
  Sleep(125)
                      }

'--------------------------------------------------------------------------------------------

    
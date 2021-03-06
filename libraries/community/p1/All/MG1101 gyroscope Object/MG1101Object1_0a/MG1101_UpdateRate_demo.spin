{{

┌─────────────────────────────────────────────────┐
│ MG1101_UpdateRate_demo, for Gyration gyroscope  │
│ to demonstrate use of MG1101Object Object 1.0   │               
│ Author: Eric Ratliff                            │               
│ Copyright (c) 2008 Eric Ratliff                 │               
│ See end of file for terms of use.               │                
└─────────────────────────────────────────────────┘
to time update rate of gyro data from MG1101 gyro, and how fast we can poll all data from the gyro
shows use of some lower level routines than engineering units demo
Revision History:
 -> V1.0 first version 2008.10.12 by Eric Ratliff
 -> V1.0a corrected instructions per Tim Pifer to match code, were pins 0 and 1 of Propeller, now pins 2 and 3 of Propeller

derived from James Burrows' I2C Demo Propeller program of Oct 2007

see MG1101Object for schematic and reference to documentation of the gyro device

this demo uses the following sub OBJECTS:
 -> MG1101Object
 -> basic_i2c_driver
 -> Debug_PC
 -> pcFullDuplexSerial
 -> Simple_Numbers

Instructions (brief):
(1) - setup the propeller - see the Parallax Documentation (www.parallax.com/propeller)
(2) - Use a 5mhz crystal on propeller X1 and X2
(3) - Connect the SDA lines to Propeller Pin3, and SCL lines to Propeller Pin2
         See diagram in Object's code for resistor placements.
(4) - set up Hyperterminal to the com port of the USB connection to the Propeller chip, then dicconnect but do not close Hyperterminal
(5) - download the app, then click 'call' icon in Hyterterminal to connect, may also use 'text capture' to record data on PC

}}

OBJ
  i2cObject      : "basic_i2c_driver"
  GyroChip      : "MG1101Object"
  debug         : "Debug_PC"
  
CON
  _clkmode      = xtal1 + pll16x
  _xinfreq      = 5_000_000
  _stack        = 50

  ' where to find I2C bus, data pin is one higher    
  i2cSCL        = 2

  ' debug - USE onboard pins
  pcDebugRX       = 31
  pcDebugTX       = 30

  ' serial baud rates  
  pcDebugBaud     = 115200
  CarrigeReturn   = 13          ' ASCII code for moving cursor to beginning of line
  LineFeed        = 10          ' ASCII code for moving cursor to next row
  Space           = 32          ' ASCII code for space character

  TimedPollCount  = 100
  
VAR
  long  i2cAddress, i2cSlaveCounter
  byte  CalConstants[GyroChip#CalByteCount]               ' calibration constants for gyro chip
  byte  GyroData[GyroChip#GyroDataByteCount]              ' sensors and status for gyro chip
  long  NetPollTime_ms                                  ' how long it took to poll all data without reporting (ms)
  long  PollStartTime                                   '                       (clocks)
  long  PollEndTime                                     '                       (clocks)
  long  NetPollTime                                     '                       (clocks)
  long  OldGyro                 ' combined pitch and yaw rates of last poll
  long  NewGyro                 ' combined pitch and yaw rates of this poll
  long  ChangePollCount         ' how many I2C bus polls before a gyro data change

pub Start
    ' start the PC debug object
    debug.startx(pcDebugRX,pcDebugTX,pcDebugBaud)
  
    ' setup i2cobject
    i2cObject.Initialize(i2cSCL)

    ' pause 5 seconds to allow user to start Hyperterminal
    repeat 10
        debug.putc(".")
        waitcnt((clkfreq/2)+cnt)
    CrLf
  
    ' i2c state
    debug.strln(string("MG1101_UpdateRate_demo"))
    CrLf

    'demo the i2c scan (not required to use the gyro)
    i2cScan
    waitcnt(clkfreq*2 +cnt)

    MG1101B_Demo

PRI MG1101B_Demo | HoldingLong, CalIndex, ResultCode
    ' demo the Gyration Gyroscope

    ' read calibration constants from EEPROM of gyro
    GyroChip.getStoredCalibrationConstants(i2cSCL,@CalConstants[0])
    debug.str(string("calibration constants from EEPROM:"))
    CrLf
    repeat CalIndex FROM 0 TO GyroChip#CalByteCount-1
      HoldingLong := CalConstants[CalIndex]
      debug.dec(HoldingLong)
      debug.putc(Space)                            
    CrLf

    ' write cal constants
    GyroChip.writeCalConstantsToRam(i2cSCL,@CalConstants[0])
    debug.str(string("wrote constants to Gyro Function:"))
    CrLf
    
    ' set gyro initialize bit
    GyroChip.setGyroIinitalizeBit(i2cSCL)
    debug.str(string("set gyro initialize bit:"))
    CrLf
    
    ' set power mode to full operation
    GyroChip.setGyroPowerFull(i2cSCL)
    debug.str(string("set gyro to full power mode:"))
    CrLf

    ' poll not ready bit until it is cleared
    ResultCode := GyroChip.WaitForGyroReady(i2cSCL)
    if ResultCode <> GyroChip#GRNR_WaitOK
      debug.str(string("gyro timed out, status code = "))
      debug.dec(ResultCode)
    else
      debug.str(string("gyro is ready"))
    CrLf

    ' poll values but don't report results, also allows for device to stabilize
    PollStartTime := cnt
    repeat TimedPollCount
      GyroChip.getAllGyroData(i2cSCL,@GyroData[0])
    PollEndTime := cnt
    NetPollTime := PollEndTime - PollStartTime
    NetPollTime_ms := NetPollTime /(clkfreq/1000)
      
    debug.str(string("polling "))
    debug.dec(TimedPollCount)
    debug.str(string(" samples took "))
    debug.dec(NetPollTime_ms)
    debug.str(string(" milliseconds"))
    CrLf
             
    ' poll values a while
    repeat 10
      repeat 3                  ' do more than once to avoid including print time in measurement
        PollStartTime := cnt
        ChangePollCount := 0
      
        ' poll values but don't report results, until gyro data changes
        repeat while OldGyro == NewGyro
          OldGyro := NewGyro
          GyroChip.getAllGyroData(i2cSCL,@GyroData[0])
          NewGyro := LONG[@GyroData[0]]
          ChangePollCount += 1
        OldGyro := NewGyro
        PollEndTime := cnt
        NetPollTime := PollEndTime - PollStartTime
        NetPollTime_ms := NetPollTime /(clkfreq/1000)

      ' report new gyro data as one long, I2C poll count to get change, and time to do this
      debug.str(string("gyro="))
      debug.dec(NewGyro)
      debug.str(string(" polls="))
      debug.dec(ChangePollCount)
      debug.str(string(" update time="))
      debug.dec(NetPollTime_ms)      
      debug.str(string(" (ms)"))
      CrLf

PRI i2cScan | ackbit
    ' Scan the I2C Bus
    debug.strln(string("Scanning I2C Bus...."))
     
    ' initialize variables
    i2cSlaveCounter := 0
     

    i2cAddress := GyroChip#MG1101_EEPROM_Addr
    ackbit := i2cObject.devicePresent(i2cSCL,i2cAddress)
        
    if ackbit==false
      debug.str(string("EEPROM NAK"))
    else
      ' show the scan                  
      debug.str(string("EEPROM Addr : %"))
      debug.bin(i2cAddress,8)          
      debug.str(string(", ACK"))                         
                                       
      ' the device has set the ACK bit 
      i2cSlaveCounter ++               
    CrLf
                                       
    i2cAddress := GyroChip#MG1101_Gyro_Addr
    ackbit := i2cObject.devicePresent(i2cSCL,i2cAddress)
        
    if ackbit==false
      debug.str(string("GyroDevice NAK"))
    else
      ' show the scan                  
      debug.str(string("GyroDevice Addr : %"))
      debug.bin(i2cAddress,8)          
      debug.str(string(", ACK"))                         
                                       
      ' the device has set the ACK bit 
      i2cSlaveCounter ++                                       
    CrLf
         
    ' update the counter
    debug.str(string("i2cScan found "))
    debug.dec(i2cSlaveCounter)
    debug.strln(string(" devices!"))
    CrLf

PRI CrLf
  debug.putc(CarrigeReturn)
  debug.putc(LineFeed)

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
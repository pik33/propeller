{                                                              dynamixel bus communications driver        
                                                      dynamixel baud rate can be set from 7.843k to 1m baud
                                              refer to the ax12  user manual from Robotis for servo address meanings                                            
                                        
  File....... DynaComV4.spin  
  Purpose.... Propeller driven AX-12 half duplex dynamixel bus driver 
  Author..... Dave Ratcliff  'ratronic'
  Support.... http://forums.parallax.com
  
  9/10/13 - Updated to version 4 with methods to set continuous rotation or servo mode and return directional torq +/-
  7/25/11 - tightened bit period timming with waitcnt
   
 Credits:
 This program was inspired from the work of Mike Gebhard's dynamixel dynabus.spin and dynamixeldriver.spin programs
 
 ┌───────────┐                
 │   AX-12   │ 
 │ spg  spg  │ 
 └─┳┳┳──┳┳┳──┘     Vdd (3.3V)
   │ │   │         
   │   6-9.6V      │
   │ Vss        10k     
   └────────────────┴── propeller i/o Pin 
                     1k

                                                                     ******* servo command methods *******
                                                                     
          chngid(id)                    = change servo id to indicated 'id'             use  dy.chngid(3)  (change attached servo(s) id# to '3') WARNING - THIS WILL CHANGE ALL SERVOS ATTACHED TO THE SPECIFIED ID#)
          getalarmbyte(id)              = get servo id# alarm/error byte                use  dy.getalarmbyte(1)  (returns servo id# '1' alarm byte)
          getrxbuffaddr                 = get address of ax12 receive buffer            use  dy.getrxbuffaddr  (returns servo's receive buffer address)
          getsrvpos(id)                 = get servo id# current position                use  dy.getsrvpos(1)  (returns servo id# '1' current position)
          getsrvtmp(id)                 = get servo id# temperature                     use  dy.getsrvtmp(2)  (returns servo id# '2' current temperature in degrees celsius)
          getsrvtrq(id)                 = get servo id# current torq reading + direct.  use  dy.getsrvtrq(3)  (returns servo id# '3' current torq reading with directional +/- #'s)
          getsrvvlt(id)                 = get servo id# current voltage X 10            use  dy.getsrvvlt(1)  (returns servo id# '1' current voltage X 10) 
          setcontinrotation(id)         = set servo id# to continuous rotation          use  dy.setcontinrotation(1)  (sets servo id# '1' to continuous rotation)
          setcontrotatall               = set all attached servos to continuous rot.    use  dy.setcontrotatall  (set all attached servos to continuous rotation)
          setservomode(id)              = set a servo from continuous to servo mode     use  dy.setservomode(1)  (set servo id# '1' from continuous to servo mode)
          setservomodeall               = set all attached servos to servo mode         use  dy.setservomodeall  (set all attached servos to servo mode)
          setsrvpos(id, position)       = set servo id# goal position                   use  dy.setsrvpos(2, 512)  (set servo id# '2' to position '512',  positions from 0 to 1023)
          setsrvspd(id, speed)          = set servo id# moving speed                    use  dy.setsrvspd(1, 100)  (set servo id# '1' moving speed to '100', speeds from 0 to 1023, contin.rotation= 0-1023ccw, 1024-2047cw)
          setsrvspdall(speed)           = set all attached servos to speed              use  dy.setsrvspdall  (set all attached servos to 'speed')
          srvalltrqoff                  = turns off torq for all attached servos        use  dy.srvalltrqoff  (turns off torq for all attached servos)       (servo mode speeds 0=full speed, 1-1023=slow to full speed)
          srvalltrqon                   = turns on torq for all attached servos         use  dy.stvalltrqon  (turns on torq for all attached servos)   
          srvtqoff(id)                  = turn off torq for servo id#                   use  dy.srvtqoff(2) (turn off torq for servo id# '2')  
          srvtqon(id)                   = turn on torq for servo id#                    use  dy.srvtqon(2) (turn torq on for servo id# '2')
                                                                   
          
                                                                ****** dynamixel instruction set methods ******
                                                                    
          action                        = trigger action from regwrite                  use  dy.action  (trigger action with bytes written to bytearray buffer - see regwrite method for example)                      
          ping(id)                      = check for servo 'id'                          use  dy.ping(1) (returns true(-1) if servo id#1 is present with no error or error byte)  
          readdata(id, address, bytes)  = read servo (id's) (address) (how many bytes)  use  dy.readdata(1, 30, 2) (returns 2 bytes from address 30 for id#1)
          regwrite(id, address, bytes)  = see method for example                        use  dy regwrite(1, 30, 2)  (write bytes written to bytearray buffer - see method for example) 
          reset(id)                     = reset servo 'id'                              use  dy.reset(3)  (reset servo id# '3' to factory default baud, id, speed, etc)
          syncwrite(nmsrv ,addr, bytes) = # of Dynams(nmsrv),address(addr),#bytes(bytes)use  dy.syncwrite(2, 30, 4)  (writes bytes written to bytearray buffer - see method for example)
          writedata(id, address, value) = write 'value' to servo'id' @servo 'address')  use  dy.writedata(1, 30, 512) (write to servo-id# '1' starting@servo-address '30' the # '512')                  

          
                                                                    ****** buffer methods ******
                                                                    
          getrxbuffadd                  = returns address of _rxbuffer                  use  dy.getbuffadd  (returns the beginning address of the _rxbuffer)      
          getrxbuffer(index)            = get the byte at _rxbuffer(index)              use  dy.getrxbuffer(0)  (returns the byte at _rxbuffer'0')
          gettxbuffer(index)            = get the byte at _txbuffer(index)              use  dy.gettxbuffer(1)  (returns the byte at _txbuffer'1')                    
          setbabf(index)                = set the byte at bytearray buffer(index)       use  dy.setbabf(3, 200)  (write '200' in bytearray'3')                          }
                                                 
Var

  long  cog
  long  _mode                   'transmit/receive flag (0=wait, 1=transmit&receive, 2=transmit only)
  long  _axPin                  'propeller i/o pin for ax12 network
  long  _txptr                  'transmit buffer pointer  
  long  _rxptr                  'receive buffer pointer
  long  _timeout                'receive timeout
  long  _packetLength           'transmit packet length
  long  _bitticks               'bit period
  byte  _txbuffer[64]           'ax12 transmit buffer
  byte  _rxbuffer[64]           'ax12 receive buffer
  byte  bytearray[32]           'bytearray for use regwrite and sync write methods 
                                  

'                  ********** all 'example use' shown below is considering this object is started with the object name of 'dy' ************  
Pub Start(axpin, baud)                                  'start dynamixel  bus communication on propeller i/o # (axpin)     
                                                        'example use - dy.start(8, 1_000_000) -start this driver using propeller p8 @ 1m baud connection rate                                                              
'axpin = dynamixel bus communication propeller i/o port#                                              
'baud  = connection baud rate with servos                                                                                                                       
                                                                                                                
  _mode := 0                                                                                                           
  _axPin := axpin                                                                                                      
  _txptr := @_txbuffer
  _rxptr := @_rxbuffer                                                                                        
  _timeout := 10_000         '150ns per cnt * 10000 = 1.5ms receive timeout                                                                                          
  _packetLength := 0
  _bitticks := clkfreq / baud                                                                                                 
  return cog := cognew(@entry, @cog) + 1                                                                    

Pub Stop                                                'stop cog                
                                                                                  
   if cog                                                                         
     cogstop(cogid)                                                                 

Pub ChngId(id)                                          'change currently attached servo(s) to id# - WARNING - THIS WILL CHANGE ALL ATTACHED SERVOS TO SPECIFIED ID#    

'id = dynamixel servo id# that you want currently attached servo(s) changed to. 

  writedata($fe, 3, id)
                                                                                    
Pub GetAlarmByte(id)                                    'returns servo id# alarm byte 
                                                        'example use - dy.getalarmbyte(1)  -  returns servo id# '1' alarm byte
  ping(id)                                              '                                                      = 0 if no alarm/error
  return _rxbuffer[4]
                                                          
Pub GetRxBuffer(index)                                  'returns the byte from _rxbuffer[index]           
                                                        'example use - 'dy.getrxbuffer(4)' - returns _rxbuffer[4] byte                                      
'index = return the byte in the _rxbuffer at index location                                         
                                                                                                    
  return _rxbuffer[index]                                                                          

Pub GetRxBuffAddr                                       'returns address of rxbuffer
                                                        'example use - dy.getrxbuffaddr     this returns the receive buffer address
  return @_rxbuffer
                                                   
Pub GetTxBuffer(index)                                  'returns the byte at _txbuffer[index]
                                                        'example use - 'dy.gettxbuffer(2)' - returns _txbuffer[2] byte
'index = return the byte in the _txbuffer at index location

  return _txbuffer[index]
  
Pub GetSrvPos(id)                                       'returns current servo 'id' position - returns dynamixel id# current position   positions from 0 to 1023
                                                        'example use - 'dy.getsrvpos(1)' - returns servo id#(1) current position
'id = dynamixel id#

  return readdata(id, 36, 2)           
    
Pub GetSrvTmp(id)                                       'returns servo temperature - returns dynamixel Id# temperature in degrees celsius            
                                                        'example use - 'dy.getsrvtmp(1)' - returns servo id#(1) temperature                                      
'id = dynamixel id#
                                                                                      
  return readdata(Id, 43, 1)                                                                             
    
Pub GetSrvTrq(id) | trq                                 'returns servo id# current torq reading directional with +/- #'s
                                                        'example use - 'dy.getsrvtrq(1)' - returns current torq reading for servo id#(1)
'id = dynamixel id#

  trq := readdata(id, 40, 2)
  if not trq & $400
    return -(trq & $3ff)
  return (trq & $3ff)
  
Pub GetSrvVlt(id)                                       'returns servo id# current voltage X 10
                                                        'example use - 'dy.getsrvvlt(1)' returns servo id#'1' voltage X 10
'id = dynamixel id#

  return readdata(id, 42, 1)
              
Pub SetBaBf(index, value)                               'set bytearray[index] to 'value'
                                                        'example use - 'dy.setbabf(0, $ff)' - set bytearray[0] := $ff
'index = _bytearray[index] 'byte position in _bytearray
'value = byte to write in _bytearray[index]
                                                        'for use with syncwrite and regwrite methods
  bytearray[index] := value

Pub SetContinRotation(id)                               'set continuous rotation for servo id#
                                                        'example use - dy.setcontinrotation(1)  -  set servo id# '1' to continuous rotation
'id = dynamixel id#

  writedata(id, 6, 0)
  writedata(id, 8, 0)

Pub SetContRotatAll                                     'set all connected servos to continuous rotatation mode
                                                        'example use - dy.setcont - set all connected servos to continuous rotation mode
  writedata($fe, 6, 0) 
  writedata($fe, 8, 0) 
                                                                 
Pub SetServoMode(id)                                    'set servo back to servo mode from continuous rotation for servo id#
                                                        'example use - dy.setservomode(1)  -  set servo id# '1' to servo mode
  writedata(id, 6, 0)
  writedata(id, 8, $3ff)

Pub SetServoModeAll                                     'set all attached servos to servo mode
                                                        'example use - dy.setservomodeall  -  set all attached servos to servo mode
  writedata($fe, 6, 0)    
  writedata($fe, 8, $3ff) 
                                                                                    
Pub SetSrvPos(id, position)                             'set servo position - write 'position' to dynamixel servo 'id' goal position
                                                        'example use - dy.setsrvpos(1, 512)' - set servo id#'1' to '512' goal position
'id       = dynamixel id#
'position = servo position to set dynamixel id# to (0 - 1023)

  position := 0 #> position <# 1023                      
  writedata(id, 30, position)                                                              
        
Pub SetSrvSpd(id, speed)                                'set servo speed - sets dynamixel servo 'id' moving speed to 'speed' (0 - 1023), (0 = full speed, 1-1023 = 0 to full speed when in servo mode)
                                                        'example use - dy.setsrvspd(1, 100)' - set servo id# '1' moving speed to '100'
'id = dynamixel id#                                     'when servo set for continuos rotation speed is 0 - 1023 counter clockwise, 1024 - 2047 clockwise
'speed = dynamixel 'moving speed'

  speed := 0 #> speed <# 2047
  writedata(id, 32, speed)
           
Pub SetSrvSpdAll(speed)                                 'set all attached servos to 'speed'
                                                        'example use - dy.setsrvspdall  -  set all attached servos to 'speed'
'speed = see SetSrvSpeed() above for info

  speed := 0 #> speed <# 2047 
  writedata($fe, 32, speed)    

Pub SrvAllTrqOff                                        'turn off torq for all attached servos
                                                        'example use - 'dy.srvalltrqoff' - turn off torq for all attached servos
  writedata($fe, 24, 0)

Pub SrvAllTrqOn                                         'turn on torq for all attached servos
                                                        'example use - 'dy.srvalltrqoff' - turn on torq for all attached servos
  writedata($fe, 24, 1)     
               
Pub SrvTqOff(id)                                        'disable torque on dynamixel servo 'id'
                                                        'example use - 'dy.srvtqoff(1)' - disable torque for servo id#(1)
'id = dynamixel id#

  writedata(id, 24, 0)                  
                  
Pub SrvTqOn(id)                                         'enable torque on dynamixel 'id'
                                                        'example use - 'dy.srvtqon(1)' - enable torq for servo id#(1)
'id = dynamixel id#

  writedata(id,24,1)
  

''************************************************** Dynamixel instruction methods***************************************************************
''***********************************************************************************************************************************************          
Pub Action | length, id                                 'triggers the action registered with the regwrite instruction                  
                                                        'example use - 'dy.action' - trigger action for data written with regwrite                                                                                 
  waitcnt(100000 + cnt)                                 'see regwrite method for example
  length := $02                                                                                                                          
  id := $fe                                                                                                                              
  _txbuffer[0] := $ff
  _txbuffer[1] := $ff
  _txbuffer[2] := id
  _txbuffer[3] := length
  _txbuffer[4] := 5
  _txbuffer[5] := (id + length + 5) ^ $ff
  _packetlength := length + 4
  _mode := 2
  repeat until _mode == 0                                                                                                                  

Pub Ping(id) | length                                   'returns true(-1) if dynamixel servo id# is present and has no error - or the alarm byte if servo has error or '0' if servo is not present     
                                                        'example use - 'dy.ping(1)' - returns true(-1) if servo id#(1) is present with no errors                                 
'id  = dynamixel id# to ping, returns true(-1) if present/no errors or alarm byte if servo has error or 0 if servo id is not present            
  bytefill(@_rxbuffer, 0, 64)                                                                                       
  length := 2                                                                                    
  _txbuffer[0] := $ff                                                                            
  _txbuffer[1] := $ff                                                                            
  _txbuffer[2] := id                                                                             
  _txbuffer[3] := length                                                                         
  _txbuffer[4] := 1                                                                              
  _txbuffer[5] := (id + length + 1)^$ff                                                          
  _packetlength := length + 4                                                                    
  _mode := 1                                                                                     
  repeat until _mode == 0
  if _rxbuffer[0] == $ff
    if _rxbuffer[2] == id
      if _rxbuffer[4] == 0                                                                       
        return true
  return _rxbuffer[4]                                                                       
    
Pub ReadData(id, startaddr, bytestoread) | length, cs   'returns value at servo 'id' 'startaddr' 'bytestoread'= how many bytes to read                     
                                                        'example use - 'dy.readdata(1, 36, 2)' - returns total of (2) bytes from servo id#(1) address(36),(37)  
'id          = dynamixel id#                            
'startaddr   = dynamixel address to read from
'bytestoread = how many bytes to read from dynamixel address
  bytefill(@_rxbuffer, 0, 64)   
  length := 4   
  cs := (id + length + 2 + startaddr + bytestoread) ^ $ff                  
  _txbuffer[0] := $ff                                                     
  _txbuffer[1] := $ff                                                     
  _txbuffer[2] := id                                                      
  _txbuffer[3] := length                                                     
  _txbuffer[4] := 2                                              
  _txbuffer[5] := startaddr                                               
  _txbuffer[6] := bytestoread                                             
  _txbuffer[7] := cs                                                      
  _packetlength := length + 4                                                                             
  _mode := 1
  repeat until _mode == 0
  if bytestoread == 1
    return _rxbuffer[5]  
  if bytestoread == 2
    return _rxbuffer[5] + _rxbuffer[6] * 256
      
Pub RegWrite(id, startAddr, N)  |  idx, idx2, length, tempSum    'regwrite - see example below
                                                        'register function here and then call 'action' when ready to execute
'id = dynamixel id#                                     'example use - 'dy.regwrite(1, 30, 2)' - see example below
'startaddr = dynamixel control table address
'n = number of bytes to write

'***************************************************************************************
'*                                   Example                                           *
'*                                                                                     *          
'*      Set ID 1 goal position register to 562 with regwrite                           *        
'*      Set ID 2 goal position register to 462 with regwrite                           *
'*      execute action command                                                         *         
'*                                                                                     *
'* dy.setbabf(0, 50)           'set goal position to 562                               *
'* dy.setbabf(1, 2)            '                                                       *
'* dy.regwrite(1, 30, 2)       'write id#1 goal position(30) - 2 bytes                 *
'* dy.setbabf(0, 206)          'set goal position to 462                               *
'* dy.setbabf(1, 1)            '                                                       *
'* dy.regwrite(2, 30, 2)       'write id#2 goal position(30) - 2 bytes                 *
'* dy.action                   'perform above regwrites                                *
'*                                                                                     *
'***************************************************************************************
 
  if startaddr < 6                                      'protect baudrate register 4 from accidently being changed to 0   
    return                                              'no use of using regwrite with registers less than 6 anyway                                                                                        
  length := N + 3
  idx := 6
  idx2 := 0
  tempSum := 0
  _txbuffer[0] := $ff
  _txbuffer[1] := $ff
  _txbuffer[2] := id
  _txbuffer[3] := length
  _txbuffer[4] := 4
  _txbuffer[5] := startaddr
  'idx := 6
  repeat N                               
    tempSum += byteArray[idx2]           
    _txbuffer[idx] := byteArray[idx2]  
    idx++                                
    idx2++                               
  _txbuffer[idx] := (id + length + 4 + startAddr + tempSum)^$ff    
  _packetlength := length + 4      
  _mode := 2                       
  repeat until _mode == 0
             
Pub Reset(id) | length                                  'resets dynamixel id#                                               
                                                        'example use - 'dy.reset(1)' - causes a reset of servo id#(1) to factory baud, speed, id defaults                                                 
'id = dynamixel id #                                                                                     
                                                                                                         
  length := 2                                                                                          
  _txbuffer[0] := $ff                                                                                    
  _txbuffer[1] := $ff                                                                                    
  _txbuffer[2] := id                                                                                     
  _txbuffer[3] := length                                                                                 
  _txbuffer[4] := 6                                                                                      
  _txbuffer[5] := (id + length + 6)^$ff                                                                  
  _packetlength := length + 4                                                                            
  _mode := 1                                                                                             
  repeat until _mode == 0                                                                               
       
Pub SyncWrite(numdynamixels, startaddr, numbytes) |  id, idx, idx2, length, tempsum    'see example below                                           
                                                        'set bytearray buffer first before calling this method
'numdynamixels = how many dynamixel id#'s in bytearray  'example use - 'dy.syncwrite(2, 30, 4)' - write values from bytearray (see example below) - (2) servos at address (30) (4)bytes                                                      
'startaddr     = start address in dynamixel control table to write
'numbytes      = how many bytes to write

'************************************************************************       
'*                       Example                                        *
'*  set servo id 1 goal position to 562 at 100 moving speed             *                            
'*  set servo id 2 goal position to 462 at 100 moving speed             *
'*  execute syncwrite command                                           *
'*                                                                      *
'*  dy.setbabf(0, 1)       '1st servo id#                               *
'*  dy.setbabf(1, 50)      'lowbyte position                            *
'*  dy.setbabf(2, 2)       'high byte position                          *
'*  dy.setbabf(3, 64)      'low byte speed                              *
'*  dy.setbabf(4, 0)       'high byte speed                             *
'*  dy.setbabf(5, 2)       '2nd servo id#                               *
'*  dy.setbabf(6, 206)     'low byte position                           *
'*  dy.setbabf(7, 1)       'high byte position                          *
'*  dy.setbabf(8, 64)      'low byte speed                              *
'*  dy.setbabf(9, 0)       'high byte speed                             *
'*  dy.syncwrite(2, 30, 4) 'perform syncwrite of above settings         *
'************************************************************************
  
  if startaddr < 6                                      'protect baudrate register 4 from accidently being changed to 0 
    return                                              'no use of using sync write with registers less than 6 anyway                              
  id      := $fe   
  idx     := 7
  idx2    := 0
  tempsum := 0
  length  := ((numbytes + 1) * numDynamixels)                                                                        
  _txbuffer[0] := $ff                                                                                              
  _txbuffer[1] := $ff                                                                                              
  _txbuffer[2] := id                                                                                              
  _txbuffer[3] := length + 4                                                                                       
  _txbuffer[4] := $83                                                                                               
  _txbuffer[5] := startAddr                                                                                        
  _txbuffer[6] := numbytes
  repeat length                                                                           
    tempSum += bytearray[idx2]                                                         
    _txbuffer[idx++] := bytearray[idx2++]                                       
  _txbuffer[idx] := (id + (length + 4) + numBytes + $83 + startAddr + tempSum) ^ $ff                                                             
  _packetlength := length + 4 + 4                                                                                  
  _mode := 2                                                                                                       
  repeat until _mode == 0                                                                                          

Pub WriteData(id, startaddr, value) | length, cs, h, l  'writes 'value' to dynamixel servo 'id' @ 'startaddr' address   
                                                        'example use - 'dy.writedata(1, 30, 512)' - writes (512) to servo id#(1) @(30) control table address
'id        = dynamixel id#                           
'startaddr = dynamixel control table address        
'value     = value to write to 'startaddr', value can be 0 - 2047 and will write the low/high bytes for you 

  value := 0 #> value <# 2047 
  if startaddr == 3 and value > 255                     'protect baudrate register 4 from accidently being changed to 0
    return                                              '
  if startaddr == 4 and value < 1                       '
    return                                              '
  case startaddr
    3..5        : length := 4
    6, 8        : length := 5
    11..13      : length := 4  
    14          : length := 5
    16..18      : length := 4
    24..29      : length := 4   
    30, 32 , 34 : length := 5
    44          : length := 4
    47          : length := 4
    48          : length := 5
    other       : return
  h := value / 256        
  l := value & $ff
  _txbuffer[0] := $ff                              
  _txbuffer[1] := $ff                              
  _txbuffer[2] := id                               
  _txbuffer[3] := length                           
  _txbuffer[4] := 3                                
  _txbuffer[5] := startAddr
  cs := (id + length + 3 + startAddr + h + l) ^ $ff    
  if length == 4
    _txbuffer[6] := l
    _txbuffer[7] := cs  
  if length == 5
    _txbuffer[6] := l
    _txbuffer[7] := h
    _txbuffer[8] := cs    
  _packetlength := length + 4   
  _mode := 1
  repeat until _mode == 0      

Dat                     '********** half duplex transmit/receive assembly routine for ax12 servos plugged into network **********

                        org     0
                        
entry                   'initialize 
                        mov     t1, par                  'read beginning address of hub variables that cog started with                       
                        add     t1, #8                   'read hub _axpin - setup propeller i/o bus communications on pin                          
                        rdlong  t2, t1                   '                                     
                        mov     pin, #1                  '                                                                                                        
                        shl     pin, t2                  '                                                                                                        
                        add     t1, #4                   'read hub _txptr                                                                                                        
                        rdlong  txbuff, t1               '                                                                       
                        mov     txhead, txbuff           'keep a copy
                        add     t1, #4                   'read hub _rxptr
                        rdlong  rxbuff, t1               '
                        mov     rxhead, rxbuff           'keep a copy                                                                               
                        add     t1, #4                   'read hub _timeout value                                                                                 
                        rdlong  timeout_, t1             '
                        add     t1, #8                   'read hub _bitticks value and setup variables
                        rdlong  bitticks_, t1            '
                        mov     txcnt, bitticks_         '
                        mov     rxcnt, bitticks_         '
                        mov     halfbit, bitticks_       'setup 1/2 bit period
                        shr     halfbit, #1              '
                        mov     modemask_, #3            'modemask_ = %0011
                                                                                                                                        
checktransmit           'check hub for transmission start signal                                                                                                                                         
                        mov     t1, par                  'read hub _mode value                                                                                    
                        add     t1, #4                   '                                                                                                        
:loop                   rdlong  mode_, t1                '                                                                                                        
                        test    mode_, modemask_ wc      'if hub _mode = 0, keep checking                                                                                                                                           
              if_nc     jmp     #:loop                   '
              '                                                                                                        
                        'initialize transmit & receive                                                                                                                                                                       
                        add     t1, #20                  'read hub _packetlength value                                                                            
                        rdlong  packetLength_, t1        '                                                                                                                            
                        mov     len, #4                  'set up loop counters                                                                                                         
                        mov     rxcnt2, #2               '                  
                        mov     timecount, timeout_      'reset timeout counter                                                                        
                        mov     txbuff, txhead           'reset buffer pointers
                        mov     rxbuff, rxhead           '
                        '
                        'transmit                                                                                   
                        or      outa, pin                'set pin high                                                                                   
                        or      dira, pin                'set pin to output                                  
:getnextbyte            rdbyte  axdata, txbuff           'get next byte to send from buffer                                                                      
                        add     txbuff, #1               'increment buffer pointer                                                                                                        
                        or      axdata, #$100            'add stop bit                                                                       
                        shl     axdata, #1               'add start bit                                                                                                        
                        mov     axbits, #10              '# of bits to send                                                                                                        
                        mov     txcnt, bitticks_         'reset txcnt
                        add     txcnt, cnt               'get start of bit periods 
:bit                    test    axdata, #1       wc      'get next bit into carry
                        muxc    outa, pin                'output bit
                        shr     axdata, #1               'shift to next bit
                        waitcnt txcnt, bitticks_         'wait for end of bit period          
                        djnz    axbits, #:bit            'output all bits                                                                                       
                        djnz    packetLength_, #:getnextbyte'output whole packet    
                        test    mode_, #1        wz      'if _mode <> 1 resetmode otherwise continue on to receive                                                                       
              if_z      jmp     #resetmode               '
                        andn    dira, pin                'set pin to input                                                                    

                        'receive  -  check for start bit                                                                                                                                                              
receive                 test    pin, ina         wc      'check pin state                                                                               
              if_nc     jmp     #:getByte                'if pin is low then get byte(start bit received)                                                                       
                        djnz    timecount, #receive      'continue checking until _timeout period exhausted                                                                      
                        jmp     #resetmode               'receive timed out - resetmode                                                                       
                                                                                                                                                                             
:getByte
                        add     rxcnt, cnt               'add start of bit periods for byte to rxcnt
                        add     rxcnt, halfbit           'add 1/2 bit period to sample in middle of bit time                            '
                        mov     axbits, #8               'how many bits to collect
                        
:bit                    
                        waitcnt rxcnt, bitticks_         'wait for bit period
                        test    pin, ina         wc      'get and rotate bit into memory
                        rcr     axdata, #1               '                                                    
                        djnz    axbits, #:bit            'get whole byte
                        waitpeq pin, pin                 'wait for stop bit                                                                                     
                        shr     axdata, #24              'trim and fit byte
                        wrbyte  axdata, rxbuff           'write received byte to rxbuffer                                                                          
                        add     rxbuff, #1               'increment rxbuffer pointer
                        mov     rxcnt, bitticks_         'reset rxcnt                                                                      
                        djnz    len, #receive            'receive 4 - last is packetlength byte
                        
                        'receive full packet length                                                             
                        add     len, axdata      wz      'set length of next capture, if 0 reset                                                                        
              if_z      jmp     #resetmode               'reset _mode to 0 and go back to wait for another transmission
                        djnz    rxcnt2, #receive         'finish getting packet
                                                                                                                
                        'reset transmit mode flag to 0                                                                                                                                       
resetmode               mov     t1, par                  'reset _mode to 0 and go back to wait for another transmission                                                     
                        add     t1, #4                   '                                                                                                        
                        wrlong  zero, t1                 '                                                                                                        
                        jmp     #checktransmit           '
                                                                                                                             
                                                         'variables                                                                                              
                                            
zero                    long    0

axbits                  res     1                                                                                            
axData                  res     1
bitticks_               res     1                                                                                            
rxbuff                  res     1
rxhead                  res     1
txbuff                  res     1
txhead                  res     1
halfbit                 res     1
len                     res     1
mode_                   res     1
modemask_               res     1       
packetLength_           res     1
pin                     res     1
rxcnt                   res     1
rxcnt2                  res     1
timecount               res     1     
timeout_                res     1
txcnt                   res     1
t1                      res     1
t2                      res     1

                        fit     496

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
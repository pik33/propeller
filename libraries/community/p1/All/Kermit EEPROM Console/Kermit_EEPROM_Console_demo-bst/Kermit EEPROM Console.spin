{{

┌──────────────────────────────────────────┐
│ Kermit EEPROM Console.spin               │
│ object that uses a serial                │
│ port for user input and for EEPROM load  │
│ Author: Eric Ratliff                     │               
│ Copyright (c) 2009, 2010 Eric Ratliff    │
│ See end of file for terms of use.        │                
└──────────────────────────────────────────┘

Kermit EEPROM Console.spin, object to load EEPROM from Kermit file send and act as user comman line serial driver
2009.5.5 by Eric Ratliff, based on FullDuplexSerial and SerialMirror
2009.5.31 Eric Ratliff, changing head/tail indicies from longs to words to allow instantaneous view of buffer status with long read
2009.7.19 Eric Ratliff, separating 'shall repeat' of Kermit parsing routine from its error codes
2009.7.30 Eric Ratliff, now works with ZTerm as well as Hyperterminal
2009.11.29 Eric Ratliff, adding way to tell if command is building up from input
                         fixed bug that "dec" did not correctly report success or failure
                         fixed bug with 'clearing of command ready' bit in ReadBytes, was actually clearing all bits of status flags
                         fixed bug with TryOutput clearing most bits of status flage
                         added timeout enabled versions of output routines
2010.1.10 Eric Ratliff, fixed bug with lock not being released when output buffer was full
2010.2..21 Eric Ratliff, version 1.0.9, edited some comments
                       , made "FileReceive" and "ProcessInput" private, now only call the public "Process" routine
}}

CON
  NoData      = -1 ' return code for no byte available
  Ascii_BS = 8
  Ascii_DEL = 127
  Ascii_CR = 13
  Ascii_Sp = 32
  IDCodeOffset = 1    ' constant that implements Lock and cog ID code code
  EchoMaxSize = 3 ' how many bytes may one characer's echo take up?  Worst case is backspace
  ProgramBaseVersion = 2000     ' this program's base version number, tells what program debugger is showing, version added below
  Extra = 0 ' puff up arrays in hopes of stopping wierd crashes

DAT

        CogID_Code    long 0    ' cod flag/id
        four_us_cl    long 0    ' 4 microseconds of time (clocks)

                                '9 contiguous longs
        rx_head       word 0    ' indicies of where we are in the receive buffer
        rx_tail       word 0
        tx_head       word 0    ' indicies of where we are in the transmit buffer
        tx_tail       word 0
        rx_pin        long 0
        tx_pin        long 0
        rxtx_mode     long 0
        bit_ticks     long 0
        buffer_ptr    long 0
        rx_peek_tail  long 0

                                'transmit and receive buffers
        rx_buffer     byte 0[128] ' SIZE may be a power of 2, must follow value of where overflow clip bit is 2 places below
        tx_buffer     byte 0[TxBufSize]
        dummy         long 0    ' marker to make file instances recognizeable as different
        LockID        long 0    ' is the number of the obtained lock.  is -1 if no lock obtained
        'OutputForKerminOnly long false ' flag to show that Kermit is in process, therefore no serial debug outputting

dat
  ' debug serial port variables
  DBrxPin long DummyInit ' where Propeller chip receives data
  DBtxPin long DummyInit ' where Propeller chip outputs data
  DBSerialMode long DummyInit ' bit 0: invert rx, bit 1 invert tx, bit 2 open-drain source tx, ignore tx echo on rx
  ' individual components of mode
  DBInvertRx long DummyInit
  DBInvertTx long DummyInit
  DBOpenDrainSourctTx long DummyInit
  DBIgnoreTxEchoOnRx long DummyInit
  DBbaud long DummyInit ' (bits/second)

PUB start(rxpin, txpin, mode, baudrate) : okay
'' Start serial driver - starts a cog and obtains a lock
'' returns true if successful
''
'' mode bit 0 = invert rx
'' mode bit 1 = invert tx
'' mode bit 2 = open-drain/source tx
'' mode bit 3 = ignore tx echo on rx

  okay := false ' pessimistic assumption

  stop
  longfill(@rx_head, 0, 2) ' reduced quantity from 4 to 2 when head & tail indicies were changed from longs to words
  longmove(@rx_pin, @rxpin, 3)  ' copy first three arguments to global variables
  bit_ticks := clkfreq / baudrate
  buffer_ptr := @rx_buffer
  four_us_cl := clkfreq / 250_000 ' pre compute constant for microsecond routine, 4 microseconds as clocks
  ' start an assembly cog that is the serial driver
  CogID_Code := cognew(@entry, @rx_head) + IDCodeOffset
  if CogID_Code ' did we get a cog for the serial driver?
    ' we did get a cog for the assembly serial driver
    ' try to get lock
    if (LockID := locknew)+1 ' did we get a lock?
      ' debug serial driver parameters
      DBrxPin := 31 ' 31 is for USB port
      DBtxPin := 30
      'DBrxPin := 7 ' 7 is for XBee port
      'DBtxPin := 6
      DBInvertRx := FALSE ' (does not matter, this program only transmits)
      DBInvertTx := FALSE ' (must be FALSE)
      DBOpenDrainSourctTx := TRUE ' I'm guessing this is for half duplex, such as 2 wire RS-485 (does not matter)
      DBIgnoreTxEchoOnRx := FALSE ' I'm guessing this is for half duplex, such as 2 wire RS-485 ( surprise, must be FALSE for transmit to work)
      DBSerialMode := (%1 & DBInvertRx)
      DBSerialMode |= (%10 & DBInvertTx)
      DBSerialMode |= (%100 & DBOpenDrainSourctTx)
      DBSerialMode |= (%1000 & DBIgnoreTxEchoOnRx)
      DBbaud := 57600
      'DebugSerialDriver.start(DBrxpin, DBtxpin, DBSerialMode, DBbaud)
      
      InputStatusFlags := 0 ' all flags cleared
      ' setup i2cobject so we can write to EEPROM
      i2cObject.Initialize(i2cSCL)
      nums.init ' numeric string interpretation setup
      'EEPROM_Wait_clk := DurationClksFromTmS(48) ' allow 4.8 ms for EEPROM writing to complete, initialize per clock frequency
      'EEPROM_Wait_clk := DurationClksFromTmS(43) ' allow 4.3 ms for EEPROM writing to complete, initialize per clock frequency
      EEPROM_Wait_clk := DurationClksFromTmS(50) ' allow 5.0 ms for EEPROM writing to complete, initialize per clock frequency
      ExpectedWriteTimeClk := DurationClksFromTmS(ExpectedWriteTimeTms) ' figure number of clocks expected for sending EEPROM write
      AllowedCallTimeClk := DurationClksFromTmS(40) ' figure number of clocks we want to allow for call to Recieve File routine
      'AllowedCallTimeClk := DurationClksFromTmS(400) ' greatly extend to allow debug prints
      ParseTimeMarginClk := DurationClksFromTmS(10) ' figure that one pass of parse loop might take this much time, conv from 1/10ths of ms (clocks)
      'if pDebug
      '  DisplaySimDurationClk := 0 ' no wait, we are debugging
      'else
      '  DisplaySimDurationClk := DurationClks(4) ' how long we wait to simulate a debugger running
      '  DisplaySimDurationClk := DurationClks(4) ' how long we wait to simulate a debugger running
      'AllowedCallTimeClk += DisplaySimDurationClk ' be more patient if we are absorbing the debugger delay time
      okay := true                                                                                                             
    else
      stop

PUB stop

'' Stop serial driver - frees a cog

  if CogID_Code
    cogstop(CogID_Code~ - IDCodeOffset)
    if LockID <> -1
      lockret(LockID)

CON
  ' results cases enueration
  KEC_RC_BufferEmpty = 0            ' nothing pending
  KEC_RC_GeneralByte = 1            ' one non special byte
  KEC_RC_Rubout      = 2            ' back space
  KEC_RC_kermitMark  = 3            ' beginning byte of a Kermit Packet

  LineLengthLimit = 40             ' maximum command line allowed
  LineIndexLimit = LineLengthLimit-1
  TxBufSizeL2 = 6 ' base 2 log of transmit buffer size, 6 gets size of 64
  TxBufSize = 1 << TxBufSizeL2 ' transmit buffer size (bytes)
  ' Input Status Masks, explains return value of ProcessInput, ReceiveFile
  KEC_ISM_CommandReady = %1                             ' a command has been received and is ready for use
  KEC_ISM_KermitPacketDetected = %10                    ' a Kermit file transfer has been started
  KEC_ISM_EEPROM_Dirty = %100                           ' writing the Kermit file to memory has started
  KEC_ISM_KermitCompleted = %1000                       ' writing the Kermit file to memory has successfully finished, ready to reboot
  KEC_ISM_AssertFailure = %10000                        ' programming error detected
  '  not implemented yet
  KEC_ISM_AllowKermit = %100000                         ' do detect and act on Kermit start signature
  KEC_ISM_WriteEEPROM = %1000000                        ' do write Kermit contents to EEPROM
  ' probably won't implement
  KEC_ISM_PauesOnAttributes = %10000000                 ' halts Kermit process on receipt of file attributes to allow inspection

DAT
LineMode byte false         ' flag to show we want command lines, other choice is single character input
DoEcho byte true        ' flag to show we want echoing of input
CommandBuffer byte 0[LineLengthLimit+Extra]                        ' secondary input buffer
CommandBufferIndex byte 0                       ' where we are in building a command line
EchoCount byte 0 ' how many single character commands we echoed since last CRLF
InputStatusFlags byte DummyInit   ' flags to show we have input ready for particular use, see "KEC" bit mapping masks above
pOutputArray long 0     ' pointer to monitored variables array for debugging to display

PUB SetCommandMode(UseCommandLines,EchoInput)
'' sets one of two user input modes, 'command lines' or single 'character commands' (default)
'' sets one of two user input echo modes, 'do echo' (default) or 'no echo'

  DoEcho := EchoInput
  if UseCommandLines            ' are we being asked to use lines?
    if LineMode                 ' are we presently using lines?
      ' no change
    else
      LineMode := true          ' record the new status
  else
    if LineMode                 ' are we presently using lines?
      ' we are abandoning line mode
      ' dump any partially collected command line
      CommandBufferIndex := 0
      LineMode := false         ' record the new status
      EchoCount := 0            ' assume we start with cursor at beginning of a new line
    else
      ' no change

PUB SetupDisplayDebugging(pTheOutputArray,pTheDebugStructure)
'' needed to enable showing variables live on screen
'' call BEFORE "start"
  pOutputArray := pTheOutputArray ' reccord pointer to general live variables to show on screen
  pDebug := pTheDebugStructure    ' record optional pointer to debugging structure
  if pDebug   ' is there a debug structure?
    LONG[pDebug][KDefs#KDB_pPacket] := @PacketInputBuffer                       ' report where packet input buffer is
    LONG[pDebug][KDefs#KDB_pFileOutput] := @EE_write_prep                       ' report where output buffer is    
    LONG[pDebug][KDefs#KDB_KR_VersionNumber] := ProgramBaseVersion + 109        ' 100 = 1.0.0 version
                 
PRI GeneralDebug(LongIndex,TheValue)
  if pOutputArray
    LONG[pOutputArray][LongIndex] := TheValue

PRI Echo(ByteToEcho)
  if DoEcho
    txPriv(ByteToEcho)

PUB GetCommandBufferIndex:QuantityInBuffer
'' shows how much of a command has been stored in the command buffer, builds up till user enters CR if in 'command line' mode
  QuantityInBuffer := CommandBufferIndex

PUB ReadBytes(pCallerCommandBuffer,pByteCount)|BufIndex
'' places command line in user provided buffer, carrige return & line feed not included, not null termainated
  if ProcessInput & KEC_ISM_CommandReady
    repeat BufIndex from 0 to CommandBufferIndex
      BYTE[pCallerCommandBuffer][BufIndex] := CommandBuffer[BufIndex]
    LONG[pByteCount] := CommandBufferIndex
    CommandBufferIndex := 0
    InputStatusFlags &= ! KEC_ISM_CommandReady ' clear the 'command ready' bit
  else
    LONG[pByteCount] := 0

PUB Process
'' look for input and process any file receive in progress
  if InputStatusFlags & KEC_ISM_KermitPacketDetected
    return ReceiveFile
  else
    return ProcessInput

PRI ProcessInput:Retval|InputByte,PI_StartTime
' tend the input so echo happens and backspaces, etc. work
  ShowInput := false ' for debugger, which may or may not be in use

  PI_StartTime := cnt
  ' deliberately delay to simulate having a debugger running
  'repeat until TimeYetDifferential(PI_StartTime,DisplaySimDurationClk)
    
  ' is a commmand already available?
  if InputStatusFlags & KEC_ISM_CommandReady
    ' do nothing now
  else
    ' attempt to get and lock output for maximum expected echo bytes
    if TryOutput(EchoMaxSize)
      ' get byte or special sequence
      case GetByte(@InputByte)
        ' nothing available
        KEC_RC_BufferEmpty :
          ' do nothing
        ' single non special byte
        KEC_RC_GeneralByte :
          if LineMode             ' are we building commnd lines?
            ' is this the end of command character?
            if InputByte == Ascii_CR
              InputStatusFlags |= KEC_ISM_CommandReady ' set the 'command ready' bit
              'CommandCount++
              if DoEcho
                localCRLF
            else
              ' length limit already met?
              if CommandBufferIndex => LineLengthLimit
                ' ignore this input byte
              else
                Echo(InputByte)        ' conditionally echo the input character
                ' save the input byte
                CommandBuffer[CommandBufferIndex++] := InputByte
          else
            Echo(InputByte)        ' conditioanlly echo the input character
            if InputByte == Ascii_CR
              EchoCount := 0
            else
              if ++EchoCount > LineIndexLimit
                if DoEcho
                  localCRLF
                EchoCount := 0
            ' copy byte to secondary buffer
            CommandBuffer[CommandBufferIndex++] := InputByte
            InputStatusFlags |= KEC_ISM_CommandReady ' set the 'command ready' bit
        KEC_RC_Rubout : ' backspace                                                     
          if LineMode             ' are we building commnd lines?
            ' anything in secondary buffer?
            if CommandBufferIndex
              Echo(Ascii_BS)        ' conditioanlly echo a backspace
              Echo(Ascii_Sp)        ' conditioanlly echo a space
              Echo(Ascii_BS)        ' conditioanlly echo a backspace
              ' reduce index to secondary buffer
              CommandBufferIndex--
            ' else
              ' do nothing
          else
            ' do nothing
        ' arrow sequence
          ' for now, not recognized as a sequence
        ' Kermit init  packet
        KEC_RC_kermitMark :
          InputStatusFlags |= KEC_ISM_KermitPacketDetected ' record that Kermit started
          CommandBufferIndex := 0 ' dump any command line that was in progress
      ' release lock on output
      ReleaseOutput
    else ' we could not get an output lock
      ' do nothing now
  Retval := InputStatusFlags
  
  if pDebug ' are we doing display debugging?
    ' post information for debugger to get
    LONG[pDebug][KDefs#KDB_ShowPacketResults] := false ' clear this in case file was just received, but no reboot
    LONG[pDebug][KDefs#KDB_ShowInput] := ShowInput
    LONG[pDebug][KDefs#KDB_FileDataCount] := 0 ' clear this in case file was just received, but no reboot
    if ShowInput
      LONG[pDebug][KDefs#KDB_PacketInputIndex] := 1
    else
      LONG[pDebug][KDefs#KDB_PacketInputIndex] := 0

PRI GetByte(pInputByte):ResultsCase|InByte
  ' note: we are not (yet) supporting 'sequences', all decisions are based on one byte
  ' so we (will in next object) determine Kermit starting by just the mark character
  ' also, this means no support of arrow keys because they come as two bytes
  ' returns results cases enueration
  InByte := rxPeek
  if InByte == NoData
    ResultsCase := KEC_RC_BufferEmpty
  else
    ' look for special bytes
    case InByte
      ' backspace or delete
      Ascii_BS, Ascii_DEL :
        ResultsCase := KEC_RC_Rubout
        rxAccept ' consume the byte from the receive buffer
        if pDebug ' are we doing display debugging?
          ShowInput := true ' for debugger, which may or may not be in use
          PacketInputBuffer[0] := InByte ' stow input byte where debugger can see it, expect to only store one before debugger gets it
      ' Kermit start
      KDefs#MARK :
        ResultsCase := KEC_RC_kermitMark
        'OutputForKerminOnly := true
      other:
        ResultsCase := KEC_RC_GeneralByte
        LONG[pInputByte]:= InByte
        rxAccept ' consume the byte from the receive buffer
        if pDebug ' duplicated from above inline for speed
          ShowInput := true ' for debugger, which may or may not be in use
          PacketInputBuffer[0] := InByte ' stow input byte where debugger can see it, expect to only store one before debugger gets it

PRI rxPeek : rxbyte
' Check if byte received (never waits)

  rxbyte := NoData
  if rx_tail <> rx_head
    rxbyte := rx_buffer[rx_tail]

PRI rxAccept
' advance receive tail one byte to acknowledge consumption of byte
  rx_tail := (rx_tail + 1) & $7F                      ' must match SIZE of receive buffer, sF for 16 byte buffer, s7F for 128 byte buffer

PRI Rx : rxbyte
' get byte if available, no waiting
  rxbyte := rxPeek
  if rxbyte <> NoData
    rxAccept

PRI TryOutput(SizeRequested):OK_to_transmit
' tries to get use of the transmit resource and verifies that there is the requested room in the output buffer
  if not (InputStatusFlags & KEC_ISM_KermitPacketDetected) ' is Kermit not running?
    ' try to tie up the lock
    OK_to_transmit := TryOutputK(SizeRequested)
  else
    OK_to_transmit := false

PRI TryOutputK(SizeRequested):OK_to_transmit
' tries to get use of the transmit resource and verifies that there is the requested room in the output buffer
' only for calling by Kermit process or when Kermit is not happening
  ' try to tie up the lock
  if LOCKSET(LockID)
    ' some other cog has the lock, this one does not
    OK_to_transmit := false
  else
    ' this cog has now use of the transmit resource
    if TxBufAvailable => SizeRequested ' is there the requested room in the buffer?
      OK_to_transmit := true
    else
      ReleaseOutput ' give back the lock
      OK_to_transmit := false

PRI ReleaseOutput
' only call this if the calling cog has the resource
' do call this when finished putting output into the output buffer
  LOCKCLR(LockID)

PRI TxBufAvailable:remaining
' how much space is left in the transmit buffer
  remaining := TxBufSize - ((tx_head-tx_tail) & TxSizeMask) + 1

PRI txPriv(txbyte)

'' Send byte (may wait for room in buffer)

  repeat until (tx_tail <> (tx_head + 1) & $F)
  tx_buffer[tx_head] := txbyte
  tx_head := (tx_head + 1) & TxSizeMask

PUB GetBufIndiciesAddress ' changed routine name from GetControlStructure to GetBufIndiciesAddress to signal that we now use word sized indicies, no longer long sized
'' allows external program to monitor buffer fullness
  return @rx_head

OBJ
' Kermit related coding begins here
  KDefs : "KermitConsoleDefs"
  nums : "Numbers"
  i2cObject      : "basic_i2c_driver"
  ' 'DebugSerialDriver : "SerialMirror"                        ' to 2nd com port, for missing output problem
  'DebugSerialDriver : "FullDuplexSerial128"                        ' to 2nd com port, for missing output problem

CON
  'PaketTimeout_ms = 1000 ' timeout for giving up on a packet (ms) see instead "AgreedTimeoutClk"
  LenSeqField = 1               ' length of the sequence field
  LenTypeField = 1              ' length of the type field
  LenFieldIndex = 1             ' index of packet length in a Kermit packet
  SeqFieldIndex = 2             ' index of sequence number in a Kermit packet
  PayloadPrefixLength = SeqFieldIndex + IndexToLength + LenTypeField
  NonDataBytesInDataPacket = PayloadPrefixLength + numCheckSumChars + numEOLchars
  FN_index = 4                  ' file name start index in file header packet
  TimeoutIndex = 5              ' where in send InitProcess and InitProcess ack the timeout parameter is
  'FLD_index = 8                ' file length digit count index in file attributes packet
  'FL_index = FLD_index + 1     ' file length first character index in file attributes packet
  numEOLchars = 1               ' number of line end characters used
  numCheckSumChars = 1          ' here we assume type 1 checksums, one character
  MinSeqNum = 0                 ' Kermit minimum packet length for sequence, type, and checksum
  MaxSeqNum = 63                ' max allowable Kermit sequence number
  PrintableOffset = $20         ' value added to quantiteis to get printable character to send/receive
  DataLinkPrefixLength = 2      ' includes mark and length fields
  MinPacketLength = DataLinkPrefixLength + numCheckSumChars ' Kermit minimum packet length for sequence, type, and checksum (expect 3)
  MaxPacketLength = 96          ' Kermit max packet length, includes mark through the checksum, i.e. the max data link packet size
                                ' see pages 15, 27, 28 of "Kermit" from Byte magazine 1983
  MaxReminingChars = MaxPacketLength - DataLinkPrefixLength ' page 28 explains why this should is 94
  MaxPacketStringLength = (LenFieldIndex+IndexToLength)+MaxPacketLength+numEOLchars
  IndexToLength = 1 ' add this to index to find quantity with zero based arrays
  NULL = 0                      ' string terminator
  EOL = $d                      ' expect carrige return as end of line character
  PrimaryFileNameBufferSize = 50' maximum usable file name (bytes including null terminator)
  FileLengthLimit = $1_00_00    ' allow only for files this long in the event that a length is not declared by sender, $1_00_00 = 64K
  LengthNotKnown = -1           ' code value to show we do not know file length also for file name length
  AttrBufLen = 40               ' attribute buffer length (bytes)
  StringGetFailed = -1          ' code for failure to get attribute string

  ' file receive step enumeration
  FRS_Init = 0
  FRS_GetSendInit = 1
  FRS_FileHeader = 2
  FRS_FileAttributes = 3
  FRS_DumpingMacBinary = 20     ' alternate way to get file attributes, when coming from ZTerm running on a Mac
  FRS_FileData = 4
  FRS_EOF = 5
  FRS_EOT = 6
  FRS_CheckLen = 7
  FRS_ForceTerminate = 9            ' not quite the same as the "FRP_CallerForcingTermination" state in KermitReceiver, but similar
                                    ' also a bit like "FRP_ProcessForcingTermination" state in KermitReceiver
                                    ' a preliminary to probable sending of error padket instead of ACK/NAK
                                    ' we will clear the "KEC_ISM_KermitPacketDetected" bit of the "InputStatusFlags" if file receive fails
  ' only allow this many data packets with no file data before declaring an error condition, Allow some for Mac send end paddiing
  ExtraDataPacketTolerance = 3
  MacBinaryFileSizeLSBIndex = 86' where in MacBinary header the least significant byte of file size is
  ' EEPROM related
  DummyInit = 0 ' for DAT Spin variables, where we don't need to initialize them
  i2cSCL        = 28            ' SCL pin connected to startup EEPROM of the prop chip
'  i2cSDA        = 29           ' implied by using the "basic_i2c_driver" 
  EEPROMAddr    = %1010_0000    ' which chip on I2C bus to use  
  EEPROM_Base     = $0000       ' starting address within chip
  EEPROM_WriteSize = 4         ' how much data we will store at once in EEPROM

DAT
  pDebug long 0        ' where to find debug structure for dedicated debugging display routing
  KermitParseStep byte DummyInit        ' where we are in a Kermit packet parse
  PacketInputBuffer byte DummyInit[MaxPacketStringLength+5+Extra]' where incoming packet is, not null terminated, having buffer here saves space and ensures globality
  PacketStartTime long DummyInit        ' when we started getting this packet (clocks)
  ' duplicate meaning!!! PacketSequenceNumber long DummyInit   ' actual packet sequence number from incoming packet
  ExpectedSequence long DummyInit       ' expected packet sequence number from incoming packet
  PakType long DummyInit             ' declared packet type from incoming packet
  PaketTimeout_clk long DummyInit       ' timeout for giving up on a packet (ms)
  PacketInputIndex long 0       ' where in packet buffer the current character goes
  ThisNewChar long DummyInit            ' long code for byte input error or byte value
  DeclRemainingLength long DummyInit    ' declared length in packet, bytes to come after the length field, less EOL (I think)
  CountedRemainingLength long DummyInit ' measured length after length field
  ParsedPakErrCode long DummyInit       ' result of Kermit Packet parsing
  AgreedTimeoutSec long DummyInit       ' lesser of sender's suggested timeout or our init packet's timeout (seconds)
  AgreedTimeoutClk long DummyInit       ' chosen packet timeout (clocks)
                                        ' combination of modes and state of File Receive process
  NeedPacket byte false                   ' flag to show we are in the 'parse packet' mode of the File Receive process
  ForceTerminate byte DummyInit           ' flag to show another mode of File Receive process, receiver is ending the transfer
  FileReceiveStep long FRS_Init              ' state (as opposed to 'mode') of the File Receive process, mostly sequential values
  DeclaredSeqNum long DummyInit         ' sequence number appearing in a packet
  ProcessHasError byte DummyInit        ' flag to show the last packet was 'bad'
  ErrorStartTime long DummyInit         ' when we last had no error (clocks)
  ProcessErrorTimeout long DummyInit    ' how long we will tolerate bad packets (clocks)
  DeclaredFileSize long KDefs#NoFileLength     ' code for known/not known and declared size of file in bytes
  FileLengthGuessed long false                  
  MeasuredFileLength long DummyInit     ' measured, as opposed to declared, size of received file (bytes)
  QCTL long DummyInit                   ' quote control character used in this Kermit file transfer, typically (pound sign?)
  REPT long DummyInit                   ' quote character for repeats, typically (?)
  ShowPacketResults long DummyInit      ' flag to incidate need to refresh debug display for packet results
  ShowInput long DummyInit              ' flag to incidate need to refresh debug display for input characters
  FileDataCount long DummyInit          ' flag to incidate need to refresh debug display for file data
  FileNameLength long LengthNotKnown    ' file name length declared by sender
  LimitedFileNameLength long DummyInit  ' length of file name as given by sender limited to size that will fit in 'primary' buffer
  PassedNameLength long DummyInit       ' length of file name further limited by size of remote buffer provided by caller
  PrimaryFileNameBuffer byte DummyInit[PrimaryFileNameBufferSize+Extra] ' first place we store file name
  FileDataStopLimit long DummyInit
  MBDumped long DummyInit               ' how many bytes of decoded bytes were dumped as 'MacBinary' header bytes so far
  'IsMBHeader long DummyInit             ' flag used between two (?) routines to determine if examined packet is a MacBinary header
  AttributeBuffer byte DummyInit[AttrBufLen+Extra]
  ExtraDataPacketCount long DummyInit   ' how many data packets do not have any file data
  
  ' Kermit response packet strings
  General_NAK
        byte  $01,$23,$20,KDefs#PT_NAK_type,$3d,$0d,$00       ' type N
  InitAck
        byte $01,$2D,$20,KDefs#PT_ACK_type,$7e,$39,$20,$40,$2D,$23,$4e,$31,$7e,$28,$40,$0D,$00 ' timeout 25 seconds
        'byte $01,$2D,$20,KDefs#PT_ACK_type,$7e,$21,$20,$40,$2D,$23,$4e,$31,$7e,$28,$40,$0D,$00 ' timeout 1 seconds
  General_ERROR
        byte  $01,$23,$20,KDefs#PT_Error_type,$3d,$0d,$00       ' type E
  General_ACK
        byte  $01,$23,$20,KDefs#PT_ACK_type,$3d,$0d,$00       ' type Y

  ' for writing to EEPROM
  EE_write_prep byte DummyInit[EEPROM_WriteSize+Extra]        ' buffer to write EEPROM data from in a whole block, a preparation 'pre load' buffer
  ReadBackRegister byte DummyInit[EEPROM_WriteSize+Extra]     ' buffer to read EEPROM data into for checcking
  ReadError long DummyInit      ' how many times EEPROM could not be read
  ReadbackByteErrors long DummyInit ' how many bytes of EEPROM did not agree with what was written
  PrepBufIndex long DummyInit                           ' where in EEPROM pre load buffer we should put a byte
  EEPROM_Wait_clk long DummyInit                ' duration of wait for EEPROM write to finish
  WhenReadyForNextWrite long DummyInit          ' expiration time indicating we can write to EEPROM again
  ActuallyWritingEEPROM long true          ' shows that we are writing data packets to EEPROM, not just letting caller consume in sync thru debug interface
  eepromLocation long DummyInit                 ' where within this particular EEPROM we are currently writing
  ClearBeforeShowing long DummyInit             ' flag to cause debugger screen to mostly clear before refreshing
  EverShowedFRP long false                      ' to show that possible debugger screen has showed some file receive process steps, and may need clearing
  SentTry long 0
  ReceiveFileStartTime long DummyInit           ' when we entered the ReceiveFile routine (clocks)

  LongTimeDebug long 0 ' where to show this debug series
  StartingFRS long DummyInit
  StartingKPS long DummyInit
  StartingNeedPacket long DummyInit
  LongPassEndTimeClk long DummyInit
  ParseTimeMarginClk long DummyInit ' how much time we think a parse loop execution may take (clocks)
  'DisplaySimDurationClk long DummyInit
  MaxCall5Time long DummyInit   ' max time packet parse step 5 takes (clocks)
  FileLengthFromMB long DummyInit        ' declared file length from MacBinary header, starts as working sum, finishes as final sum
  PadBytes long DummyInit       ' quantity of bytes found after declared file size

PRI ReceiveFile: ResultCode
' this does the calling of parse packet alternating with using the packet
' call this until time to reboot, or until internally or externally aborted
' works in a 8 step rentrent process
' intended to be moderately fast, fast enough to share 100 Hz control loop

  ReceiveFileStartTime := cnt ' record when we started in attempt to limit time taken by delaying deferrable actions
  
  ShowPacketResults := false ' only refresh debug screen once per completion of a file process step
  ShowInput := false ' may also use this for console input
  FileDataCount := 0 ' don't let debugger show the same file data twice, and just plain initialize
  ClearBeforeShowing := false ' a debugging flag, make sure we don't clear the data last displayed

  if pDebug
    ' to see what calls are taking many milliseconds
    'LongPassEndTimeClk:=StartTiming(DurationClks($9))
    LongPassEndTimeClk:= ReceiveFileStartTime + AllowedCallTimeClk + DurationClksFromTmS(10)
    GeneralDebug(LongTimeDebug+4,AllowedCallTimeClk)
    StartingNeedPacket := NeedPacket 
    StartingFRS := FileReceiveStep
    StartingKPS := KermitParseStep

  ' separate two broad categories of file receive process state, parsing a new packet, and processing the last received packet
  if NeedPacket
    'if ExpectedSequence == 2  ' 2 still allows mark here
    '  repeat ' hang here
    ' deliberately delay to simulate having a debugger running
    'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
    ''DebugSerialDriver.str(STRING("Calling Parse exp seq="))
    ''DebugSerialDriver.str(nums.ToStr(ExpectedSequence,nums#HEX))
    ''DebugSerialDriver.str(STRING(" pii="))
    ''DebugSerialDriver.str(nums.ToStr(PacketInputIndex,nums#HEX))
    ''DebugSerialDriver.str(STRING(" KPS="))
    ''DebugSerialDriver.str(nums.ToStr(KermitParseStep,nums#HEX))
    ''DebugSerialDriver.CRLF
    'if ExpectedSequence == 3 ' finished showing the attributes packet, about to look for file packet
    '  repeat ' hang here
    ParseKermitPacket ' try to get a Kermit Packet
    if KermitParseStep == KPS_Init ' is packet done or abandoned?
      NeedPacket := false ' on next call of this routine, we will process this packet
      ShowInput := true       ' do show this packet
    ' note no change of results code from when routine was entered, that will only happen when we evaluate the packet get results
    ''DebugSerialDriver.str(STRING("pii="))
    ''DebugSerialDriver.str(nums.ToStr(PacketInputIndex,nums#HEX))
    ''DebugSerialDriver.str(STRING(" Ec="))
    ''DebugSerialDriver.str(nums.ToStr(ParsedPakErrCode,nums#HEX))
    ''DebugSerialDriver.CRLF
    'if ExpectedSequence == 2 ' stop after attributes packet, 'no timeout' is set in parsing
    '  repeat ' hang here
    'if ExpectedSequence == 3 ' stop after 1st data packet, 'no timeout' is set in parsing
    '  repeat ' hang here
  else
    'if ExpectedSequence == 3
    '  repeat ' hang here
    ' deliberately delay to simulate having a debugger running
    ' process and ACK/NAK a Kermit file packet
    ' fine categories of file receive process state
    case FileReceiveStep   
      FRS_Init : ' initialize process of getting a file
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive0
      FRS_GetSendInit : ' get send init packet
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive1
      FRS_FileHeader : ' look for file header packet
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive2
      FRS_FileAttributes : ' look for file attributes packet
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive3
      FRS_FileData : ' receive file data
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive4               
      FRS_EOF : ' look for end of file packet
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive5
      FRS_EOT : ' look for end of transmission packet
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive6
      7 : ' check file length & go back to command mode
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive7
      FRS_ForceTerminate : ' receiver forcing termination
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceiveTerminate
      FRS_DumpingMacBinary : ' alternate step 3, read MacBinary header
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        FileReceive3mb
      other:
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        InputStatusFlags |= KEC_ISM_AssertFailure ' add assert failure, programming error detected, to status flags

  if ProcessHasError          ' any process errors?
    if (cnt - ErrorStartTime) => ProcessErrorTimeout              ' fractionally more than one of sender's timeouts expired?
      FileReceiveStep := ForceTerminate ' set up to send error packet whatever packet comes next, or if next packet times out
      'repeat ' hang here

  if pDebug
    ' post information for debugger to get
    LONG[pDebug][KDefs#KDB_ShowPacketResults] := ShowPacketResults
    LONG[pDebug][KDefs#KDB_ShowInput] := ShowInput
    LONG[pDebug][KDefs#KDB_FileDataCount] := FileDataCount
    LONG[pDebug][KDefs#KDB_PacketInputIndex] := PacketInputIndex
    LONG[pDebug][KDefs#KDB_DeclPacketLength] := DeclRemainingLength + LenFieldIndex + IndexToLength + numEOLchars
    LONG[pDebug][KDefs#KDB_ExtrSequenceNumber] := DeclaredSeqNum
    ' ectracted checksum: posted elsewhere
    ' calculated checksum: posted elsewhere
    LONG[pDebug][KDefs#KDB_InputStatusFlags] := InputStatusFlags
    LONG[pDebug][KDefs#KDB_PakType] := PakType
    LONG[pDebug][KDefs#KDB_PacketErrorCode ] := ParsedPakErrCode
    LONG[pDebug][KDefs#KDB_FileState] := FileReceiveStep
    LONG[pDebug][KDefs#KDB_ParseState] := KermitParseStep
    ' DeclaredFileSize: accessed by debugger via function call
    LONG[pDebug][KDefs#KDB_MeasuredFileLength] := MeasuredFileLength
    LONG[pDebug][KDefs#KDB_ClearBeforeShowing] := ClearBeforeShowing
    ' to see what is slow
    if TimeYet(LongPassEndTimeClk) 'and StartingFRS == 4'StartingKPS == 5
      GeneralDebug(LongTimeDebug+0,StartingNeedPacket)
      GeneralDebug(LongTimeDebug+1,StartingFRS)
      GeneralDebug(LongTimeDebug+2,StartingKPS)
      GeneralDebug(LongTimeDebug+3,KermitParseStep)

  ResultCode := InputStatusFlags ' return the 'input status flags'                                                            
  'if ExpectedSequence == 2  ' 2 stops mark here
  '  repeat ' hang here

PUB GetFileAttributes(pFileNameBuffer,FileNameBufferSize,pFileLength):NameKnown 
'' returns true when file name is known
'' saves non negative file length when that is known
  if FileNameLength <> LengthNotKnown  ' make sure file name length has been calculated
    'if LimitedFileNameLength + 1 > FileNameBufferSize
    '  FileNameLength := FileNameBufferSize - 1
    PassedNameLength := LimitedFileNameLength <# (FileNameBufferSize-1)
    CopyBytes(@PrimaryFileNameBuffer,pFileNameBuffer,PassedNameLength)
    BYTE[pFileNameBuffer][PassedNameLength] := NULL ' make this a null terminated string
    NameKnown := true
  else
    BYTE[pFileNameBuffer][0] := NULL ' make this an empty null terminated string
    NameKnown := false
  if FileLengthGuessed
    LONG[pFileLength] := KDefs#NoFileLength
  else
    LONG[pFileLength] := DeclaredFileSize

PRI FileReceive0
' initialize process of getting a file
  ' make sure we have a detected Kermit packet start
  if not InputStatusFlags & KEC_ISM_KermitPacketDetected
    InputStatusFlags |= KEC_ISM_AssertFailure ' add assert failure, programming error detected, to status flags
    return

  ' only do initialization when the Kermit process has control of the output
  if TryOutputK(0) ' try to get the output resource, don't worry about space available at the moment, zero bytes OK
    FileNameLength := LengthNotKnown ' do this right away, the un-locked calls to GetFileAttributes could be at bad timing
    ExpectedSequence := MinSeqNum
    ResetProcessErrorTimeout
    MeasuredFileLength := 0
    DeclaredFileSize := KDefs#NoFileLength ' we do not know the file length
    PaketTimeout_clk := DurationClks(500) ' default timeout, applies to init packet, converts from ms to clocks
    'ReadyToShowFirstPacket := true
    'GotFileLength := false
    'ExtraDataPacketCount := 0
    ProcessHasError := false
    ForceTerminate := false
    NeedPacket := true ' get ready to parse the waiting Kermit packet
    ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
    PrepBufIndex := 0           ' no decoded & RLE characters in EEPROM preparation buffer
    ExtraDataPacketCount := 0   ' no mal formed file data packets (no data) encountered yet
    WhenReadyForNextWrite := StartTiming(EEPROM_Wait_clk) ' pessimistically assume that very last thing that happened was an EEPROM write
    eepromLocation := EEPROM_Base ' initialize where in this EEPROM we will start writing
    ClearBeforeShowing := EverShowedFRP
    EverShowedFRP := true
    ReadError := 0 ' no EEPROM readback errors yet
    ReadbackByteErrors := 0 '  how many EEPROM bytes are incorrect, we konw of none yet
    DataPacket_ProcessState := DataPacket_Init ' show that we are ready to handle a data packet
    DecodeProcessState := Decode_PS_Init ' show that we are ready to decode new file data
    KermitParseStep := 0 ' make sure we start parsing anew on each file send
    MaxCall5Time := 0
    FileLengthGuessed := false
    PadBytes := 0
    FileReceiveStep := FRS_GetSendInit ' advance to next file receive process step, get send init packet

PRI FileReceive1
' get send init packet
  'repeat ' hang here
  'GeneralDebug(4,PrimaryFileNameBuffer)
  'GeneralDebug(5,@PrimaryFileNameBuffer)
  if ParsedPakErrCode ==  KDefs#PEC_KermitPacketReady ' no problem detected with the packet?
    case PakType          ' branch depending on packet type
      KDefs#PT_SendInitiate_type :                   ' this is the expected type
        ' MAXL :=  ' maximum remaining characters, up to 94, value after un character function
        ' choose lower timeout, sender's suggested timeout or our ACK value (seconds)
        AgreedTimeoutSec := UnChar(PacketInputBuffer[TimeoutIndex]) <# InitACK[TimeoutIndex]
        AgreedTimeoutClk := AgreedTimeoutSec * clkfreq ' chosen timeout (clocks)
        PaketTimeout_clk := AgreedTimeoutClk ' not using a fast timeout for packets as in previous implementation
        ProcessErrorTimeout := AgreedTimeoutClk + AgreedTimeoutClk >> 4         ' 125% of agreed timeout
        QCTL := PacketInputBuffer[9] ' get the quote character for control and prefix charactera
        'QBIN := PacketInputBuffer[10] ' get the quote character for binaries
        REPT := PacketInputBuffer[12] ' get the quote character for repeats

        PrepAndSend(@InitAck,ExpectedSequence) ' tell sender our time out period
        'repeat ' hang here
        ResetProcessErrorTimeout

        FileReceiveStep := FRS_FileHeader ' advance to next file receive process step, look for file header packet
        'ReadyToShowFirstPacket := true              ' be sure the clear below works any time we are debugging
        ' if we just got or failed while trying to get a file, set up to clear debugger screen on next data
        'ClearDebuggerScreen
        ExpectedSequence := FollowingSeqNum(ExpectedSequence) ' increment or wrap sequence number
      KDefs#PT_Error_type :   ' early termination from sender, not sure this ever happens
        ExternalShutdownFileReceive
      OTHER :             ' not expected packet type
        NAK_Note_Need_Refresh
    NeedPacket := true ' start looking for another Kermit packet
    ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
  else
    NAK_Note_Need_Refresh

PRI ExternalShutdownFileReceive
  ' handle possibility that sender sends error code
  InputStatusFlags &= ! KEC_ISM_KermitPacketDetected ' clear the kermit in process bit, so we go back to command mode
  'repeat ' hang here
                                                               
PRI FileReceive2
' looking for file header packet
  'repeat ' hang here
  if ParsedPakErrCode ==  KDefs#PEC_KermitPacketReady ' no problem detected with the packet?
    case PakType        ' branch depending on packet type
      KDefs#PT_FileHeader_type :   ' we expect this for files from Hyperterminal or ZTerm                                                             
        ResetProcessErrorTimeout                      ' this was an acceptable type
        ' extract and post file name                                                         
        ' calculate length of file name
        FileNameLength := PacketInputIndex - FN_index - numEOLchars - numCheckSumChars
        if FileNameLength < 1 ' do not accept unnamed files
          FileReceiveStep := FRS_ForceTerminate
        else
          LimitedFileNameLength := FileNameLength <# PrimaryFileNameBufferSize                ' file name size that will fit in buffer
          ' copy file name out of packet into the file name buffer
          CopyBytes(@PacketInputBuffer[FN_index],@PrimaryFileNameBuffer,LimitedFileNameLength)
          PrepAndSend(@General_ACK,ExpectedSequence)
          FileReceiveStep := FRS_FileAttributes ' advance to next file receive process step, look for file attributes packet
      KDefs#PT_Error_type :   ' early termination from sender, not sure this ever happens
        ExternalShutdownFileReceive
      OTHER :                                       ' unsupported packet type
        ProcessHasError := true                 ' this packet type not supported or expected, don't tolerate much of this
        ' a 'yes sir, don't rock the boat' answer, to pass unused unsupported operations        
        PrepAndSend(@General_ACK,ExpectedSequence)
    ExpectedSequence := FollowingSeqNum(ExpectedSequence) ' increment or wrap sequence number
    NeedPacket := true ' start looking for another Kermit packet
    ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
    'repeat 2' hang here    (gets no mark if infinite) (gets mark if just 2)
  else ' packet had error
    NAK_Note_Need_Refresh
  

PRI FileReceive3 '| NewStringLength
' look for file attributes packet
  'strK(STRING("got to file receive 3")) ' to see in serial port monitor, do not expect to see in terminal screen
  'repeat ' hang here

  if ParsedPakErrCode ==  KDefs#PEC_KermitPacketReady ' no problem detected with the packet?
    case PakType        ' branch depending on packet type
      ' put the most frequent packet type first to speed the case statement execution
      KDefs#PT_Data_type : ' we may get file data or MacBinary header
        ResetProcessErrorTimeout                                           ' this was an acceptable type
        ' no file attributes packet means we may be getting from ZTerm on a Mac
        ' is the encoded data a Mac Binary Header?
        ' do not expect any run length encoding from ZTerm
        ' expect first decoded bytes in payload of packet to be 0 and then the length of the file name in binary
        '     possible problem is file name has spaces, ZTerm user must set 'send unmodified'
        ' make sure there were enough bytes to decode
        if DeQuote(PacketInputBuffer[5]) == 0 and DeQuote(PacketInputBuffer[7]) == FileNameLength and PacketInputIndex => 10
          MBDumped := 0                ' ignore the two decoded characters dumped so far
          FileReceiveStep := FRS_DumpingMacBinary ' handle this packet as a mac binary to ACK, evaluate and dump on next pass
          'DebugSerialDriver.str(STRING("Dumping mb"))
          'DebugSerialDriver.CRLF
        else
          ' now need to use this packet as file data, consider that we don't have a declared file length
          FileLengthGuessed := true ' don't allow reporting of guessed file size to caller
          DeclaredFileSize := FileLengthLimit   ' calculate where to last convert input to file data, prevents a buffer over run situation
          FileReceiveStep := FRS_FileData ' just go handle this packet as a file data packet on next pass
          'DebugSerialDriver.str(STRING("Not mb: 5="))
          'DebugSerialDriver.str(nums.ToStr(DeQuote(PacketInputBuffer[5]),nums#HEX))
          'DebugSerialDriver.str(STRING(" 7="))
          'DebugSerialDriver.str(nums.ToStr(DeQuote(PacketInputBuffer[7]),nums#HEX))
          'DebugSerialDriver.str(STRING(" name len="))
          'DebugSerialDriver.str(nums.ToStr(FileNameLength,nums#HEX))
          'DebugSerialDriver.str(STRING(" pii="))
          'DebugSerialDriver.str(nums.ToStr(PacketInputIndex,nums#HEX))
          'DebugSerialDriver.CRLF
      KDefs#PT_FileAttributes_type :
        if GetAttributes(@PacketInputBuffer,PacketInputIndex)
          ResetProcessErrorTimeout
          PrepAndSend(@General_ACK,ExpectedSequence)
          'if ExpectedSequence == 2
          '  repeat ' hang here
          NeedPacket := true ' start looking for another Kermit packet
          FileReceiveStep := FRS_FileData ' advance to next file receive process step, look for file attributes packet
          ExpectedSequence := FollowingSeqNum(ExpectedSequence) ' increment or wrap sequence number
        else
          FileReceiveTerminate ' we don't want a re-send of this packet that is something that we cannot read
      KDefs#PT_Error_type :   ' early termination from sender, not sure this ever happens
        ExternalShutdownFileReceive
      OTHER :                                       ' unsupported packet type
        ProcessHasError := true                 ' this packet type not supported or expected, don't tolerate much of this
        ' a 'yes sir, don't rock the boat' answer
        PrepAndSend(@General_ACK,ExpectedSequence)
    'ExpectedSequence := FollowingSeqNum(ExpectedSequence) ' increment or wrap sequence number
    ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
  else ' packet had error
    NAK_Note_Need_Refresh 

PRI FileReceive3mb | IsDone,pPayload
  ' note: this takes up to 8.6 milliseconds to execute (including external call), violating the 4 millisecond call time limit
  'DebugSerialDriver.str(STRING("3mb pii="))
  'DebugSerialDriver.str(nums.ToStr(PacketInputIndex,nums#HEX))
  'DebugSerialDriver.str(STRING(" Ec="))
  'DebugSerialDriver.str(nums.ToStr(ParsedPakErrCode,nums#HEX))
  'DebugSerialDriver.str(STRING(" exp seq="))
  'DebugSerialDriver.str(nums.ToStr(ExpectedSequence,nums#HEX))
  'DebugSerialDriver.CRLF

  ' not sure how I want to code this

  ' still need to ACK the data packet...

  ' want to move "MacBinaryDumpDone" code to here

  ' probably need to test packet type
  
  if ParsedPakErrCode ==  KDefs#PEC_KermitPacketReady ' no problem detected with the packet?
    case PakType          ' branch depending on packet type
      KDefs#PT_Data_type :                   ' this is an expected type
        PrepAndSend(@General_ACK,ExpectedSequence)
        pPayload := @PacketInputBuffer[0] + PayloadPrefixLength
        Decode_InputIndex := 0       ' start at first input byte
        IsDone := false               ' start by assuming this is NOT the last MacBinary header byte
        'Decode_InputBatchSize := PacketInputIndex - NonDataBytesInDataPacket - MBDumped
        Decode_InputBatchSize := PacketInputIndex - NonDataBytesInDataPacket
        ' only decode as many input characters as we have in this packet
        repeat until InputExhausted
          if BYTE[pPayload][Decode_InputIndex] == QCTL           ' is this character the quote for control and prefix characters?
            Decode_InputIndex++              ' advance to the escaped value location, the quote character will not be part of the output
            'DebugSerialDriver.str(STRING("D="))
            'DebugSerialDriver.str(nums.ToStr(MBDumped,nums#DEC))
            'DebugSerialDriver.str(STRING(" "))
            'DebugSerialDriver.str(nums.ToStr(DeQuote(BYTE[pPayload][Decode_InputIndex]),nums#HEX))
            'DebugSerialDriver.CRLF
            ReadFileLength(DeQuote(BYTE[pPayload][Decode_InputIndex]),MBDumped)
          else
            ' this must be just a regular character, not quoting or repeating
            ' output one character
            'DebugSerialDriver.str(STRING("d="))
            'DebugSerialDriver.str(nums.ToStr(MBDumped,nums#DEC))
            'DebugSerialDriver.str(STRING(" "))
            'DebugSerialDriver.str(nums.ToStr(BYTE[pPayload][Decode_InputIndex],nums#HEX))
            'DebugSerialDriver.CRLF
            ReadFileLength(BYTE[pPayload][Decode_InputIndex],MBDumped)
          Decode_InputIndex++      ' increment place within this packet
          MBDumped++                ' count this one character for total dumping
          ' should we stop decoding this packet early?
          if MBDumped == 128          ' will next byte be beyond Mac header?
            IsDone := true
            'DebugSerialDriver.str(STRING("Done, exp seq="))
            'DebugSerialDriver.str(nums.ToStr(ExpectedSequence,nums#HEX))
            'DebugSerialDriver.CRLF
            quit ' get out of loop so that we stop dumping header characters, remainder may exist and be file data
        if IsDone  ' have we finished dumping the mac binary?
          if InputExhausted ' did we happen to run out of input at same time Mac Binary is fully dumped?
            ' we must have run out of input
            NeedPacket := true
            ExpectedSequence := FollowingSeqNum(ExpectedSequence) ' increment or wrap sequence number
            ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
            DataPacket_ProcessState := DataPacket_Init
            'DebugSerialDriver.str(STRING(" also exhausted"))
            'DebugSerialDriver.CRLF
          else
            DataPacket_ProcessState := DataPacket_InPakInit
            'DebugSerialDriver.str(STRING(" not exhausted"))
            'DebugSerialDriver.CRLF
          DeclaredFileSize := FileLengthFromMB  ' nothing to check, just assign
          FileReceiveStep := FRS_FileData                  ' stop dumping MacBinary header info
        else
          ' we must have run out of input
          NeedPacket := true
          ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
          ExpectedSequence := FollowingSeqNum(ExpectedSequence) ' increment or wrap sequence number
          'DebugSerialDriver.str(STRING("Still dumping, exp seq="))
          'DebugSerialDriver.str(nums.ToStr(ExpectedSequence,nums#HEX))
          'DebugSerialDriver.str(STRING(" dumped="))
          'DebugSerialDriver.str(nums.ToStr(MBDumped,nums#HEX))
          'DebugSerialDriver.CRLF
      KDefs#PT_EndOfFile_type :                   ' only expect this in case of very short files                 
        FileReceiveStep := FRS_EOF ' advance to next file receive process step to handle this packet
      OTHER :             ' not expected packet type
        NAK_Note_Need_Refresh
  else
    NAK_Note_Need_Refresh

PRI DeQuote(QuotedChar):RestoredChar
  ' change escaped character back to it's oritinal value
  '  horrible repeat use of some constants, AND probably need to be defined from init packet results!!!
  if QuotedChar => $40 and QuotedChar =< $5f
    return QuotedChar - $40
  if QuotedChar == $bf
    return QuotedChar + $40
  if QuotedChar => $c0 and QuotedChar =< $df
    return QuotedChar - $40
  if QuotedChar == $3f
    return QuotedChar + $40
  else
    return QuotedChar
    
PRI GetAttributes(pPacketInputBuffer,PacketLength):PacketIsValid|Tag,AttributeStringLength,IndexInPacket,TagNumber
' interprets tagged fields from a Kermit attributes packet
  PacketIsValid := true         ' default is the optomistic assumption
  TagNumber := 0
  ' look through entire packet for tagged feilds
  repeat IndexInPacket from SeqFieldIndex+LenSeqField+LenTypeField to (PacketLength-1)
    Tag := BYTE[pPacketInputBuffer][IndexInPacket]
    AttributeStringLength := GetAttributeString(pPacketInputBuffer+IndexInPacket+1,PacketLength-numEOLchars-numCheckSumChars,@AttributeBuffer)
    if AttributeStringLength == StringGetFailed
      PacketIsValid := false
      quit  ' jump out of the repeat loop                                                                                    
    else
      ' we did successfully get a string
      PacketLength -= (AttributeStringLength+2)             ' this much less is left for next attribute
      IndexInPacket += (AttributeStringLength+1)
    case Tag
      KDefs#KAPT_Length :
        DeclaredFileSize := nums.FromStr(@AttributeBuffer,nums#DEC) ' just this line requires anonther instance of this object
        quit  ' jump out of the repeat loop
      OTHER :
        ' do nothing with the found string

PRI GetAttributeString(pStartOfAttribute,BytesAvailable,pStringBuffer):StringLenght| StringIndex
' for single field of a Kermit Attribute Packet, reads length of attribute and creates null terminated string from remainder of field
  if BytesAvailable => 1
    StringLenght := unchar(BYTE[pStartOfAttribute])
    ' does packet have enough bytes left to have this declared string length?
    if StringLenght+1 > BytesAvailable
      StringLenght := StringGetFailed
    else
      StringLenght <#= (AttrBufLen-1)                   ' limit to no longer than buffer can handle
      ' copy string to buffer
      repeat StringIndex from 0 to StringLenght-1
        BYTE[pStringBuffer][StringIndex] := BYTE[pStartOfAttribute][StringIndex+1]
      ' null terminate the string
      BYTE[pStringBuffer][StringLenght] := NULL
  else
    StringLenght := StringGetFailed

PRI ReadFileLength(CurrentByte,CurrentIndex)
  ' assumes only three bytes will have file size, actually only expect two, "80_80" is expected for a 32K file
  case CurrentIndex
    MacBinaryFileSizeLSBIndex-2 : ' first eligable byte of file size
      'DebugSerialDriver.str(STRING("Dumped="))
      'DebugSerialDriver.str(nums.ToStr(CurrentIndex,nums#DEC))
      'DebugSerialDriver.str(STRING(" byte="))
      'DebugSerialDriver.str(nums.ToStr(CurrentByte,nums#HEX))
      'DebugSerialDriver.CRLF
      ' use first of three bytes to initialize the file length sum
      FileLengthFromMB := CurrentByte
    MacBinaryFileSizeLSBIndex-1, MacBinaryFileSizeLSBIndex : ' 2nd LS byte and LS byte of file size
      'DebugSerialDriver.str(STRING("dumped="))
      'DebugSerialDriver.str(nums.ToStr(CurrentIndex,nums#DEC))
      'DebugSerialDriver.str(STRING(" byte="))
      'DebugSerialDriver.str(nums.ToStr(CurrentByte,nums#HEX))
      'DebugSerialDriver.CRLF
      ' shift sum left one byte and add new byte
      FileLengthFromMB := (FileLengthFromMB << 8) + CurrentByte
    OTHER :
      ' do nothing

PRI FileReceive4
' receive file data
  'strK(STRING("got to file receive 4")) ' to see in serial port monitor, do not expect to see in terminal screen
  'repeat ' hang here
 
  'DebugSerialDriver.str(STRING("FR4 ec="))
  'DebugSerialDriver.str(nums.ToStr(ParsedPakErrCode,nums#HEX))
  'DebugSerialDriver.str(STRING(" PType="))
  'DebugSerialDriver.str(nums.ToStr(PakType,nums#HEX))
  'DebugSerialDriver.CRLF
  if ParsedPakErrCode ==  KDefs#PEC_KermitPacketReady ' no problem detected with the packet?
    case PakType          ' branch depending on packet type
      KDefs#PT_Data_type :                   ' this is an expected type
        DataPacketProcess                 
        'if DecodeProcessState == Decode_PS_Init ' are we ready to decode a new file data packet payload?
        if DataPacket_ProcessState == DataPacket_Init ' are we ready to process a new data packet?
          ExpectedSequence := FollowingSeqNum(ExpectedSequence) ' increment or wrap sequence number
          NeedPacket := true ' start looking for another Kermit packet
      KDefs#PT_EndOfFile_type :                   ' this is an expected type, but not processed in this step                 
        FileReceiveStep := FRS_EOF ' advance to next file receive process step to handle this packet
      OTHER :             ' not expected packet type
        NAK_Note_Need_Refresh
  else
    NAK_Note_Need_Refresh

PRI DurationClks(DurationMs):DurationInClocks       
  DurationInClocks := (clkfreq >> 10 + clkfreq >> 16) * DurationMs ' -.8% accurate 
  'DurationInClocks := (clkfreq >> 10 + clkfreq >> 16 + clkfreq >> 17) * DurationMs ' -.05% accurate 
                              
PRI DurationClksFromTmS(DurationTenthsOfMs):DurationInClocks       
  DurationInClocks := (clkfreq >> 14 + clkfreq >> 15 + clkfreq >> 17) * DurationTenthsOfMs ' -.8% accurate 

PRI StartTiming(DurationClocks):TimeoutTimeClks
  TimeoutTimeClks := cnt + DurationClocks
                                                                     
PRI TimeYet(TimeoutTimeClks):AtOrPastTheTime      
  AtOrPastTheTime := (cnt - TimeoutTimeClks) => 0              
  'AtOrPastTheTime := (cnt => TimeoutTimeClks)

' StartTime := cnt ' one line alternative to "StartTiming" for use with "TimeYetDifferential"              
    
PRI TimeYetDifferential(StartTime,DurationClocks):AtOrPastTheTime      
  AtOrPastTheTime := (cnt - StartTime) => DurationClocks              

CON ' process states for "DataPacketProcess"
  DataPacket_Init = 0
  DataPacket_InPakInit = 1 ' special init case where we start using data for the file after some was diverted as Mac Binary Header
  DataPacket_Decode = 2
  DataPacket_SendEEPROM = 3
  ' I need batter constant that depends on page size
  ExpectedWriteTimeTms = 29 ' how long we expect the send of a page of data to take (tenths of a millisecond), fixed value based on size 4 page
DAT
  DataPacket_ProcessState long DummyInit
  StartingFileSize long DummyInit
  OutputQuantityAllowed long DummyInit ' How many bytes may be placed into output buffer, shared with downstream process
  ExpectedWriteTimeClk long DummyInit  ' how long we expect EEPROM send to take (clocks)
  AllowedCallTimeClk long DummyInit ' limit to time we want a Receive File call to last (clocks)
PRI DataPacketProcess:DataPacketComplete|ShallRepeat,PrintDelayTimeoutClk
  'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
  ShallRepeat := true ' just to make entering the loop possible
  repeat while ShallRepeat
    ShallRepeat := false ' the default case is to never repeat
    case DataPacket_ProcessState                                             
      DataPacket_Init : ' prepare for a new data packet
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        'DebugSerialDriver.str(STRING("ACK at "))
        'DebugSerialDriver.str(nums.ToStr(cnt,nums#HEX))
        'DebugSerialDriver.CRLF
        PrepAndSend(@General_ACK,ExpectedSequence)    ' tell sender packet arrived OK, even before we have started to use it
        'if ExpectedSequence == 3 ' stop after 1st data packet, 'no timeout' is set in parsing
        '  repeat ' hang here
        StartingFileSize := MeasuredFileLength
        ' not necessary since decode process resets itself, and the whole file receive process sets this at its initialization
        DecodeProcessState := Decode_PS_Init ' for initializing the decode process, show we are ready for a new packet...
        ShallRepeat := true ' this step was quick, do the next step now
        DataPacket_ProcessState := DataPacket_Decode ' do some decoding right now
      DataPacket_InPakInit : ' prepare to continue processing partially used data packet
        'DebugSerialDriver.str(STRING("at Packet InPakInit "))
        'DebugSerialDriver.CRLF
        StartingFileSize := MeasuredFileLength
        ' not necessary since decode process resets itself, and the whole file receive process sets this at its initialization
        DecodeProcessState := Decode_PS_InPakInit ' for initializing the decode process, show we are just starting output of file data to EEPROM
        ShallRepeat := true ' this step was quick, do the next step now
        DataPacket_ProcessState := DataPacket_Decode ' do some decoding right now
      DataPacket_Decode : ' decoding and possibly expanding run length encoding
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        ' see how many characters we can decode
        OutputQuantityAllowed := DeclaredFileSize - MeasuredFileLength ' see how many bytes remain to finish the file
        'DebugSerialDriver.str(STRING("decl size="))
        'DebugSerialDriver.str(nums.ToStr(DeclaredFileSize,nums#HEX))
        'DebugSerialDriver.str(STRING("meas len="))
        'DebugSerialDriver.str(nums.ToStr(MeasuredFileLength,nums#HEX))
        'DebugSerialDriver.CRLF
        OutputQuantityAllowed <#= EEPROM_WriteSize ' limit to no more than buffer size
        ' remove quotes from the string, expand run length encodes
        ' note: data begins at index 4, but I should state this as a combination of other constants rather than a literal
        DecodeDataPacketPayload(@PacketInputBuffer[4])
        'if ExpectedSequence == 37 ' stop after 1st data packet, 'no timeout' is set in parsing
          'repeat ' hang here
          ' just delay here
          'PrintDelayTimeoutClk := StartTiming(DurationClks(100))
          'repeat until TimeYet(PrintDelayTimeoutClk)
        if Output_IndexLimitReached and PrepBufIndex > 0' is a full output buffer to write to EEPROM?
          if OutputQuantityAllowed == 0
            PadBytes += PrepBufIndex
            'DebugSerialDriver.str(STRING("end padding="))
            'DebugSerialDriver.str(nums.ToStr(PadBytes,nums#HEX))
            'DebugSerialDriver.CRLF
          if ActuallyWritingEEPROM and OutputQuantityAllowed > 0 ' are we sending file data to EEPROM?
            ' is there time remaining to do an EEPROM write?
            if not TimeYetDifferential(ReceiveFileStartTime,AllowedCallTimeClk-ExpectedWriteTimeClk)
              if not TryEEPROM_Write ' try to send the data to the EEPROM right now.  Assumes we have spent little time in call so far
              'if true ' pretend this write failed to see if it brings missing character write
                DataPacket_ProcessState := DataPacket_SendEEPROM ' send this data to EEPROM on the next pass
              'else ' not necessary
              '  DataPacket_ProcessState := DataPacket_Decode ' prepare to decode more data on next pass
            else
              ' we don't have enough time, try on next call
              'DataPacket_ProcessState := DataPacket_Decode ' prepare to decode more data on next pass, seems wrong because we can't decode more till this is written
              DataPacket_ProcessState := DataPacket_SendEEPROM ' prepare to decode more data on next pass, seems wrong
          else
            FileDataCount := OutputQuantityAllowed ' tell debugger how many file bytes to display
            PrepBufIndex := 0 ' move back to beginning of output buffer, ignoring the decoded data
            MeasuredFileLength += OutputQuantityAllowed ' record this amount of file received
        if InputExhausted and DataPacket_ProcessState <> DataPacket_SendEEPROM ' is there no more data this packet?
          if MeasuredFileLength == StartingFileSize
            ExtraDataPacketCount++
            ' this test is a kind of buffer over run attack detection
            if ExtraDataPacketCount > ExtraDataPacketTolerance  ' too many file packets where we did not accept data?  Allow some for Mac send end paddiing
              FileReceiveStep := FRS_ForceTerminate ' halt receive of this file because too many empty file data packets arrived, aborts a higher level process
          DataPacket_ProcessState := DataPacket_Init ' this data packet is completely decoded, signal we are ready for another
          ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
      DataPacket_SendEEPROM :    ' we only ever get here if a first try at writing failed, probably won't happen if rest of control loop takes much time
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        SentTry++
        GeneralDebug(6,SentTry)
        'strK(STRING("needed 2nd write try")) ' to see in serial port monitor, do not expect to see in terminal screen
        ' write to EEPROM if we have waited long enough since last write
        if TryEEPROM_Write ' do we succeed in writing?
          'repeat ' hang here
          ''DebugSerialDriver.str(STRING("Data Packet, Send "))
          if InputExhausted ' is there no more data this packet?
            DataPacket_ProcessState := DataPacket_Init ' this data packet is completely decoded, signal we are ready for another
            ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
          else
            DataPacket_ProcessState := DataPacket_Decode ' prepare to decode more data on next pass
          
CON ' process states for "DecodeDataPacketPayload"
  Decode_PS_Init = 0
  Decode_PS_InPakInit = 1
  Decode_PS_HandleOneCharacter = 2
  Decode_PS_HandleMultCharInit = 3
  Decode_PS_HandleMultCharLoop = 4  
DAT
  DecodeProcessState long DummyInit
  Decode_InputBatchSize long DummyInit ' how large the payload of the current data packet is
  Decode_InputIndex long DummyInit ' where we are in the payload of the current data packet
  DupCharQuantity long DummyInit  ' how many repeats there are in the current RLE encode
  DupChar long DummyInit ' the character that repeats in the current RLE encode
  'EndDupIndex long DummyInit ' how much RLE expansion is allowed limited by file length, page size, and quantity in the current RLE encode
  DupsWritten long DummyInit    ' how many characters of current RLE expansion have been written to the output buffer
  WriteCalls long 0 
PRI DecodeDataPacketPayload(pInputBuffer)|ShallRepeat
  ' needs to return/store:
  ' -index limit reached or not
  ' -input exhausted or not
  ' -in RLE or not categorized next input
  ' -current input index
  ' -update total measured file sixe
  ' remove escapes for 'control and prefix' characters and expand run length encoding
  ' will not write beyond output buffer limit, so may lose characters if RLE expansion it too much
  ' this is also where the object posts its output to the circular buffer
  'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
  ShallRepeat := true ' just to make entering the loop possible
  repeat while ShallRepeat
    ShallRepeat := false ' the default case is to never repeat
    case DecodeProcessState
      Decode_PS_Init :      
        'DebugSerialDriver.str(STRING("at Decode Init "))
        'DebugSerialDriver.CRLF
        Decode_InputBatchSize := PacketInputIndex - NonDataBytesInDataPacket
        ''DebugSerialDriver.str(STRING("input batch size is "))
        ''DebugSerialDriver.str(nums.ToStr(Decode_InputBatchSize,nums#HEX))
        ''DebugSerialDriver.str(STRING(" ii is "))
        ''DebugSerialDriver.str(nums.ToStr(PacketInputIndex,nums#HEX))
        Decode_InputIndex := 0
        DecodeProcessState := Decode_PS_HandleOneCharacter
        ShallRepeat := true
      Decode_PS_InPakInit :      
        'DebugSerialDriver.str(STRING("at Decode InPakInit "))
        'DebugSerialDriver.CRLF
        Decode_InputBatchSize := PacketInputIndex - NonDataBytesInDataPacket
        DecodeProcessState := Decode_PS_HandleOneCharacter
        ShallRepeat := true
      Decode_PS_HandleOneCharacter :
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        ' did we NOT finish the input buffer?
        ''DebugSerialDriver.str(STRING("Decode "))
        if not InputExhausted
          if BYTE[pInputBuffer][Decode_InputIndex] == QCTL           ' is this character the quote for control and prefix characters?
            Decode_InputIndex++              ' advance to the escaped value location, the quote character will not be part of the output
            ' output one character
            PutOutputByte(DeQuote(BYTE[pInputBuffer][Decode_InputIndex]))
            Decode_InputIndex++             ' get ready for next input character
            ShallRepeat := not Output_IndexLimitReached
          else
            if BYTE[pInputBuffer][Decode_InputIndex] == REPT         ' is this character the escape for run length encoding?
              DecodeProcessState := Decode_PS_HandleMultCharInit
              ShallRepeat := true
            else
              ' this must be just a regular character, not quoting or repeating
              ' output one character
              PutOutputByte(BYTE[pInputBuffer][Decode_InputIndex])
              Decode_InputIndex ++  ' advance to next character
              ShallRepeat := not Output_IndexLimitReached
        else ' we did finish the input buffer
          DecodeProcessState := Decode_PS_Init ' prepare to start over
      Decode_PS_HandleMultCharInit :
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        Decode_InputIndex++            ' advance to the duplication count location
        DupCharQuantity := UnChar(BYTE[pInputBuffer][Decode_InputIndex])
        Decode_InputIndex++            ' advance to the duplicated character location
        if BYTE[pInputBuffer][Decode_InputIndex] == QCTL       ' is this character the quote for control and prefix characters?
          Decode_InputIndex++          ' advance to the escaped value location
          DupChar := DeQuote(BYTE[pInputBuffer][Decode_InputIndex])
        else
          DupChar := BYTE[pInputBuffer][Decode_InputIndex]
        DupsWritten := 0 ' initialize counter of duplicates written to output buffer
        DecodeProcessState := Decode_PS_HandleMultCharLoop
        ShallRepeat := true
      Decode_PS_HandleMultCharLoop :
        'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
        'if PrepBufIndex =< EndDupIndex ' have we NOT finished RLE expansion of this repeat instance?
        if DupsWritten < DupCharQuantity ' have we NOT finished RLE expansion of this repeat instance?
          DupsWritten++ ' increment count of written duplicates
          ' output one character
          PutOutputByte(DupChar)
          if not Output_IndexLimitReached ' do we still have room in the EEPROM prep buffer?
            ShallRepeat := true
        else ' we have finished the repeat sequence
          DecodeProcessState := Decode_PS_HandleOneCharacter
          Decode_InputIndex ++  ' advance to next character
          ShallRepeat := true

PRI InputExhausted | Conclusion
' determines if data packet payload has been consumed
' for post increment use, in other words, decode input index is pointing to NEXT character to decode
  ''DebugSerialDriver.str(STRING("checking ii "))
  ''DebugSerialDriver.str(nums.ToStr(Decode_InputIndex,nums#HEX3))
  'return Decode_InputIndex > Decode_InputBatchSize 
  Conclusion := Decode_InputIndex => Decode_InputBatchSize 
  ''DebugSerialDriver.str(STRING("exhausted="))
  ''DebugSerialDriver.str(nums.ToStr(Conclusion,nums#HEX3))
  ''DebugSerialDriver.CRLF
  return Conclusion

PRI Output_IndexLimitReached
' determine if decode output buffer (AKA EEPROM prep buffer) is full
  ' test the post incremented value of the index, now it is a quantity
  return PrepBufIndex => OutputQuantityAllowed ' is buffer at page size or file at stated size?

PRI PutOutputByte(TheByteValue)
' stow this byte into the buffer that holds data to write to EEPROM
  EE_write_prep[PrepBufIndex] := TheByteValue     ' save byte and increment index
  ''DebugSerialDriver.str(STRING("prep "))
  ''DebugSerialDriver.str(nums.ToStr(TheByteValue,nums#HEX3))
  ''DebugSerialDriver.str(STRING(" to "))
  ''DebugSerialDriver.str(nums.ToStr(PrepBufIndex,nums#HEX))
  ''DebugSerialDriver.CRLF
  PrepBufIndex++

PRI TryEEPROM_Write:DidWrite|PretendWriteDoneClk,DurationWriteMs,Simulate
  'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
  if TimeYet(WhenReadyForNextWrite)  ' EEPROM recovered since last write?  This is timed rather than tested
    'DebugSerialDriver.str(STRING("writing "))
    ''DebugSerialDriver.str(nums.ToStr(OutputQuantityAllowed,nums#HEX))
    ''DebugSerialDriver.str(STRING(" of ---"))
    ''DebugSerialDriver.str(nums.ToStr(EE_write_prep[0],nums#HEX3))
    ''DebugSerialDriver.str(nums.ToStr(EE_write_prep[1],nums#HEX3))
    ''DebugSerialDriver.str(nums.ToStr(EE_write_prep[2],nums#HEX3))
    ''DebugSerialDriver.str(nums.ToStr(EE_write_prep[3],nums#HEX3))
    ''DebugSerialDriver.str(STRING("--- at "))
    ''DebugSerialDriver.str(nums.ToStr(eepromLocation,nums#HEX))
    ''DebugSerialDriver.str(STRING(" ii="))
    ''DebugSerialDriver.str(nums.ToStr(Decode_InputIndex,nums#HEX))
    ''DebugSerialDriver.str(STRING(" seq="))
    ''DebugSerialDriver.str(nums.ToStr(DeclaredSeqNum,nums#HEX))
    ''DebugSerialDriver.str(STRING(" FileReceivePS="))
    ''DebugSerialDriver.str(nums.ToStr(FileReceiveStep,nums#HEX))
    ''DebugSerialDriver.str(STRING(" DataPacketPS="))
    ''DebugSerialDriver.str(nums.ToStr(DataPacket_ProcessState,nums#HEX))
    ''DebugSerialDriver.str(STRING(" DecodePS="))
    ''DebugSerialDriver.str(nums.ToStr(DecodeProcessState,nums#HEX))
    'DebugSerialDriver.CRLF
        
    'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
    Simulate := false
    if Simulate
      ' simulate the send
      PretendWriteDoneClk := StartTiming(DurationClksFromTmS(ExpectedWriteTimeTms)) ' figure when we are done, first converting 1/10 milliseconds to clocks
      repeat while not TimeYet(PretendWriteDoneClk)
    else
      ' do the send
      i2cObject.WritePage(i2cSCL, EEPROMAddr, eepromLocation,@EE_write_prep,OutputQuantityAllowed)
    WhenReadyForNextWrite := StartTiming(EEPROM_Wait_clk)
    eepromLocation += OutputQuantityAllowed
    ' tell any possible debugger how much decoded data to display
    FileDataCount := OutputQuantityAllowed ' post incremented index is corrrect as quantity
    PrepBufIndex := 0 ' move back to beginning of output buffer because we are finished with the data in this object
    MeasuredFileLength += OutputQuantityAllowed ' record this amount of file received
    DidWrite := true
    InputStatusFlags |= KEC_ISM_EEPROM_Dirty ' record fact that we changed EERPOM
    'if WriteCalls > 400
    '  strK(string("WWWWWWW"))   'Decode_InputIndex nums.ToStr(ByteCount,nums#DEC)
    '  strK(nums.ToStr(Decode_InputIndex,nums#DEC))
  else
    'DebugSerialDriver.str(STRING("not ready to write "))
    'DebugSerialDriver.CRLF
        
    'repeat until TimeYetDifferential(ReceiveFileStartTime,DisplaySimDurationClk)
    DidWrite := false
    'if WriteCalls > 400
    '  strK(string("no write"))
    '  strK(nums.ToStr(Decode_InputIndex,nums#DEC))
  WriteCalls++

PRI FileReceive5
' look for end of file packet
  'strK(STRING("got to file receive 5")) ' to see in serial port monitor, do not expect to see in terminal screen
  'repeat ' hang here
  if ParsedPakErrCode ==  KDefs#PEC_KermitPacketReady ' no problem detected with the packet?
    case PakType          ' branch depending on packet type
      KDefs#PT_EndOfFile_type :                   ' this is an expected type, but not processed in this step                 
        PrepAndSend(@General_ACK,ExpectedSequence) ' tell sender our time out period
        ' flush output buffer
        if PrepBufIndex <> 0
          'strK(string("Flush"))
          ' note: we assume we will not exceed the call time limit
          repeat while not TryEEPROM_Write ' write last remaining bytes
            'strK(string("Flushing"))
        ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
        ExpectedSequence := FollowingSeqNum(ExpectedSequence) ' increment or wrap sequence number
        NeedPacket := true ' start looking for another Kermit packet
        FileReceiveStep := FRS_EOT ' advance to next file receive process step to handle this packet
      OTHER :             ' not expected packet type
        NAK_Note_Need_Refresh
  else
    NAK_Note_Need_Refresh
  
PRI FileReceive6
' get break transmission packet
  case ParsedPakErrCode ' switch on general status of packet receive
    KDefs#PEC_KermitPacketReady : ' no problem detected with the packet
      case PakType          ' branch depending on packet type
        KDefs#PT_BreakTransmission_type :                   ' this is the expected type
          PrepAndSend(@General_ACK,ExpectedSequence) ' tell sender our time out period
          ResetProcessErrorTimeout
          ShowPacketResults := true  ' signal to debugger to update packet parse and process results display
          FileReceiveStep := FRS_CheckLen ' advance to next file receive process step to handle this packet
        OTHER :             ' not expected packet type
          NAK_Note_Need_Refresh
    OTHER : ' problem was found during packet parse
      NAK_Note_Need_Refresh

PRI FileReceive7
' check file length & go back to command mode
  FileReceiveStep := FRS_Init  ' trigger reset of process if another Kermit mark is detected
  InputStatusFlags &= ! KEC_ISM_KermitPacketDetected ' record that Kermit ended
  ' check file length
  if MeasuredFileLength == DeclaredFileSize
    InputStatusFlags |= KEC_ISM_KermitCompleted ' writing the Kermit file to memory has successfully finished, ready to reboot
  ReleaseOutput ' the Kermit process is over, so let others get access to output again
  
PRI FileReceiveTerminate
  PrepAndSend(@General_ERROR,ExpectedSequence) ' special termination packet
  FileReceive7
  
PRI FollowingSeqNum(PresentSeqNum):NewSeqNum
  ' look to next packet's sequence number
  if PresentSeqNum == MaxSeqNum                   ' have we reached the wrap around limit?
    NewSeqNum := MinSeqNum                        ' wrap back to 0              
  else
    NewSeqNum := ++PresentSeqNum                  ' increment for next packet

PRI CopyBytes(pSource,pDest,Quantity)|ByteIndex,MaxIndex
' copies a series of bytes of specified length
  MaxIndex := Quantity - IndexToLength
  repeat ByteIndex from 0 to MaxIndex
    BYTE[pDest][ByteIndex] := BYTE[pSource][ByteIndex]

PRI xef(PresentSeqNum):NewSeqNum
  ' look to next packet's sequence number
  if PresentSeqNum == MaxSeqNum                   ' have we reached the wrap around limit?
    NewSeqNum := MinSeqNum                        ' wrap back to 0              
  else
    NewSeqNum := ++PresentSeqNum                  ' increment for next packet

PRI ResetProcessErrorTimeout
' marks when and that file receive process is known to be running well
  ProcessHasError := false
  ErrorStartTime := cnt         ' record when we had a good packet

PRI NAK_Note_Need_Refresh  ' note: older code had complex test for re-send of previous packet, an no NAK of that case
' common operations for case of packet had parse error
  'DebugSerialDriver.str(STRING("NAK at "))
  'DebugSerialDriver.str(nums.ToStr(cnt,nums#HEX))
  'DebugSerialDriver.CRLF
  ' may need flush here
  PrepAndSend(@General_NAK,ExpectedSequence)
  ProcessHasError := true
  NeedPacket := true ' start looking for another Kermit packet on next call of process routine
  ShowPacketResults := true  ' signal to debugger to update packet parse and process results display

CON
  ' Kermit packet parsing process states
  KPS_Init        =0
  KPS_GetMark     =1
  KPS_GetLength   =2
  KPS_GetSeq      =3
  KPS_GetType     =4
  KPS_LookForEnd  =5
  KPS_VerifyCkLen =6
  KPS_FlushInput  =7

PRI ParseKermitPacket{: LocalPakErrCode}|ParseLoopLimitTimeClk,ShallRepeat
  ' this is what you call as long as we are in mode of getting a file via Kermit, each time prior to calling routine to put packet into EEPROM
  ' works in a 7 step rentrent process
  ' always fast
                                                                                         
  'if ExpectedSequence == 2
  '  repeat ' hang here
  ' has the packet timed out AND we have started looking for a packet?
  if ((cnt - PacketStartTime) => PaketTimeout_clk) AND KermitParseStep <> KPS_Init
    ' we have not received characters in quite a while
    if PacketInputBuffer[PacketInputIndex-1] == EOL ' was the last received character the end of line character?
      ' because the loop has not finished, we must have been expecting a longer packet per the packet length field
      ParsedPakErrCode := KDefs#PEC_MissingCharsInPacket
    else
      ' we were kept waiting during a packet receipt
      ParsedPakErrCode := KDefs#PEC_KermitPacketTimeout
      'GeneralDebug(6,(cnt - PacketStartTime) - PaketTimeout_clk)
      'GeneralDebug(5,KermitParseStep)
    ShallRepeat := false
  else
    'LocalPakErrCode := KDefs#PEC_KeepProcessingNow ' enable repeats of loop
    ShallRepeat := true
    ' did we run out of input on last call?
    if ParsedPakErrCode == KDefs#PEC_WaitingForInput
      ' set error code back to 'in process'
      ParsedPakErrCode := KDefs#PEC_InProcess

  '  figure when we need to kill this loop
  ParseLoopLimitTimeClk := ReceiveFileStartTime + (AllowedCallTimeClk-ParseTimeMarginClk)

  ' do as many steps as we can until an error or until serial input buffer is empty
  'repeat while LocalPakErrCode == KDefs#PEC_KeepProcessingNow
  repeat while ShallRepeat 
    case KermitParseStep
      KPS_Init : ' initialize process of getting a packet
        ShallRepeat := ParseKermit0
      KPS_GetMark : ' get mark
        ShallRepeat := ParseKermit1
      KPS_GetLength : ' look for packet length
        ShallRepeat := ParseKermit2
      KPS_GetSeq : ' look for packet sequence number
        ShallRepeat := ParseKermit3
      KPS_GetType : ' look for type
        ShallRepeat := ParseKermit4
      KPS_LookForEnd : ' look for end of packet                                                 ' KDefs#WaitingForInput
        ShallRepeat := ParseKermit5(ParseLoopLimitTimeClk)
      KPS_VerifyCkLen : ' verify checksum & check received length
        ShallRepeat := ParseKermit6
      KPS_FlushInput : ' flush input buffer
        ShallRepeat := ParseKermit7
    'if false ' never timeout to see why adding serial debugs fixes problems with repeats
    if TimeYet(ParseLoopLimitTimeClk) ' almost out of time for this call?
      ''DebugSerialDriver.str(STRING("Parse timeout ec="))   
      ''DebugSerialDriver.str(nums.ToStr(ParsedPakErrCode,nums#HEX))
      ''DebugSerialDriver.str(STRING(" ParS="))   
      ''DebugSerialDriver.str(nums.ToStr(KermitParseStep,nums#HEX))
      ''DebugSerialDriver.CRLF
      GeneralDebug(15,KermitParseStep)
      GeneralDebug(14,ParsedPakErrCode)
      ShallRepeat := false ' get out of thfe repeat loop

PRI ParseKermit0:ShallRepeat
' initialize process of getting a packet
  'if ExpectedSequence == 2
  '  repeat ' hang here
  PacketInputIndex := 0         ' start place for this input packet
  KermitParseStep := KPS_GetMark ' advance process state
  PacketStartTime := cnt  ' record entry time, somewhat delayed
  ParsedPakErrCode := KDefs#PEC_InProcess
  ShallRepeat := true

PRI ParseKermit1:ShallRepeat
' get mark
  ' look for packet begin character
  ThisNewChar := Rx
  if ThisNewChar == NoData
    ParsedPakErrCode :=   KDefs#PEC_WaitingForInput ' come back later to see if there is input
    ShallRepeat := false
  else
    ' put this byte into the Kermit packet buffer
    StowPacketCharacter(ThisNewChar)                      ' make this part of the packet available for later examination
    ''DebugSerialDriver.str(STRING("Start="))   
    ''DebugSerialDriver.str(nums.ToStr(ThisNewChar,nums#HEX))
    if ThisNewChar <> KDefs#MARK
      ''DebugSerialDriver.CRLF
      ParsedPakErrCode :=  KDefs#PEC_BadPacketStart ' wrong byte was waiting
      KermitParseStep := KPS_FlushInput
    else
      KermitParseStep := KPS_GetLength ' advance process state
    ShallRepeat := true

PRI ParseKermit2:ShallRepeat
' look for packet length
  'if ExpectedSequence == 2
  '  repeat ' hang here
  ThisNewChar := Rx
  if ThisNewChar == NoData
    ParsedPakErrCode := KDefs#PEC_WaitingForInput ' come back later to see if there is input
    ShallRepeat := false
  else
    StowPacketCharacter(ThisNewChar)                      ' make this part of the packet available for later examination
    ''DebugSerialDriver.str(STRING(" Len="))   
    ''DebugSerialDriver.str(nums.ToStr(ThisNewChar,nums#HEX))
    DeclRemainingLength := unchar(ThisNewChar)            ' char to number
    ' check for length value needed to have a valid packet
    if DeclRemainingLength < LenSeqField + LenTypeField + numCheckSumChars OR DeclRemainingLength > MaxReminingChars
      ''DebugSerialDriver.CRLF
      ParsedPakErrCode :=  KDefs#PEC_BadPacketLength
      KermitParseStep := KPS_FlushInput
    else
      KermitParseStep := KPS_GetSeq ' advance process state
    ShallRepeat := true

PRI ParseKermit3:ShallRepeat
  ' look for packet sequence number
  ThisNewChar := Rx
  if ThisNewChar == NoData
    ParsedPakErrCode := KDefs#PEC_WaitingForInput ' come back later to see if there is input
    ShallRepeat := false
  else
    StowPacketCharacter(ThisNewChar)                      ' make this part of the packet available for later examination
    DeclaredSeqNum := unchar(ThisNewChar)           ' char to number
    ''DebugSerialDriver.str(STRING(" Seq="))   
    ''DebugSerialDriver.str(nums.ToStr(DeclaredSeqNum,nums#HEX))
    ''DebugSerialDriver.CRLF
    'if DeclaredSeqNum == 2
    '  repeat '  hang here
    ' Q: why check this later instead of right now?
    KermitParseStep := KPS_GetType ' advance process state
    ShallRepeat := true

PRI ParseKermit4:ShallRepeat
  ' look for type
  'if ExpectedSequence == 2
  '  repeat ' hang here
  ThisNewChar := Rx
  if ThisNewChar == NoData
    ParsedPakErrCode := KDefs#PEC_WaitingForInput ' come back later to see if there is input
    ShallRepeat := false
  else
    StowPacketCharacter(ThisNewChar)                      ' make this part of the packet available for later examination
    PakType := ThisNewChar        ' this field is a literal character, store to the global
    ' initialize the count used in step 5
    CountedRemainingLength := 2     ' we already got seq number and type
    KermitParseStep := KPS_LookForEnd ' advance process state
    ShallRepeat := true

PRI ParseKermit5(ParseLoopLimitTimeClk):ShallRepeat'|StartTime
' step 5, look for end of packet
  'StartTime := cnt
  ShallRepeat := true
  ThisNewChar := Rx ' try to get another character from the input buffer
  if ThisNewChar == NoData
    GeneralDebug(13,PacketInputIndex)
    ParsedPakErrCode := KDefs#PEC_WaitingForInput ' come back later to see if there is input
    ShallRepeat := false
  else
    StowPacketCharacter(ThisNewChar)                    ' make this part of the packet available for later examination
    CountedRemainingLength++

  if CountedRemainingLength > DeclRemainingLength ' did we finish the loop?
    ' did we NOT get expected EOL character?
    if ThisNewChar <> EOL
      ParsedPakErrCode := KDefs#PEC_BadEOL
      KermitParseStep := KPS_FlushInput
    else
      ' we did get the expected end of line character
      ' null terminate packet for separate printability
      PacketInputBuffer[PacketInputIndex] := NULL
      KermitParseStep := KPS_VerifyCkLen ' advance process state
  'MaxCall5Time := (cnt-StartTime) #> MaxCall5Time
  'GeneralDebug(5,MaxCall5Time)

PRI ParseKermit6:ShallRepeat
' step 6, verify checksum & sequence number
  if not VerifyChecksum(@PacketInputBuffer,PacketInputIndex)
    ParsedPakErrCode :=  KDefs#PEC_ChecksumMismatch
  else
    ''DebugSerialDriver.str(STRING("Testing "))   
    ''DebugSerialDriver.str(nums.ToStr(ExpectedSequence,nums#HEX))
    ''DebugSerialDriver.str(STRING(" == "))   
    ''DebugSerialDriver.str(nums.ToStr(DeclaredSeqNum,nums#HEX))
    ''DebugSerialDriver.CRLF
    ' is this the sequence number we expected? not sure why I don't check this earlier
    if ExpectedSequence <> DeclaredSeqNum
      ParsedPakErrCode :=  KDefs#PEC_WrongPacketSequence
    else
      ParsedPakErrCode :=  KDefs#PEC_KermitPacketReady ' we are finished with Kermit packet parsing successfully  
  KermitParseStep := KPS_FlushInput ' advance process state
  ShallRepeat := true
  
PRI ParseKermit7:ShallRepeat
' flush input buffer
  ' this added 2008.12.1 on advice of Byte's rule 6, 'clear the input buffer after reading each packet that arrives successfully'
  ' dump input buffer until it is empty
  'if ExpectedSequence == 2
  '  repeat ' hang here
  repeat while Rx <> NoData
  KermitParseStep := KPS_Init ' reset the parse process for repeat next time
  ShallRepeat := false

PRI StowPacketCharacter(TheInputCharacter)
  ' stuff incoming characters into a global buffer, uses global index
  PacketInputBuffer[PacketInputIndex] := TheInputCharacter
  PacketInputIndex++            ' get ready for next input character stowing

PRI PrepAndSend(pPacket,Seq)| PackLen
  ' prepare and send packet, measures length, sets sequence and checksum, then sends
  PackLen := strsize(pPacket)
  BYTE[pPacket][SeqFieldIndex] := char(Seq)             ' embed the sequence number
  SetChecksum(pPacket,PackLen)                          ' calculate and embed the checksum
  strK(pPacket)                                         ' send ACK packet

PRI SetChecksum(pPacketString,ThisPacketStringLength)| NumericChecksum
  NumericChecksum := CalcChecksum(pPacketString,ThisPacketStringLength)            ' calculate numeric value of checksum
  'LONG[@MonArray][96] := NumericChecksum
  ' calculate character value of checksum and embed it
  BYTE[pPacketString][ThisPacketStringLength-numCheckSumChars-numEOLchars] := char(NumericChecksum)

PRI CalcChecksum(pPacketString,StringLength) : CComboSum | StringIndex, RawSum, SevenSixBits, ComboSum, SringIndex, MaxIndex
  ' returns numeric checksum value, 'clipped combo checksum'
  ' do not include checksum character in the checksum calculation
  MaxIndex := StringLength - IndexToLength - numEOLchars - numCheckSumChars
  RawSum := 0
  ' add most characters in the string, from length to just before checksum, to get a large checksum
  repeat StringIndex from LenFieldIndex to MaxIndex
    RawSum += BYTE[pPacketString + StringIndex]
  ' get just bits 6 and 7
  SevenSixBits := RawSum & $c0
  ' push bits 6 and 7 into positions 0 and 1
  SevenSixBits >>= 6
  ' add the 6,7 bits to the plain sum to get a combination sum
  ComboSum := RawSum + SevenSixBits
  ' mask off the high order bits, leaving just six bits
  CComboSum := ComboSum & $3f
  'if TimeForPeriodicError      ' test of process robustness
  ' CComboSum ^= %001           ' bitwise xor with some number to make checksum seem wrong

PRI ExtractChecksum(pPacketString,StringLength) : NumericChecksum
  ' get checksum from field in string, make numeric
  ' checksum character is next to the last character in the string
  NumericChecksum := unchar(BYTE[pPacketString + StringLength - IndexToLength - numEOLchars])

PRI VerifyChecksum(pPacketString,StringLength)| ExtrCKS, CalcCKS
  ExtrCKS := ExtractChecksum(pPacketString,StringLength)
  CalcCKS := CalcChecksum(pPacketString,StringLength)
  ' are we displaying debug information?
  if pDebug
    ' post some internal values to a visible place
    LONG[pDebug][KDefs#KDB_ExtractedChecksum] := ExtrCKS
    LONG[pDebug][KDefs#KDB_CalculatedChecksum] := CalcCKS
  return ExtrCKS == CalcCKS

PRI unchar(PrintableValue) : NumericValue
  NumericValue := PrintableValue - PrintableOffset

PRI char(NumericValue) : PrintableValue
  PrintableValue := NumericValue + PrintableOffset

OBJ
  ' just to make orange band to mark end of Kermit code section

PUB str(stringptr):success|StringLength
'' Send string, returns false immediately if insuficient room in output buffer
  StringLength := STRSIZE(stringptr)
  if TryOutput(StringLength + EchoMaxSize) ' do we have room in output buffer plus space for an echo and Kermit not happening?
    strK(stringptr)
    success := true
    ReleaseOutput
  else
    success := false

PRI strK(stringptr)|StringLength
' Send string
' only for calling by Kermit process, or when we know there is no Kermit happening
  StringLength := STRSIZE(stringptr)
  repeat StringLength
    txPriv(byte[stringptr++])

PUB dec(value):success | i
'' Print a decimal number, returns false immediately if insuficient room in output buffer
  if TryOutput(10 + EchoMaxSize) ' do we have room in output buffer for -1000000000 plus space for an echo and Kermit not happening?

    if value < 0
      -value
      txPriv("-")

    i := 1_000_000_000

    repeat 10
      if value => i
        txPriv(value / i + "0")
        value //= i
        result~~
      elseif result or i == 1
        txPriv("0")
      i /= 10
    ReleaseOutput
    success := TRUE
  else
    success := FALSE

PUB hex(value, digits):success
'' Print a hexadecimal number, returns false immediately if insuficient room in output buffer
  if TryOutput(8 + EchoMaxSize) ' do we have room in output buffer for ffeeddcc plus space for an echo and Kermit not happening?

    value <<= (8 - digits) << 2
    repeat digits
      txPriv(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))
    ReleaseOutput
    success := true
  else
    success := false

PUB bin(value, digits):success
'' Print a binary number, returns false immediately if insuficient room in output buffer
  if TryOutput(32 + EchoMaxSize) ' do we have room in output buffer for biggest binary plus space for an echo and Kermit not happening?

    value <<= 32 - digits
    repeat digits
      txPriv((value <-= 1) & 1 + "0")
    ReleaseOutput
    success := true
  else
    success := false

PUB CRLF:success
'' output carrige return and line feed, returns false immediately if insuficient room in output buffer
  if TryOutput(2 + EchoMaxSize) ' do we have room in output buffer for \r\n plus space for an echo and Kermit not happening?
    txPriv(13)
    txPriv(10)
    ReleaseOutput
    success := true
  else
    success := false

PUB tx(TheByte):success
'' output a byte, returns false immediately if insuficient room in output buffer
'' always leaves at least space for an echo to prevent output debugs from totally hogging resource
  if TryOutput(1 + EchoMaxSize) ' do we have room in output buffer for a byte plus space for an echo and Kermit not happening?
    txPriv(TheByte)
    ReleaseOutput
    success := true
  else
    success := false

PUB decT(value,Timeout_clk):success|TimedOut_clk
'' Print a decimal number, returns false if insuficient room in output buffer before timeout
  TimedOut_clk := Timeout_clk + cnt
  success := false
  repeat while (not success) and (cnt - TimedOut_clk < 0)
    success := dec(value)

PUB hexT(value,digits,Timeout_clk):success|TimedOut_clk
'' Print a hexadecimal number, returns false if insuficient room in output buffer before timeout
  TimedOut_clk := Timeout_clk + cnt
  success := false
  repeat while (not success) and (cnt - TimedOut_clk < 0)
    success := hex(value, digits)

PUB binT(value, digits,Timeout_clk):success|TimedOut_clk
'' Print a binary number, returns false if insuficient room in output buffer before timeout
  TimedOut_clk := Timeout_clk + cnt
  success := false
  repeat while (not success) and (cnt - TimedOut_clk < 0)
    success := bin(value, digits)

PUB strT(pbuf,Timeout_clk):success|TimedOut_clk
'' Send string, returns false if insuficient room in output buffer before timeout
  TimedOut_clk := Timeout_clk + cnt
  success := false
  repeat while (not success) and (cnt - TimedOut_clk < 0)
    success := str(pbuf)

PUB txT(TheByte,Timeout_clk):success|TimedOut_clk
'' output a byte, returns false if insuficient room in output buffer before timeout
'' always leaves at least space for an echo to prevent output debugs from totally hogging resource
  TimedOut_clk := Timeout_clk + cnt
  success := false
  repeat while (not success) and (cnt - TimedOut_clk < 0)
    success := tx(TheByte)

PUB CRLF_T(Timeout_clk):success|TimedOut_clk
'' output carrige return and line feed, returns false if insuficient room in output buffer before timeout
  TimedOut_clk := Timeout_clk + cnt
  success := false
  repeat while (not success) and (cnt - TimedOut_clk < 0)
    success := CRLF

PRI localCRLF:success
' output carrige return and line feed
  txPriv(13)
  txPriv(10)

DAT

'***********************************
'* Assembly language serial driver *
'***********************************

                        org
'
'
' Entry
'
entry                   mov     t1,par                'get structure address
                                                      ' changed left number from 4 to 2 when head & tail indicies were changed from longs to words
                        add     t1,#2 << 2            'skip past heads and tails, address size of word, 2, multiplied by 4 via shift left of 2

                        rdlong  t2,t1                 'get rx_pin
                        mov     rxmask,#1
                        shl     rxmask,t2

                        add     t1,#4                 'get tx_pin
                        rdlong  t2,t1
                        mov     TxPinMask,#1
                        shl     TxPinMask,t2

                        add     t1,#4                 'get rxtx_mode
                        rdlong  rxtxmode,t1

                        add     t1,#4                 'get bit_ticks
                        rdlong  bitticks,t1

                        add     t1,#4                 'get buffer_ptr
                        rdlong  rxbuff,t1
                        mov     txbuff,rxbuff
                        add     txbuff,#128           'must match SIZE of input buffer

                        test    rxtxmode,#%100  wz    'init tx pin according to mode (z = not tri state?)
                        test    rxtxmode,#%010  wc    '                              (c = invert tx?    )
        if_z_ne_c       or      outa,TxPinMask
        if_z            or      dira,TxPinMask           'make the transmit pin an output now only if we're not doing tri state

                        mov     txcode,#transmit      'initialize ping-pong multitasking
'
'
' Receive
'
receive                 jmpret  rxcode,txcode         'run a chunk of transmit code, then return

                        test    rxtxmode,#%001  wz    'wait for start bit on rx pin
                        test    rxmask,ina      wc    '                              (c = RX pin low?   )
        if_z_eq_c       jmp     #receive

                        mov     rxbits,#9             'ready to receive byte
                        mov     rxcnt,bitticks
                        shr     rxcnt,#1
                        add     rxcnt,cnt

:bit                    add     rxcnt,bitticks        'ready next bit period

:wait                   jmpret  rxcode,txcode         'run a chuck of transmit code, then return

                        mov     t1,rxcnt              'check if bit receive period done
                        sub     t1,cnt
                        cmps    t1,#0           wc
        if_nc           jmp     #:wait

                        test    rxmask,ina      wc    'receive bit on rx pin
                        rcr     rxdata,#1
                        djnz    rxbits,#:bit

                        shr     rxdata,#32-9          'justify and trim received byte
                        and     rxdata,#$FF
                        test    rxtxmode,#%001  wz    'if rx inverted, invert byte
        if_nz           xor     rxdata,#$FF

                        'save received byte and inc head
                        rdword  t2,par                  ' get the current receive 'head' index's value (zero extended), now read only word, used to read long
                        add     t2,rxbuff               ' add index to buffer base address
                        wrbyte  rxdata,t2               ' (!?) is the address really ready yet? I am surprised there is not inbetween instruction
                        sub     t2,rxbuff               ' get back to the head index's value
                        add     t2,#1                   ' increment the receive index
                        and     t2,#$7F                 ' do remanider function for buffer that has a size equal to a power of 2, clips off the overflow bit
                                                        ' depending on SIZE of buffer, #s0F is for 16 byte buffer, $s7F is for 128  bytes
                        wrword  t2,par                  ' report back the new receive head index, now just a word, used to be a long

                        jmp     #receive                'byte done, receive next byte
'
'
' Transmit
'
transmit                jmpret  txcode,rxcode           'run a chunk of receive code, then return

                        mov     t1,par                  ' check for head <> tail, first we get hub address of rx head into t1
                        add     t1,#2 << 1              ' calculate hub address of tx head, address size of words, 2 mulitplied by 2 via shift left 1
                        rdword  t2,t1                   ' now only reading a word, used to be a long
                        add     t1,#2 << 0              ' calculate hub address of tx tail, address size of 2, qunaitity of 1, so no shift left at all
                        rdword  t3,t1                   ' get tx tail index value, now only reading a word, used to be a long
                        cmp     t2,t3           wz
        if_z            jmp     #transmit

                        'get byte and inc tail
                        add     t3,txbuff               ' add tail index value to address of transmit buffer base
                        rdbyte  txdata,t3               ' get one byte from hub's transmit buffer
                        sub     t3,txbuff               ' subtract buffer address to get tail index value again
                        add     t3,#1                   ' increment transmit tail index value
                        and     t3,TxSizeMask                 ' do remanider function for buffer that has a size equal to a power of 2, clips off the overflow bit
                                                        ' depending on SIZE of buffer, #s0F is for 16 byte buffer
                        wrword  t3,t1                   'store new tail index value back into hub, used to write long, now write only a word

                        or      txdata,#$100            'ready byte to transmit
                        shl     txdata,#2
                        or      txdata,#1
                        mov     txbits,#11
                        mov     txcnt,cnt

:bit                    test    rxtxmode,#%100  wz      'output bit on tx pin according to mode
                        test    rxtxmode,#%010  wc
        if_z_and_c      xor     txdata,#1
                        shr     txdata,#1       wc
        if_z            muxc    outa,TxPinMask
        if_nz           muxnc   dira,TxPinMask
                        add     txcnt,bitticks          'ready next cnt

:wait                   jmpret  txcode,rxcode           'run a chunk of receive code, then return

                        mov     t1,txcnt                'check if bit transmit period done
                        sub     t1,cnt
                        cmps    t1,#0           wc
        if_nc           jmp     #:wait

                        djnz    txbits,#:bit            'another bit to transmit?

                        jmp     #transmit               'byte done, transmit next byte

' initialaized data for putting into assembly cog
TxSizeMask long TxBufSize-1
'
'
' Uninitialized data
'
t1                      res     1
t2                      res     1
t3                      res     1

rxtxmode                res     1
bitticks                res     1

rxmask                  res     1
rxbuff                  res     1
rxdata                  res     1
rxbits                  res     1
rxcnt                   res     1
rxcode                  res     1

TxPinMask                  res     1
txbuff                  res     1
txdata                  res     1
txbits                  res     1
txcnt                   res     1
txcode                  res     1
FIT 496 ' make compiler generate warning if program is too big
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

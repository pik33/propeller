{{
Wii Classic Controller Driver Demo Object v1.0
By Pat Daderko (DogP)

Based on a Wii nunchuck example project from John Abshier, which was based on code originally by João Geada

This demo object repeatedly polls the Wii Classic Controller and writes the controller data to the
serial port (at 115200bps), reusing the pins used for programming.   

Diagram below is showing the pinout looking into the connector (which plugs into the Wii Remote)
 _______ 
| 1 2 3 |
|       |
| 6 5 4 |
|_-----_|

1 - SDA 
2 - 
3 - VCC
4 - SCL 
5 - 
6 - GND

This is an I2C peripheral, and requires a pullup resistor on the SDA line
If using a prop board with an I2C EEPROM, this can be connected directly to pin 28 (SCL) and pin 29 (SDA)

Digital controller bits:
0: R fully pressed
1: Start
2: Home
3: Select
4: L fully pressed
5: Down
6: Right
7: Up
8: Left
9: ZR
10: x
11: a
12: y
13: b
14: ZL
}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

'Digital controller bits:
'AND with button data to check if pressed (i.e.: if classic.buttons&TRIG_R)
TRIG_R    = 1<<0  ' R fully pressed
BTN_STA   = 1<<1  ' Start
BTN_HOME  = 1<<2  ' Home
BTN_SEL   = 1<<3  ' Select
TRIG_L    = 1<<4  ' L fully pressed
PAD_D     = 1<<5  ' Down
PAD_R     = 1<<6  ' Right
PAD_U     = 1<<7  ' Up
PAD_L     = 1<<8  ' Left
BTN_ZR    = 1<<9  ' ZR
BTN_X     = 1<<10 ' x
BTN_A     = 1<<11 ' a
BTN_Y     = 1<<12 ' y
BTN_B     = 1<<13 ' b
BTN_ZL    = 1<<14 ' ZL

OBJ
  classic : "ClassicCtrl"
  uart : "Extended_FDSerial"
  
PUB init
   uart.start(31, 30, 0, 115200) 'start UART at 115200 on programming pins
   classic.init(28,29) 'initialize I2C Classic Controller on existing I2C pins
   mainLoop 'run main app

PUB mainLoop
    repeat
      classic.readClassic 'read data from controller

      'output data read to serial port
      uart.dec(classic.joyLX)
      uart.tx(44)
      uart.dec(classic.joyLY)
      uart.tx(44)
      uart.dec(classic.joyRX)
      uart.tx(44)
      uart.dec(classic.joyRY)
      uart.tx(44)
      uart.dec(classic.shoulderL)
      uart.tx(44)
      uart.dec(classic.shoulderR)
      uart.tx(44)
      uart.hex(classic.buttons,4)  
      uart.tx(13)            
      waitcnt(clkfreq/64 + cnt) 'wait for a short period
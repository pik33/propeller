───────────────────────────────────────
Parallax Semiconductor Propeller Chip Project Archive
───────────────────────────────────────
 
This archive contains the driver for the Programmable Sound Generator by Texas Instruments SN76489. 
This chip was used in the eighties as sound chip for many arcade games and game console. 
The version of the driver included is updated to be used together with ZiCOG ans qZ80 emulators.

The code is written in Propeller assembly and has been reduced and optimized to take only 142 longs 
of program memory and 16 longs of shared memory for its registers. The driver, once started, listens 
to the io_port location set for the Z80 emulation. 
As soon as it finds the number of its port ( in this case $7F ) it processes the data byte carried on 
the location of the io_port.

It can be used also alone by accessing it as if it was the z80 doing it. The driver is well commented 
and with the demos included you can play some VGM music and also some sound effects.
 
 Enjoy it!



 Projects :  "VGM_Player_027"
             "Sound_Explosions.spin"
             "Sound_Bounces.spin"
             
 Archived :  15/10/2012 at 10.56.21 a.m.

     Tool :  Propeller Tool version 1.3.2


 Note: In order to execute the VGM Player program you need to format a micro SD card with a FAT file system
       and put the content of the folder "SD_CARD" inside the root. The SD cart must be < 4GB
        
            VGM_Player_027.spin
            Sound_Explosions.spin
            Sound_Bounces.spin
              │
              ├──Cog_SPI_Driver_014.spin
              │
              ├──SN76489_031.spin
              │
              ├──JTC_Tile_Drv.spin
              │    │
              │    ├──JB_tv_02.spin
              │    │
              │    ├──JTC_Tile_Renderer.spin
              │    │
              │    └──tile.dat
              │
              └──Serial_keyboard_010.spin


────────────────────
Parallax Inc., dba Parallax Semiconductor
www.parallaxsemiconductor.com
support@parallaxsemiconductor.com
USA 916.632.4664
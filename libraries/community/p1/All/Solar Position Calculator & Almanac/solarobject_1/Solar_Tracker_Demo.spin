''********************************************
''*  Sun_Tracker_Demo                        *
''*  Solar Calculator Object                 *
''*  Author: Gregg Erickson                  *
''*  December 2011                           *
''*  See MIT License for Related Copyright   *
''*  See end of file and objects for .       *
''*  related copyrights and terms of use     *
''*                                          *
''*  This uses code from FullFloat32 &       *
''*  equations and equations from a          *
''*  version of "Solar Energy Systems        *
''*  Design" by W.B.Stine and R.W.Harrigan   *
''*  (John Wiley and Sons,Inc. 1986)         *
''*  retitled "Power From The Sun"           *
''*  http://www.powerfromthesun.net/book.html*
''********************************************

{{ This Demonstrates the use of the Solar Object to
calculate the azimuth and angle of the sun's
position and solar time then outputs it to the
Parallax Serial Terminal and a 2x16 LCD as well as
drivingt two servos for a two axis mini solar panel
drive system.


The solar object calculates a good approximation
of the position (altitude and azimuth) of the sun
at any time (local clock or solar) during the day
as well as events such as solar noon, sunrise,
sunset, twilight(astronomical, nautical, civil),
and daylength. Derived values such as the equation
of time, time meridians, hour angle, day of the year
and declination are also provided.

Please note: The code is fully documented and is purposely less
compact than possible to allow the user to follow and/or
modify the formulas and code.
}}
{The inputs include date, local/solar time,latitude,
longitude and daylight savings time status. Adjustments
are made for value local time zones, daylight savings
time, leap year, seasonal tilt of the earth,
retrograde of earth rotation, and ecliptic earth
orbit (Perihelion,apihelion) and atmospheric refraction.

Potential Level of Error: The equations used are good
approximations adequate for small photovoltaic panels,
flat panel or direct apeture thermal collectors. A quick
check against NOAA data indicates a match within a
degree and minute.  More refinement may be needed for
concentrating collectorsthat focus light through a lense
or parabolic reflector. The equation of time formula
achieves an error rate of roughly 16 seconds with a max of
38 seconds. The error would need to have an average error
in the seconds of degrees and seconds of time to effectively
target the whole image on the target.

Additional error from mechanical tracking devices will
also add to the error.  Some report that these low
precision forumulas may be within a degree of angle and
a minute or so of time compared to the apparent direction
from the perspective of the observer. However, precise
verification has not been verified as calculated by this
code and/or processor. The error also increases as the
altitude gets closer to the horizon due to atmospheric
disortion and diffraction, especially at sunset and sunrise.
It may be intuitive but the accuracy is not valid when
the sun dips below the horizon such as beyond the artic
and antartic circles or at night.

In summary, this code is appropriate for two axis flat
panel tracking applications where accuracy within a degree
or two would result in negligible losses according to the
cosine effect. It would also be an effective "predictive"
complement to light sensor tracking algorims that can "hunt"
or require rapid movement during cloudy condition.  The
user should verify function, accuracy and validity of
output for any specific application.  No warranty is implied
or expressed.  Use at your own risk...

}


CON
  _clkmode = xtal1 + pll16x  '80 mhz, compensates for slow FP Math
  _XinFREQ = 5_000_000       'Can run slower to save power


  _leftServoPin = 8            'Servo Pin for Azimuth
  _rightServoPin = 9           'Servo Pin for Altitude
  _updateFrequencyInHertz = 50 'Servo Update Frequency
  leftServospan=169.0          'Azimth Angle in Degrees that Servo Rotates
  LSP_scalar=1077              'Scalar when Servo is Positive, adjust using max angle for correct physical angle
  LSN_scalar=1040              'Scalar when Servo is Negative, adjust using max angle for correct physical angle
  rightServospan=160.0         'Angle in Degrees that Altitude Servo Rotates
  RSP_scalar=1084              'Scalar when Servo is Positive, adjust using max angle for correct physical angle
  RSN_scalar=1029              'Scalar when Servo is Negative, adjust using max angle for correct physical angle


VAR

'-------Angular Variables----(FP=Floating Point, I=Integer)
Long Latitude, Longitude    'FP:Latitude & Longitude of Observer
Long Altitude, Azimuth      'FP:Angle of Sun Above Horizon and Heading
Long SunriseAz,SunsetAz     'FP:Azimuth at Sunrise and Sunset
Long HourAngle              'FP:Angle ofSun from Noon, Due to Rotation
Long HorizonHourAngle       'FP:HourAngle at Sunset and Sunrise
Long HorizonRefraction      'FP:Angle of Atmospheric Refraction at Sunset and Sunrise
Long Declination            'FP:Tilt of Earth Relative to Solar Plain
Long North,East,Height      'FP:Northerning, Easterning, Height of Target A
Long HelioAz,HelioAlt,HelioE'FP:Angle to Point a Heliostat to Hit Target A with Error
Long Theta                  'FP:Angle of Reflect Between Sun and Target Vectors
Long Distance,ReflectionSize'FP:Distance through air to target and ImageSize
Long MirrorSize             'FP:Size of Heliostat Mirror
Long Junkvariable           'just a place holder
Long Path,Flight


'-------Time Variable--------(FP=Floating Point, I=Integer)
Long Sunrise,Sunset         'FP:Solar Time at Sunrise and Sunset
Long LCT,SCT                'FP:Local Clock Time, Solar Clock Time
Long Meridian               'FP:Longitude of Time Zone Meridian
Long Month,Day,Year         'Integer:Year,Month & Day of the Year
Long NDays                  'FP:Day of Year starting with Jan 1st=1
Long Hour,Minute, Second,AMPM 'Integer:Local Time Hour, Min & Sec
Long SolarTime,ClockTime    'FP:Local Time in Hours Adj to Solar Noon
Long DST                    'FP:Day Light Saving Time, =1.0 if true
Long Daylight               'FP:Hours of Daylight in a Day
Long EOT,EOT2,EOT3          'FP:Equation of Time, Apparent Shift in
                               'Solar Noon Due to Earth's Orbital
                               'Elipse from Apogee(far) to Perigee(near)

Long ClkHr,ClkMin,ClkSec    'I:local clock in hours, minutes, seconds
Long LocalRise,LocalSet     'Local Clock Time for Sunrise and Sunset
Long TimeString
Byte DateStamp[11], TimeStamp[11]
Long ServoPulse

Obj

  S:    "Solar2.4"                 'Solar Almanac Object
  PST:  "Parallax Serial Terminal" 'For Output & Troubleshooting
  term: "Simple_Serial"            'Serial Output for 2x16 LCD

  FStr: "FloatString"              'Conversions for Output
  Fmath:"Float32Full"              'The Full Version is needed for ATAN,ACOS,ASIN
  Clock:"PropellerRTC_Emulator_Modified" ' Provide Clock Emulator
  ser:  "PWM2C_SEREngine.spin"     'Servo Object


Pub main| n

'-------------------Start Objects-------------
Pst.start(57600)   'Start Parallax Serial Terminal
S.start            'Start Solar Object
Fmath.start        'Start Floating Point Math Object
term.init(27,27,19_200)     ' Initiate Simple Serial to 2x16 LCD
Clock.Start(@TimeString)    ' Initiate Prop Clock
ifnot(ser.SEREngineStart(_leftServoPin, _rightServoPin, _updateFrequencyInHertz))
    reboot                  ' Start Servo Object


'----------------Set Clock-----------------------

Clock.Suspend               '' Suspend Clock while being set
Clock.SetYear(12)           '' 00 - 31 ... Valid from 2000 to 2031
Clock.SetMonth(1)           '' 01 - 12 ... Month
Clock.SetDate(16)           '' 01 - 31 ... Date
Clock.SetHour(12)           '' 01 - 12 ... Hour
Clock.SetMin(00)            '' 00 - 59 ... Minute
Clock.SetSec(00)            '' 00 - 59 ... Second
Clock.SetAMPM(1)            '' 0 = AM ; 1 = PM
Clock.Restart               '' Start Clock after being set

'-------------------Set Defaults--------------

'-------------------Set Time and Date Defaults--------------
'Year:=2012            'I: Year Divisable by 4 are leap years
'Month:=1              'I: Month Set for Testing
'Day:=26               'I: Day Set for Testing
DST:=0.0               'FP:Daylight Saving, 1.0=true, 0.0=false

'--------- Set Location to 599 Menlo Park, Rocklin CA----------
Longitude:=121.296104  'FP:  (Positive to West)
Latitude:=38.813112    'FP:

'---------- Set Heliostat Target ---------------------
North:=100.0           'FP: Distance of Heliostat Target toward South
East:=10.0             'FP: Distance of Heliostat Target West of Center
Height:=3.0            'FP: Height of Heliostat Target Above Heliostat
MirrorSize:=5.0

     'Calculate Ground Path and Air/Flight Distance to Target
      Path:=fmath.fsqr(fmath.fadd(fmath.fmul(North,North),fmath.fmul(East,East)))
      Flight:=fmath.fsqr(fmath.fadd(fmath.pow(height,2.0),fmath.pow(path,2.0)))

junkvariable:=s.get_spreading_loss(MirrorSize,Flight,@ReflectionSize)



'-------------------Print Header to PST-----------------
pst.char(16)

pst.home
pst.char($0D)
pst.char($0D)
pst.str(string("----Location Info----"))
pst.char($0D)
pst.str(String("599 Menlo Park, Rocklin CA 95765"))
pst.char($0D)
pst.str(String("Latitude="))
pst.str(FStr.FloatToString(latitude))
pst.char($0D)
pst.str(String("Longitude="))
pst.str(FStr.FloatToString(longitude))
pst.char($0D)
'-------- Print Heliostat Info -------
pst.char($0D)
pst.str(string("----Heliostat----"))
pst.char($0D)
pst.str(String("Heliostat Mirror Size="))
pst.str(FStr.FloatToString(MirrorSize))
pst.char($0D)
pst.str(String("Reflection Size="))
pst.str(FStr.FloatToString(ReflectionSize))
pst.char($0D)


pst.str(String("Distance North of Target="))
pst.str(FStr.FloatToString(North))
pst.char($0D)
pst.str(String("Distance East of Target="))
pst.str(FStr.FloatToString(East))
pst.char($0D)
pst.str(String("Height up to Target="))
pst.str(FStr.FloatToString(Height))
pst.char($0D)

'--------------Hourly Direction to Sun -------------

pst.char($0D)
pst.str(String(" ---TimeStamp------     ----- Solar----      ---Servo---    ---Heliostat Angles----  --% Loss--  ------Dilutions------"))
pst.char($0D)
pst.str(String("Date        Clock       Time    Alt   Azi    Tilt  Swivel  Azimuth  Altitude  Theta    Cosine    Spreading   Vert.Landing"))
pst.char($0D)
pst.str(String("-----------------------------------------------------------------------------------------------------------------------"))
pst.char($0D)

repeat

      AMPM:=clock.getAMPM
      Year:=2000+clock.getyear
      Month:=clock.getmonth
      Day:=clock.getday

      Hour:=fmath.fdiv(fmath.ffloat(clock.getminute),60.0)
      Hour:=fmath.fadd(Hour,fmath.fdiv(fmath.ffloat(clock.getseconds),3600.0))
      Hour:=fmath.fadd(Hour,fmath.ffloat(clock.gethour))
      If AMPM==1 and clock.gethour<12
         Hour:=fmath.fadd(Hour,12.0)
      If AMPM==0 and clock.gethour==12
         Hour:=fmath.fadd(Hour,12.0)

      '------ Date Calculations
      NDays:=fmath.ffloat(s.Day_Number(Year,Month,Day))
      EOT:=s.Equation_of_Time2(NDays)
      Declination:=s.Declination_Degrees(NDays)
       
      '-------Time Calculations
      Meridian:=s.Meridian_Calc(Longitude)
      solartime:=s.Solar_Clock_Time(hour,Longitude,Meridian,EOT,DST)
      LCT:=s.Local_Clock_Time(SolarTime,Longitude,Meridian,EOT,DST)
      SCT:=s.Solar_Clock_Time(LCT,Longitude,Meridian,EOT,DST)

      HourAngle:=s.Hour_Angle_SolarTime(SolarTime)
      If AMPM==0 and clock.gethour==12
         Hour:=fmath.fsub(Hour,12.0)



      ClkHr:=s.Extract_Hour(LCT)
      ClkMin:=s.Extract_Minute(LCT)

      '-------Solar Position Calculations
      Altitude:=s.Altitude_Calc (declination,Latitude,HourAngle)
      Altitude:=fmath.fadd(Altitude,s.refraction(Altitude))
      Altitude:=fmath.fdiv(fmath.ffloat(fmath.fround(fmath.fmul(Altitude,100.0))),100.0)

      Azimuth:=s.Azimuth_Calc(Declination,Latitude,HourAngle,Altitude)
      Azimuth:=fmath.fdiv(fmath.ffloat(fmath.fround(fmath.fmul(Azimuth,100.0))),100.0)

      HelioE:=s.Helio_Altitude(@HelioAz,@HelioAlt,@Theta,@Distance,Azimuth,Altitude,North,East,height)



      Clock.ParseDateStamp(@DateStamp)
      Clock.ParseTimeStamp(@TimeStamp)




      pst.str(@datestamp)
      pst.str(String(", "))


      pst.str(@timestamp)
      pst.str(String(", "))

      if s.extract_hour(SCT)<24
         pst.dec(s.extract_hour(SCT))
      else
         pst.dec(s.extract_hour(SCT)-24)

      pst.str(String(":"))
      if s.Extract_Minute(SCT)<10
          pst.char("0")
      pst.dec(s.extract_minute(SCT))
      pst.str(String(", "))

      pst.str(FStr.FloatToString(Altitude))
      pst.str(String(", "))
      pst.str(FStr.FloatToString(Azimuth))
      pst.str(String(", "))

      term.tx($80)

      term.str(string("Azimuth Altitude"))

      term.tx($94)
      term.str(string("                "))
      term.tx($94)
      term.str(FStr.FloatToString(Azimuth))
      term.str(string("   "))
      term.str(FStr.FloatToString(Altitude))
      waitcnt(clkfreq+cnt)

 
  
      Altitude:=fmath.fsub(altitude,48.0)   ' Adjustment to reflect angle of servo horn attachment
      servopulse:=fmath.ftrunc(fmath.fmul(fmath.fdiv(Altitude,rightservospan),1500.0))
       if servopulse>0 'Harware Adjustment to match specific servo
         servopulse:=RSP_scalar*servopulse/1000
       else
         servopulse:=RSN_scalar*servopulse/1000 
     servopulse:=650#>(1500+(ServoPulse))<#2250
      pst.dec(servopulse)
      pst.str(String(", "))
      ser.rightPulseLength(ServoPulse)



      Azimuth:=fmath.fsub(Azimuth,188.0)      ' Adjustment to reflect angle of servo horn attachment
      servopulse:=fmath.ftrunc(fmath.fmul(fmath.fdiv(Azimuth,leftservospan),1500.0))
      if servopulse>0 'Harware Adjustment to match specific servo
         servopulse:=LSP_scalar*servopulse/1000
      else
         servopulse:=LSN_scalar*servopulse/1000  
      servopulse:=650#>(1500-(ServoPulse))<#2250
      pst.dec(servopulse)
      ser.leftPulseLength(ServoPulse)

      pst.str(String(", "))
      pst.str(FStr.FloatToString(HelioAz))
      pst.str(String(", "))
      pst.str(FStr.FloatToString(HelioAlt))
      pst.str(String(", "))
      pst.str(FStr.FloatToString(Theta))
      pst.str(String(", "))
      pst.str(FStr.FloatToString(s.get_cosine_loss(Theta)))
      pst.str(String(", "))
      pst.str(FStr.FloatToString(s.get_spreading_loss(MirrorSize,Distance,@ReflectionSize)))
      pst.str(String(", "))
      pst.str(FStr.FloatToString(fmath.fmul(100.0,fmath.fsub(1.0,fmath.cos(fmath.radians(HelioAlt))))))

      pst.char($0D)


DAT
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
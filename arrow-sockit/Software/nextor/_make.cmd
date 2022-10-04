@echo off
echo Making no HWDS
..\..\sjasmplus-1.15.1.win\sjasmplus --nologo -DHWDS=0 --lst=Driver.lst DriverM.asm
IF ERRORLEVEL 1 GOTO error

mknexrom Nextor-2.1.0-beta1.base.dat NEXTOR.ROM /d:driver.bin /m:Mapper.ASCII16.bin
IF ERRORLEVEL 1 GOTO error
rem copy NEXTOR.ROM ..\..\Support\SD\MSX1FPGA

echo Making HWDS
..\..\sjasmplus-1.15.1.win\sjasmplus --nologo -DHWDS=1 --lst=DriverH.lst DriverM.asm
IF ERRORLEVEL 1 GOTO error

mknexrom Nextor-2.1.0-beta1.base.dat NEXTORH.ROM /d:driver.bin /m:Mapper.ASCII16.bin
IF ERRORLEVEL 1 GOTO error
rem copy NEXTORH.ROM ..\..\Support\SD\MSX1FPGA
goto ok

:error
echo Error!

:ok
echo.
pause
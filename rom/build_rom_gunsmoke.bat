rem version 2.20 - 2019/08/16 by Bruno Silva
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2 
Title Gun.Smoke's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

:MENU
cls
echo                                              __      
echo    ____ ___  ______    _________ ___  ____  / /_____ 
echo   / __ `/ / / / __ \  / ___/ __ `__ \/ __ \/ //_/ _ \
echo  / /_/ / /_/ / / / / (__  ) / / / / / /_/ / ,^< /  __/
echo  \__, /\__,_/_/ /_(_)____/_/ /_/ /_/\____/_/^|_^|\___/ 
echo /____/                                               

echo.
if %merged% EQU 0 (
echo Copy Mame Non-Merged set files to !pwd!MAME folder
) else (
echo Copy Mame Merged set files to !pwd!MAME folder
)
echo.
echo This bat file was tested with mame version 0.212
echo.
echo Press H for Help
echo.
echo ** MENU **
echo 1 - Gun.Smoke (World, 851115) - Default
echo 2 - Gun.Smoke (Japan, 851115)
echo 3 - Gun.Smoke (US, 851115, set 1)
echo 4 - Gun.Smoke (US, 851115, set 2)
echo 5 - Gun.Smoke (US, 860408)
echo 6 - Gun.Smoke (World, 851115) (bootleg)

echo.
if %merged% EQU 0 (
echo C - Change from Non-Merged to Merged MAME ROM SET
) else (
echo C - Change from Merged to Non-Merged MAME ROM SET
)
if "%verb%" EQU "" (
echo V - Set verbose Off
) else (
echo V - Set verbose On
)
echo H - HELP
echo Q - Quit


if NOT EXIST "!pwd!MAME" mkdir "!pwd!MAME" 2> nul

echo.
SET /P M="Choose option and then press ENTER (or Q to quit): "
IF '%M%'=='1' GOTO GUNSMOKE
IF '%M%'=='2' GOTO GUNSMOKEJ
IF '%M%'=='3' GOTO GUNSMOKEUA
IF '%M%'=='4' GOTO GUNSMOKEUB
IF '%M%'=='5' GOTO GUNSMOKEU
IF '%M%'=='6' GOTO GUNSMOKEB

echo.
IF '%M%'=='c' GOTO CHANGEMERGED
IF '%M%'=='C' GOTO CHANGEMERGED
IF '%M%'=='h' GOTO HELP
IF '%M%'=='H' GOTO HELP
IF '%M%'=='v' GOTO VERBOSE
IF '%M%'=='V' GOTO VERBOSE
IF '%M%'=='q' GOTO QUIT
IF '%M%'=='Q' GOTO QUIT

GOTO MENU

:GUNSMOKE
set zip1m=MAME\gunsmoke.zip
set ifilesm=gs03.09n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set zip1=MAME\gunsmoke.zip
set ifiles=gs03.09n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set md5valid=a659c3df76fc4374a4af1ca2187faa8f
set ofile=jtgun.rom
set fullname=Gun.Smoke (World, 851115) - Default
GOTO START

:GUNSMOKEJ
set zip1m=MAME\gunsmoke.zip
set ifilesm=gunsmokej\gsj_03.09n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set zip1=MAME\gunsmokej.zip
set ifiles=gsj_03.09n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set md5valid=f06442c96d2b9b6115f45c30bb18cced
set ofile=Gun.Smoke (Japan, 851115).rom
set fullname=Gun.Smoke (Japan, 851115)
GOTO START

:GUNSMOKEUA
set zip1m=MAME\gunsmoke.zip
set ifilesm=gunsmokeua\gsr_03a.9n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set zip1=MAME\gunsmokeua.zip
set ifiles=gsr_03a.9n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set md5valid=75869a86ddd280f7a3387373723b643c
set ofile=Gun.Smoke (US, 851115, set 1).rom
set fullname=Gun.Smoke (US, 851115, set 1)
GOTO START

:GUNSMOKEUB
set zip1m=MAME\gunsmoke.zip
set ifilesm=gunsmokeub\gsr_03.9n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set zip1=MAME\gunsmokeub.zip
set ifiles=gsr_03.9n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set md5valid=dc8ee9d839375d648795f74794bb70b6
set ofile=Gun.Smoke (US, 851115, set 2).rom
set fullname=Gun.Smoke (US, 851115, set 2)
GOTO START

:GUNSMOKEU
set zip1m=MAME\gunsmoke.zip
set ifilesm=gunsmokeu\gsa_03.9n+gunsmokeu\gs04.10n+gunsmokeu\gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set zip1=MAME\gunsmokeu.zip
set ifiles=gsa_03.9n+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set md5valid=f8a2d3be6059d682867fd0137a57bd04
set ofile=Gun.Smoke (US, 860408).rom
set fullname=Gun.Smoke (US, 860408)
GOTO START

:GUNSMOKEB
set zip1m=MAME\gunsmoke.zip
set ifilesm=gunsmokeb\3.ic85+gs04.10n+gs05.12n+gs02.14h+gs01.11f+gs14.11c+gs13.06c+gs09.06a+gs12.05c+gs08.05a+gs11.04c+gs07.04a+gs10.02c+gs06.02a+gs22.06n+gs18.06l+gs21.04n+gs17.04l+gs20.03n+gs16.03l+gs19.01n+gs15.01l+g-01.03b+g-02.04b+g-03.05b+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set zip1=MAME\gunsmokeb.zip
set ifiles=3.ic85+4.ic86+5.ic87+2.ic41+1.ic39+14.ic25+13.ic21+9.ic04+12.ic20+8.ic03+11.ic19+7.ic02+10.ic18+6.ic01+22.ic134+18.ic115+21.ic133+17.ic114+20.ic132+16.ic113+19.ic131+15.ic112+prom.ic3+prom.ic4+prom.ic5+g-04.09d+g-06.14a+g-07.15a+g-09.09f+g-08.08f+g-10.02j+g-05.01f
set md5valid=c2dbd27e0a05e6575d1ff83831051a73
set ofile=Gun.Smoke (World, 851115) (bootleg).rom
set fullname=Gun.Smoke (World, 851115) (bootleg)
GOTO START


:CHANGEMERGED
if %merged% EQU 0 (
	set /A merged=1
	echo.
	echo You will now use Merged MAME ROM SET. Press a key to continue...
) else (
	set /A merged=0
	echo.
	echo You will now use Non-Merged MAME ROM SET. Press a key to continue...
)
pause > nul
GOTO MENU

:VERBOSE
if "%verb%" EQU "" (
	set "verb=> nul"
	echo.
	echo Verbose is Off. Press a key to continue...
) else (
	set "verb="
	echo.
	echo Verbose is On. Press a key to continue...
)
pause > nul
GOTO MENU

:START

rem =====================================
echo.
echo.

if %merged% EQU 1 (
	set zip1=%zip1m%
	set ifiles=%ifilesm%
)


if NOT EXIST %zip1% GOTO ERRORZIP1
if NOT EXIST "!pwd!7za.exe" GOTO ERROR7Z
echo.
echo Starting creating rom for %fullname%
echo.
echo Unziping rom file...
echo.
"!pwd!7za" x -y -otmp %zip1% %verb%

	if !ERRORLEVEL! EQU 0 ( 
		cd tmp
		echo.
		echo Creating rom file...
		echo.
		copy /b /y /v %ifiles% "!pwd!%ofile%" %verb%
		
			if !ERRORLEVEL! EQU 0 ( 
				cd "!pwd!"
				
				set "md5="
					echo.
					echo Checking MD5...
					echo.				
					for /f "skip=1 tokens=* delims=" %%# in ('certutil -hashfile "!pwd!%ofile%" MD5') do (
						if not defined md5 (
							for %%Z in (%%#) do  (
								set "md5=%%Z"
							)
						)
					)	
			
				if "%md5valid%" EQU "!md5!" (
					echo.
					echo ** Process is complete! **
					echo.
					echo Copy "%ofile%" into SD card
				) else (
					echo.
					echo ** PROBLEM IN ROM **
					echo.
					echo MD5 DOESN'T MATCH! CHECK YOU ZIP FILE
					echo It could work anyway...
					echo.
					echo MD5 is !md5! but should be "%md5valid%"
				)
			) else (
				GOTO ERRORCOPY
			)
		cd !pwd!
		rmdir /s /q tmp	
		GOTO END		
	) else (
		GOTO ERRORUNZIP
	)

:ERRORZIP1
	echo.
	echo Error: Cannot find "%zip1%" file.
	GOTO END
	
:ERROR7Z
	echo.
	echo Error: Cannot find "7za.exe" file. Put it in the same directory as "%~nx0"!
	GOTO END

:ERRORCOPY
	cd !pwd!
	rmdir /s /q tmp > nul
	echo.
	echo Error: Problem creating rom!
	echo. 
	GOTO END

:ERRORUNZIP
	cd !pwd!
	rmdir /s /q tmp > nul
	echo.
	echo Error: problem unzipping file!
	echo. 
	GOTO END
	

:HELP
color 7
cls
echo                                              __      
echo    ____ ___  ______    _________ ___  ____  / /_____ 
echo   / __ `/ / / / __ \  / ___/ __ `__ \/ __ \/ //_/ _ \
echo  / /_/ / /_/ / / / / (__  ) / / / / / /_/ / ,^< /  __/
echo  \__, /\__,_/_/ /_(_)____/_/ /_/ /_/\____/_/^|_^|\___/ 
echo /____/                                               

echo.
echo HELP for this .bat file
echo.
echo ** Merged and Non-Merged mame roms **
echo By default this .bat file uses non-merged version of mame roms. You can change to merged version by pressing C in the menu
echo.
echo ** Verbose **
echo By default the .bat doesn't display the output of some commands (unzip/copy). You can see the output by pressing V in the menu.
echo.
echo ** Rom Creation **
echo Choose a number from the menu to create a rom from the zip files from mame. This .bat file checks the md5 for the rom created.
echo Having a different md5 doesn't mean that the rom doesn't work.
echo.
echo ** Copy Files to SD Card **
echo Copy jtgun.rom to SDCard's root or bootrom folder (mister) and the other roms to jtgun folder.
echo.
echo ** For reference **
echo.
echo Merged Set:
echo A merged set takes the parent set and one or more clone sets and puts them all inside the parent set^'s storage. To use the 
echo existing Pac-Man example, combining the Puckman, Midway Pac-Man (USA) sets, along with various bootleg versions - and combining 
echo it all into PUCKMAN.ZIP, would be making a merged set.
echo Remark: The parent games in a merged set DO NOT include BIOS or DEVICE files - they are separate files within the set (An example 
echo would be 100lions (No BIOS in the parent) and Galaga (No device file in the parent) - This is per MAME design.
echo.
echo Non-Merged Set:
echo A non-merged set is one that contains absolutely everything necessary for a given game to run in one ZIP file.
echo The non-merged set is ideal for those people that work on Arcade PCBs as ALL roms/devices/bios files are contained within the game. 
echo This set is also great for those that for instance create their own arcade cabinets and want to copy only very specific games to 
echo their PC/Rapsberry/Other, the game.zip file contain all the files needed, no more searching for the dependent parent files, BIOS 
echo files, device files - just copy galaga.zip and you are set.
echo.
echo.
echo Press a key to return to menu...
pause > nul
color 2 
GOTO MENU



:END
echo.
echo.
echo Press a key to return to menu...
pause > nul
GOTO MENU

:QUIT


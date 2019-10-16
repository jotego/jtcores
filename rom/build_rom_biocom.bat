rem version 2.20 - 2019/08/16 by Bruno Silva
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2 
Title Bionic Commando's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

if NOT EXIST "!pwd!NONMERGED" mkdir "!pwd!NONMERGED" 2> nul
if NOT EXIST "!pwd!MERGED" mkdir "!pwd!MERGED" 2> nul
if NOT EXIST "!pwd!7za.exe" copy "C:\Users\Developer\Desktop\Updates\Mister\bat\7za.exe" "!pwd!7za.exe" 2> nul

:MENU
cls
echo  ___   _   ___   _      _   __        __    ___   _      _       __    _      ___   ___  
echo ^| ^|_) ^| ^| / / \ ^| ^|\ ^| ^| ^| / /`      / /`  / / \ ^| ^|\/^| ^| ^|\/^|  / /\  ^| ^|\ ^| ^| ^| \ / / \ 
echo ^|_^|_) ^|_^| \_\_/ ^|_^| \^| ^|_^| \_\_,     \_\_, \_\_/ ^|_^|  ^| ^|_^|  ^| /_/--\ ^|_^| \^| ^|_^|_/ \_\_/ 

echo.
if %merged% EQU 0 (
echo Copy Mame Non-Merged set files to !pwd!MAME folder
) else (
echo Copy Mame Merged set files to !pwd!MAME folder
)
echo.
echo This bat file was tested with mame version 0214
echo.
echo Press H for Help
echo.
echo ** MENU **
echo 1 - Bionic Commando (Euro) - Default
echo 2 - Bionic Commando (US set 1)
echo 3 - Bionic Commando (US set 2)
echo 4 - Bionic Commandos (bootleg, set 2)
echo 5 - Top Secret (Japan, old revision)
echo 6 - Top Secret (Japan, revision B)

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
IF '%M%'=='1' GOTO BIONICC
IF '%M%'=='2' GOTO BIONICC1
IF '%M%'=='3' GOTO BIONICC2
IF '%M%'=='4' GOTO BIONICCBL2
IF '%M%'=='5' GOTO TOPSECRT
IF '%M%'=='6' GOTO TOPSECRT2

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

:BIONICC
set zip1m=MERGED\bionicc.zip
set ifilesm=tse_02.1a+tse_03.2a+tse_04.1b+tse_05.2b+ts_01b.4e+tsu_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+tsu_06.4l+tsu_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+tsu_07.5l+tsu_07.5l+tse_22.17j+tsu_21.15j+tse_20.13j+tsu_19.11j+tse_15.13g+tsu_14.11g+tse_10.13f+tsu_09.11f+ts.2f+63s141.18f
set zip1=NONMERGED\bionicc.zip
set ifiles=tse_02.1a+tse_03.2a+tse_04.1b+tse_05.2b+ts_01b.4e+tsu_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+tsu_06.4l+tsu_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+tsu_07.5l+tsu_07.5l+tse_22.17j+tsu_21.15j+tse_20.13j+tsu_19.11j+tse_15.13g+tsu_14.11g+tse_10.13f+tsu_09.11f+ts.2f+63s141.18f
set md5valid=1e0d5946c2618f03a29e895fa7d987f0
set ofile=JTBIOCOM.rom
set fullname=Bionic Commando (Euro) - Default
GOTO START

:BIONICC1
set zip1m=MERGED\bionicc.zip
set ifilesm=bionicc1\tsu_02b.1a+bionicc1\tsu_03b.2a+bionicc1\tsu_04b.1b+bionicc1\tsu_05b.2b+ts_01b.4e+tsu_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+tsu_06.4l+tsu_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+tsu_07.5l+tsu_07.5l+bionicc1\tsu_22.17j+tsu_21.15j+bionicc1\tsu_20.13j+tsu_19.11j+bionicc1\tsu_15.13g+tsu_14.11g+bionicc1\tsu_10.13f+tsu_09.11f+ts.2f+63s141.18f
set zip1=NONMERGED\bionicc1.zip
set ifiles=tsu_02b.1a+tsu_03b.2a+tsu_04b.1b+tsu_05b.2b+ts_01b.4e+tsu_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+tsu_06.4l+tsu_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+tsu_07.5l+tsu_07.5l+tsu_22.17j+tsu_21.15j+tsu_20.13j+tsu_19.11j+tsu_15.13g+tsu_14.11g+tsu_10.13f+tsu_09.11f+ts.2f+63s141.18f
set md5valid=7cb34279e923e454f8524ba146398b49
set ofile=Bionic Commando (US set 1).rom
set fullname=Bionic Commando (US set 1)
GOTO START

:BIONICC2
set zip1m=MERGED\bionicc.zip
set ifilesm=bionicc2\tsu_02.1a+bionicc2\tsu_03.2a+bionicc2\tsu_04.1b+bionicc2\tsu_05.2b+ts_01b.4e+tsu_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+tsu_06.4l+tsu_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+tsu_07.5l+tsu_07.5l+bionicc1\tsu_22.17j+tsu_21.15j+bionicc1\tsu_20.13j+tsu_19.11j+bionicc1\tsu_15.13g+tsu_14.11g+bionicc1\tsu_10.13f+tsu_09.11f+ts.2f+63s141.18f
set zip1=NONMERGED\bionicc2.zip
set ifiles=tsu_02.1a+tsu_03.2a+tsu_04.1b+tsu_05.2b+ts_01b.4e+tsu_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+tsu_06.4l+tsu_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+tsu_07.5l+tsu_07.5l+tsu_22.17j+tsu_21.15j+tsu_20.13j+tsu_19.11j+tsu_15.13g+tsu_14.11g+tsu_10.13f+tsu_09.11f+ts.2f+63s141.18f
set md5valid=576aee4c876c70772cabee6928ccc0ec
set ofile=Bionic Commando (US set 2).rom
set fullname=Bionic Commando (US set 2)
GOTO START

:BIONICCBL2
set zip1m=MERGED\bionicc.zip
set ifilesm=bioniccbl2\tsu_02.1a+bioniccbl2\3+bioniccbl2\tsu_04.1b+bioniccbl2\tsu_05.1d+bioniccbl\01.bin+bioniccbl2\ts_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+bioniccbl2\ts_06.4l+bioniccbl2\ts_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+bioniccbl2\ts_07.5l+bioniccbl2\ts_07.5l+tse_22.17j+tsu_21.15j+tse_20.13j+tsu_19.11j+tse_15.13g+tsu_14.11g+tse_10.13f+tsu_09.11f+ts.2f+63s141.18f
set zip1=NONMERGED\bioniccbl2.zip
set ifiles=tsu_02.1a+3+tsu_04.1b+tsu_05.1d+ts_01.4e+ts_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+ts_06.4l+ts_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+ts_07.5l+ts_07.5l+tse_22.17j+tsu_21.15j+tse_20.13j+tsu_19.11j+tse_15.13g+tsu_14.11g+tse_10.13f+tsu_09.11f+d8751h.bin+63s141.18f
set md5valid=680ca2b7dc94e60967b130a9da15253e
set ofile=Bionic Commandos (bootleg, set 2).rom
set fullname=Bionic Commandos (bootleg, set 2)
GOTO START

:TOPSECRT
set zip1m=MERGED\bionicc.zip
set ifilesm=bioniccbl\02l.bin+bioniccbl\02u.bin+bioniccbl\03l.bin+bioniccbl\03u.bin+bioniccbl\01.bin+bioniccbl2\ts_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+bioniccbl2\ts_06.4l+bioniccbl2\ts_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+bioniccbl2\ts_07.5l+bioniccbl2\ts_07.5l+topsecrt\ts_22.17j+topsecrt\ts_21.15j+topsecrt\ts_20.13j+topsecrt\ts_19.11j+topsecrt\ts_15.13g+topsecrt\ts_14.11g+topsecrt\ts_10.13f+topsecrt\ts_09.11f+ts.2f+63s141.18f
set zip1=NONMERGED\topsecrt.zip
set ifiles=ts_02.1a+ts_03.2a+ts_04.1b+ts_05.2b+ts_01.4e+ts_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+ts_06.4l+ts_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+ts_07.5l+ts_07.5l+ts_22.17j+ts_21.15j+ts_20.13j+ts_19.11j+ts_15.13g+ts_14.11g+ts_10.13f+ts_09.11f+ts.2f+63s141.18f
set md5valid=f75676c0b1c3abf5535b24e78390e01b
set ofile=Top Secret (Japan, old revision).rom
set fullname=Top Secret (Japan, old revision)
GOTO START

:TOPSECRT2
set zip1m=MERGED\bionicc.zip
set ifilesm=topsecrt2\ts_02b.1a+topsecrt2\ts_03b.2a+topsecrt2\ts_04b.1b+topsecrt2\ts_05b.2b+ts_01b.4e+bioniccbl2\ts_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+bioniccbl2\ts_06.4l+bioniccbl2\ts_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+bioniccbl2\ts_07.5l+bioniccbl2\ts_07.5l+topsecrt\ts_22.17j+topsecrt\ts_21.15j+topsecrt\ts_20.13j+topsecrt\ts_19.11j+topsecrt\ts_15.13g+topsecrt\ts_14.11g+topsecrt\ts_10.13f+topsecrt\ts_09.11f+ts.2f+63s141.18f
set zip1=NONMERGED\topsecrt2.zip
set ifiles=ts_02b.1a+ts_03b.2a+ts_04b.1b+ts_05b.2b+ts_01b.4e+ts_08.8l+ts_13.18f+ts_18.18g+ts_23.18j+ts_24.18k+ts_06.4l+ts_06.4l+ts_12.17f+ts_11.15f+ts_17.17g+ts_16.15g+ts_07.5l+ts_07.5l+ts_22.17j+ts_21.15j+ts_20.13j+ts_19.11j+ts_15.13g+ts_14.11g+ts_10.13f+ts_09.11f+ts.2f+63s141.18f
set md5valid=7be00bcd76fc39373fe3bf5927ce0fd5
set ofile=Top Secret (Japan, revision B).rom
set fullname=Top Secret (Japan, revision B)
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
echo  ___   _   ___   _      _   __        __    ___   _      _       __    _      ___   ___  
echo ^| ^|_) ^| ^| / / \ ^| ^|\ ^| ^| ^| / /`      / /`  / / \ ^| ^|\/^| ^| ^|\/^|  / /\  ^| ^|\ ^| ^| ^| \ / / \ 
echo ^|_^|_) ^|_^| \_\_/ ^|_^| \^| ^|_^| \_\_,     \_\_, \_\_/ ^|_^|  ^| ^|_^|  ^| /_/--\ ^|_^| \^| ^|_^|_/ \_\_/ 

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
echo Copy JTBIOCOM.rom to SDCard's root or bootrom folder (mister) and the other roms to JTBIOCOM folder.
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


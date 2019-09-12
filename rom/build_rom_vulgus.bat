rem version 2.20 - 2019/08/16 by Bruno Silva
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2 
Title Vulgus's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

:MENU
cls
echo                                          _____                                   
echo `.           .' ^|         ^| ^|         .-~     ~.  ^|         ^|             ..'''' 
echo   `.       .'   ^|         ^| ^|        :            ^|         ^|          .''       
echo     `.   .'     ^|         ^| ^|        :     _____  ^|         ^|       ..'          
echo       `.'       `._______.' ^|_______  `-._____.'^| `._______.' ....''             

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
echo 1 - Vulgus (set 1) - Default
echo 2 - Mach-9 (bootleg of Vulgus)
echo 3 - Vulgus (Japan?)
echo 4 - Vulgus (set 2)

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
IF '%M%'=='1' GOTO VULGUS
IF '%M%'=='2' GOTO MACH9
IF '%M%'=='3' GOTO VULGUSJ
IF '%M%'=='4' GOTO VULGUSA

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

:VULGUS
set zip1m=MAME\vulgus.zip
set ifilesm=vulgus.002+vulgus.003+vulgus.004+vulgus.005+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
set zip1=MAME\vulgus.zip
set ifiles=vulgus.002+vulgus.003+vulgus.004+vulgus.005+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
set md5valid=410250f0a3af08ead86b4ddd8dd78006
set ofile=JTVULGUS.ROM
set fullname=Vulgus (set 1) - Default
GOTO START

:MACH9
set zip1m=MAME\vulgus.zip
set ifilesm=mach9\02_4n.bin+vulgus.003+vulgus.004+mach9\05_7n.bin+1-8n.bin+1-11c.bin+1-11c.bin+mach9\01_3d.bin+2-4a.bin+mach9\11_5a.bin+2-2a.bin+mach9\09_3a.bin+2-6a.bin+mach9\13_7a.bin+2-6a.bin+mach9\13_7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+mach9\82s129_10e.bin+d1.bin+j2.bin+82s129.8n
set zip1=MAME\mach9.zip
set ifiles=02_4n.bin+03_5n.bin+04_6n.bin+05_7n.bin+06_8n.bin+07_11c.bin+07_11c.bin+01_3d.bin+10_4a.bin+11_5a.bin+08_2a.bin+09_3a.bin+12_6a.bin+13_7a.bin+12_6a.bin+13_7a.bin+16_4n.bin+17_5n.bin+14_2n.bin+15_3n.bin+82s129_9k.bin+82s129_9c.bin+82s129_9c.bin+82s129_9c.bin+82s129_8e.bin+82s129_9e.bin+82s129_10e.bin+82s129_1d.bin+82s129_2j.bin+82s129_8n.bin
set md5valid=eb03683437787decdc1b80c689baff6d
set ofile=Mach-9 (bootleg of Vulgus).rom
set fullname=Mach-9 (bootleg of Vulgus)
GOTO START

:VULGUSJ
set zip1m=MAME\vulgus.zip
set ifilesm=vulgusj\1-4n.bin+vulgusj\1-5n.bin+vulgusj\1-6n.bin+vulgusj\1-7n.bin+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
set zip1=MAME\vulgusj.zip
set ifiles=1-4n.bin+1-5n.bin+1-6n.bin+1-7n.bin+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
set md5valid=8515013723d82c947293f8d17f37549a
set ofile=Vulgus (Japan).rom
set fullname=Vulgus (Japan?)
GOTO START

:VULGUSA
set zip1m=MAME\vulgus.zip
set ifilesm=vulgusa\v2+vulgusa\v3+vulgusa\v4+vulgusa\v5+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
set zip1=MAME\vulgusa.zip
set ifiles=v2+v3+v4+v5+1-8n.bin+1-11c.bin+1-11c.bin+1-3d.bin+2-4a.bin+2-5a.bin+2-2a.bin+2-3a.bin+2-6a.bin+2-7a.bin+2-6a.bin+2-7a.bin+2-4n.bin+2-5n.bin+2-2n.bin+2-3n.bin+82s126.9k+c9.bin+c9.bin+c9.bin+e8.bin+e9.bin+e10.bin+d1.bin+j2.bin+82s129.8n
set md5valid=cc7ff45328905f65aa6866e90260d081
set ofile=Vulgus (set 2).rom
set fullname=Vulgus (set 2)
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
echo                                          _____                                   
echo `.           .' ^|         ^| ^|         .-~     ~.  ^|         ^|             ..'''' 
echo   `.       .'   ^|         ^| ^|        :            ^|         ^|          .''       
echo     `.   .'     ^|         ^| ^|        :     _____  ^|         ^|       ..'          
echo       `.'       `._______.' ^|_______  `-._____.'^| `._______.' ....''             

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
echo Copy JTVULGUS.ROM to SDCard's root or bootrom folder (mister) and the other roms to JTVULGUS.ROM folder.
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


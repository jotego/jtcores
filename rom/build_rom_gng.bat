rem version 2.20 - 2019/08/16 by Bruno Silva
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2 
Title Ghosts'n Goblins's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

:MENU
cls
echo  _______  __   __  _______  _______  _______  _______  __   __    _    _______  _______  _______  ___      ___   __    _  _______ 
echo ^|       ^|^|  ^| ^|  ^|^|       ^|^|       ^|^|       ^|^|       ^|^|  ^| ^|  ^|  ^| ^|  ^|       ^|^|       ^|^|  _    ^|^|   ^|    ^|   ^| ^|  ^|  ^| ^|^|       ^|
echo ^|    ___^|^|  ^|_^|  ^|^|   _   ^|^|  _____^|^|_     _^|^|  _____^|^|__^| ^|   ^|_^| ^|  ^|    ___^|^|   _   ^|^| ^|_^|   ^|^|   ^|    ^|   ^| ^|   ^|_^| ^|^|  _____^|
echo ^|   ^| __ ^|       ^|^|  ^| ^|  ^|^| ^|_____   ^|   ^|  ^| ^|_____      ^|       ^|  ^|   ^| __ ^|  ^| ^|  ^|^|       ^|^|   ^|    ^|   ^| ^|       ^|^| ^|_____ 
echo ^|   ^|^|  ^|^|       ^|^|  ^|_^|  ^|^|_____  ^|  ^|   ^|  ^|_____  ^|     ^|  _    ^|  ^|   ^|^|  ^|^|  ^|_^|  ^|^|  _   ^| ^|   ^|___ ^|   ^| ^|  _    ^|^|_____  ^|
echo ^|   ^|_^| ^|^|   _   ^|^|       ^| _____^| ^|  ^|   ^|   _____^| ^|     ^| ^| ^|   ^|  ^|   ^|_^| ^|^|       ^|^| ^|_^|   ^|^|       ^|^|   ^| ^| ^| ^|   ^| _____^| ^|
echo ^|_______^|^|__^| ^|__^|^|_______^|^|_______^|  ^|___^|  ^|_______^|     ^|_^|  ^|__^|  ^|_______^|^|_______^|^|_______^|^|_______^|^|___^| ^|_^|  ^|__^|^|_______^|

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
echo 1 - Ghosts'n Goblins (World? set 1) - Default
echo 2 - Ghosts'n Goblins (Italian bootleg, harder)
echo 3 - Ghosts'n Goblins (US)
echo 4 - Ghosts'n Goblins (World? set 3)
echo 5 - Makai-Mura (Japan Revision C)
echo 6 - Makai-Mura (Japan Revision G)
echo 7 - Makai-Mura (Japan)

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
IF '%M%'=='1' GOTO GNG
IF '%M%'=='2' GOTO GNGBLITA
IF '%M%'=='3' GOTO GNGT
IF '%M%'=='4' GOTO GNGC
IF '%M%'=='5' GOTO MAKAIMURC
IF '%M%'=='6' GOTO MAKAIMURG
IF '%M%'=='7' GOTO MAKAIMUR

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

:GNG
set zip1m=MAME\gng.zip
set ifilesm=gg3.bin+gg4.bin+gg5.bin+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gg17.bin+gg16.bin+gg15.bin+gg15.bin+gg14.bin+gg13.bin+gg12.bin+gg12.bin
set zip1=MAME\gng.zip
set ifiles=gg3.bin+gg4.bin+gg5.bin+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gg17.bin+gg16.bin+gg15.bin+gg15.bin+gg14.bin+gg13.bin+gg12.bin+gg12.bin
set md5valid=41a39ea05a8bf15526ca05e0894c248f
set ofile=jtgng.rom
set fullname=Ghosts'n Goblins (World? set 1) - Default
GOTO START

:GNGBLITA
set zip1m=MAME\gng.zip
set ifilesm=gngblita\4-5+gngblita\3+gngblita\1-2+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gg17.bin+gg16.bin+gg15.bin+gg15.bin+gg14.bin+gg13.bin+gg12.bin+gg12.bin
set zip1=MAME\gngblita.zip
set ifiles=4-5+3+1-2+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gg17.bin+gg16.bin+gg15.bin+gg15.bin+gg14.bin+gg13.bin+gg12.bin+gg12.bin
set md5valid=3da9708518bfb1b90ba960b22f71e0c9
set ofile=Ghosts'n Goblins (Italian bootleg, harder).rom
set fullname=Ghosts'n Goblins (Italian bootleg, harder)
GOTO START

:GNGT
set zip1m=MAME\gng.zip
set ifilesm=gngt\mmt03d.8n+gngt\mmt04d.10n+gngt\mmt05d.13n+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gg17.bin+gg16.bin+gg15.bin+gg15.bin+gg14.bin+gg13.bin+gg12.bin+gg12.bin
set zip1=MAME\gngt.zip
set ifiles=mmt03d.8n+mmt04d.10n+mmt05d.13n+mm01.11e+mm02.14h+mm09.3c+mm08.1c+mm07.3b+mm06.1b+mm11.3e+mm10.1e+mm11.3e+mm10.1e+mm17.4n+mm16.3n+mm15.1n+mm15.1n+mm14.4l+mm13.3l+mm12.1l+mm12.1l
set md5valid=205229cb8941ae2ab651777018f91826
set ofile=Ghosts'n Goblins (US).rom
set fullname=Ghosts'n Goblins (US)
GOTO START

:GNGC
set zip1m=MAME\gng.zip
set ifilesm=gngc\mm_c_03+gngc\mm_c_04+gngblita\1-2+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gg17.bin+gg16.bin+gg15.bin+gg15.bin+gg14.bin+gg13.bin+gg12.bin+gg12.bin
set zip1=MAME\gngc.zip
set ifiles=mm_c_03+mm_c_04+mm_c_05+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gg17.bin+gg16.bin+gg15.bin+gg15.bin+gg14.bin+gg13.bin+gg12.bin+gg12.bin
set md5valid=682b65e318744430685085daf95eb899
set ofile=Ghosts'n Goblins (World set 3).rom
set fullname=Ghosts'n Goblins (World? set 3)
GOTO START

:MAKAIMURC
set zip1m=MAME\gng.zip
set ifilesm=makaimurc\mj03c.bin+makaimurc\mj04c.bin+makaimurc\mj05c.bin+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gngbl\19.84472.4n+gg16.bin+gg15.bin+gg15.bin+gngbl\16.84472.4l+gg13.bin+gg12.bin+gg12.bin
set zip1=MAME\makaimurc.zip
set ifiles=mj03c.bin+mj04c.bin+mj05c.bin+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gng13.n4+gg16.bin+gg15.bin+gg15.bin+gng16.l4+gg13.bin+gg12.bin+gg12.bin
set md5valid=4986f3d2522f8461206db2bd3bc5bc6b
set ofile=Makai-Mura (Japan Revision C).rom
set fullname=Makai-Mura (Japan Revision C)
GOTO START

:MAKAIMURG
set zip1m=MAME\gng.zip
set ifilesm=makaimurg\mj03g.bin+makaimurg\mj04g.bin+makaimurg\mj05g.bin+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gngbl\19.84472.4n+gg16.bin+gg15.bin+gg15.bin+gngbl\16.84472.4l+gg13.bin+gg12.bin+gg12.bin
set zip1=MAME\makaimurg.zip
set ifiles=mj03g.bin+mj04g.bin+mj05g.bin+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gng13.n4+gg16.bin+gg15.bin+gg15.bin+gng16.l4+gg13.bin+gg12.bin+gg12.bin
set md5valid=b2c45890c22b282f6a1e799cfdc4c700
set ofile=Makai-Mura (Japan Revision G).rom
set fullname=Makai-Mura (Japan Revision G)
GOTO START

:MAKAIMUR
set zip1m=MAME\gng.zip
set ifilesm=makaimur\8n.rom+makaimur\10n.rom+makaimur\12n.rom+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gngbl\19.84472.4n+gg16.bin+gg15.bin+gg15.bin+gngbl\16.84472.4l+gg13.bin+gg12.bin+gg12.bin
set zip1=MAME\makaimur.zip
set ifiles=8n.rom+10n.rom+12n.rom+gg1.bin+gg2.bin+gg9.bin+gg8.bin+gg7.bin+gg6.bin+gg11.bin+gg10.bin+gg11.bin+gg10.bin+gng13.n4+gg16.bin+gg15.bin+gg15.bin+gng16.l4+gg13.bin+gg12.bin+gg12.bin
set md5valid=f80a619acf3e03db0b5c38e1559d9932
set ofile=Makai-Mura (Japan).rom
set fullname=Makai-Mura (Japan)
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
echo  _______  __   __  _______  _______  _______  _______  __   __    _    _______  _______  _______  ___      ___   __    _  _______ 
echo ^|       ^|^|  ^| ^|  ^|^|       ^|^|       ^|^|       ^|^|       ^|^|  ^| ^|  ^|  ^| ^|  ^|       ^|^|       ^|^|  _    ^|^|   ^|    ^|   ^| ^|  ^|  ^| ^|^|       ^|
echo ^|    ___^|^|  ^|_^|  ^|^|   _   ^|^|  _____^|^|_     _^|^|  _____^|^|__^| ^|   ^|_^| ^|  ^|    ___^|^|   _   ^|^| ^|_^|   ^|^|   ^|    ^|   ^| ^|   ^|_^| ^|^|  _____^|
echo ^|   ^| __ ^|       ^|^|  ^| ^|  ^|^| ^|_____   ^|   ^|  ^| ^|_____      ^|       ^|  ^|   ^| __ ^|  ^| ^|  ^|^|       ^|^|   ^|    ^|   ^| ^|       ^|^| ^|_____ 
echo ^|   ^|^|  ^|^|       ^|^|  ^|_^|  ^|^|_____  ^|  ^|   ^|  ^|_____  ^|     ^|  _    ^|  ^|   ^|^|  ^|^|  ^|_^|  ^|^|  _   ^| ^|   ^|___ ^|   ^| ^|  _    ^|^|_____  ^|
echo ^|   ^|_^| ^|^|   _   ^|^|       ^| _____^| ^|  ^|   ^|   _____^| ^|     ^| ^| ^|   ^|  ^|   ^|_^| ^|^|       ^|^| ^|_^|   ^|^|       ^|^|   ^| ^| ^| ^|   ^| _____^| ^|
echo ^|_______^|^|__^| ^|__^|^|_______^|^|_______^|  ^|___^|  ^|_______^|     ^|_^|  ^|__^|  ^|_______^|^|_______^|^|_______^|^|_______^|^|___^| ^|_^|  ^|__^|^|_______^|

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
echo Copy jtgng.rom to SDCard's root or bootrom folder (mister) and the other roms to jtgng folder.
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


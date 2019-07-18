rem version 2.01 - 2019/07/16
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2 
Title Commando's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

:MENU
cls
echo  _____                                           _       
echo /  __ \                                         ^| ^|      
echo ^| /  \/ ___  _ __ ___  _ __ ___   __ _ _ __   __^| ^| ___  
echo ^| ^|    / _ \^| '_ ` _ \^| '_ ` _ \ / _` ^| '_ \ / _` ^|/ _ \ 
echo ^| \__/\ (_) ^| ^| ^| ^| ^| ^| ^| ^| ^| ^| ^| (_^| ^| ^| ^| ^| (_^| ^| (_) ^|
echo  \____/\___/^|_^| ^|_^| ^|_^|_^| ^|_^| ^|_^|\__,_^|_^| ^|_^|\__,_^|\___/ 

echo.
if %merged% EQU 0 (
echo Copy Mame Non-Merged set files to !pwd!MAME folder
) else (
echo Copy Mame Merged set files to !pwd!MAME folder
)
echo Copy HBMame Merged set files to !pwd!HBMAME folder
echo.
echo Press H for Help
echo.
echo ** MENU **
echo 1 - Commando (World) - commando.zip (Mame) - ORIGINAL
echo 2 - Commando (US set 1) - commandou.zip (Mame)
echo 3 - Senjou no Ookami - commandoj.zip (Mame)
echo 4 - Commando (bootleg set 1) - commandob.zip (Mame)
echo 5 - Commando (bootleg set 2) - commandob2.zip (Mame)
echo 6 - Commando (US set 2) - commandou2.zip (Mame)
echo 7 - Space Invasion (Europe) - sinvasn.zip (Mame)
echo 8 - Space Invasion (bootleg) - sinvasnb.zip (Mame)
echo 9 - Mercenario (Commando bootleg) - mercenario.zip (Mame)
echo 10 - Commando Deluxe - commando.zip (HBMame)
echo 11 - Commando Deluxe Again - commando.zip (HBMame)
echo.

if %merged% EQU 0 (
echo C - Change from Non-Merged to Merged MAME ROM SET
) else (
echo C - Change from Merged to Non-Merged MAME ROM SET
)
echo H - HELP
if "%verb%" EQU "" (
echo V - Set verbose Off
) else (
echo V - Set verbose On
)
echo Q - Quit


if NOT EXIST "!pwd!MAME" mkdir "!pwd!MAME" 2> nul
if NOT EXIST "!pwd!HBMAME" mkdir "!pwd!HBMAME" 2> nul
echo.
SET /P M="Choose option and then press ENTER (or Q to quit): "
IF '%M%'=='1' GOTO COMMANDO
IF '%M%'=='2' GOTO COMMANDOU
IF '%M%'=='3' GOTO COMMANDOJ
IF '%M%'=='4' GOTO COMMANDOB
IF '%M%'=='5' GOTO COMMANDOB2
IF '%M%'=='6' GOTO COMMANDOU2
IF '%M%'=='7' GOTO SINVASN
IF '%M%'=='8' GOTO SINVASNB
IF '%M%'=='9' GOTO MERCENARIO
IF '%M%'=='10' GOTO COMDELUXHB
IF '%M%'=='11' GOTO COMDLUX1HB

IF '%M%'=='c' GOTO CHANGEMERGED
IF '%M%'=='C' GOTO CHANGEMERGED

IF '%M%'=='h' GOTO HELP
IF '%M%'=='H' GOTO HELP
IF '%M%'=='v' GOTO VERBOSE
IF '%M%'=='V' GOTO VERBOSE
IF '%M%'=='q' GOTO QUIT
IF '%M%'=='Q' GOTO QUIT

GOTO MENU

:COMMANDO
set zip1m=MAME\commando.zip
set ifilesm=cm04.9m+cm03.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=MAME\commando.zip
set ifiles=cm04.9m+cm03.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=5ba63333cd074858f8303dfbcb885c17
set ofile=a.commando.rom
set fullname=Commando (World) - commando.zip (Mame) - ORIGINAL
GOTO START

:COMMANDOU
set zip1m=MAME\commando.zip
set ifilesm=commandou\u4-f.9m+commandou\u3-f.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=MAME\commandou.zip
set ifiles=u4-f.9m+u3-f.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=db9d4c87634d826a8146b32a65afd5fe
set ofile=Commando (US set 1).rom
set fullname=Commando (US set 1) - commandou.zip (Mame)
GOTO START

:COMMANDOJ
set zip1m=MAME\commando.zip
set ifilesm=commandoj\so04.9m+commandoj\so03.8m+"commandob2\8,so02.9f"+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=MAME\commandoj.zip
set ifiles=so04.9m+so03.8m+so02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=c5c4e016fc69e6b5df21f169202f2d27
set ofile=Senjou no Ookami.rom
set fullname=Senjou no Ookami - commandoj.zip (Mame)
GOTO START

:COMMANDOB
set zip1m=MAME\commando.zip
set ifilesm=commandob\commandob_04_9m_27256.bin+cm03.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=MAME\commandob.zip
set ifiles=commandob_04_9m_27256.bin+cm03.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=f8dde8679dd76751f4229d2d40ed7d1a
set ofile=Commando (bootleg set 1).rom
set fullname=Commando (bootleg set 1) - commandob.zip (Mame)
GOTO START

:COMMANDOB2
set zip1m=MAME\commando.zip
set ifilesm="commandob2\10"+"commandob2\11"+"commandob2\8,so02.9f"+"vt01.5d"+"vt11.5a"+"vt12.6a"+"vt15.9a"+"vt16.10a"+"vt13.7a"+"vt14.8a"+"vt15.9a"+"vt16.10a"+"vt05.7e"+"vt06.8e"+"vt07.9e"+"vt08.7h"+"vt09.8h"+"vt10.9h"+"vtb1.1d"+"vtb2.2d"+"vtb3.3d"+"vtb4.1h"+"vtb5.6l"+"vtb6.6e"
set zip1=MAME\commandob2.zip
set ifiles="10"+"11"+"8,so02.9f"+"7,vt01.5d"+"17,vt11.5a"+"16,vt12.6a"+"13,vt15.9a"+"12,vt16.10a"+"15,vt13.7a"+"14,vt14.8a"+"13,vt15.9a"+"12,vt16.10a"+"3,vt05.7e"+"2,vt06.8e"+"1,vt07.9e"+"6,vt08.7h"+"5,vt09.8h"+"4,vt10.9h"+"vtb1.1d"+"vtb2.2d"+"vtb3.3d"+"vtb4.1h"+"vtb5.6l"+"vtb6.6e"
set md5valid=118ed2e2913f1e89acbacf81ea43ee73
set ofile=Commando (bootleg set 2).rom
set fullname=Commando (bootleg set 2) - commandob2.zip (Mame)
GOTO START

:COMMANDOU2
set zip1m=MAME\commando.zip
set ifilesm=commandou2\uc4.9m+commandou2\uc3.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=MAME\commandou2.zip
set ifiles=uc4.9m+uc3.8m+cd02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb-1.1d+vtb-2.2d+vtb-3.3d+vtb-4.1h+vtb-5.6l+vtb-6.6e
set md5valid=b1b84583f097374a90de68f0f14d2501
set ofile=Commando (US set 2).rom
set fullname=Commando (US set 2) - commandou2.zip (Mame)
GOTO START

:SINVASN
set zip1m=MAME\commando.zip
set ifilesm=sinvasn\sp04.9m+sinvasn\sp03.8m+sinvasn\u2.9f+sinvasn\u1.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+sinvasn\u5.e7+sinvasn\sp06.e8+sinvasn\sp07.e9+sinvasn\u8.h7+sinvasn\sp09.h8+sinvasn\sp10.h9+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=MAME\sinvasn.zip
set ifiles=sp04.9m+sp03.8m+u2.9f+u1.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+u5.e7+sp06.e8+sp07.e9+u8.h7+sp09.h8+sp10.h9+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=3249eacf00cb6be091944d38eb29db9e
set ofile=Space Invasion (Europe).rom
set fullname=Space Invasion (Europe) - sinvasn.zip (Mame)
GOTO START

:SINVASNB
set zip1m=MAME\commando.zip
set ifilesm=sinvasnb\u4+sinvasnb\u3+sinvasn\u2.9f+sinvasn\u1.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+sinvasn\u5.e7+vt06.8e+vt07.9e+sinvasn\u8.h7+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=MAME\sinvasnb.zip
set ifiles=u4+u3+u2+u1+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+u5+vt06.e8+vt07.e9+u8+vt09.h8+vt10.h9+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=764ef00e691dfcf4a682226426ee8606
set ofile=Space Invasion (bootleg).rom
set fullname=Space Invasion (bootleg) - sinvasnb.zip (Mame)
GOTO START

:MERCENARIO
set zip1m=MAME\commando.zip
set ifilesm=mercenario\4ac.bin+mercenario\4bc.bin+mercenario\3c.8m+cm02.9f+mercenario\1c.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=MAME\mercenario.zip
set ifiles=4ac.bin+4bc.bin+3c.8m+cm02.9f+1c.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+vt05.7e+vt06.8e+vt07.9e+vt08.7h+vt09.8h+vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=ec4d0f8d3b1330eed8ab958c3e2ec0a5
set ofile=Mercenario (Commando bootleg).rom
set fullname=Mercenario (Commando bootleg) - mercenario.zip (Mame)
GOTO START

:COMDELUXHB
set zip1m=HBMAME\commando.zip
set ifilesm=cm04.9m+cm03.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+comdelux\dx_vt05.7e+vt06.8e+comdelux\dx_vt07.9e+comdelux\dx_vt08.7h+vt09.8h+comdelux\dx_vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=HBMAME\commando.zip
set ifiles=cm04.9m+cm03.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+comdelux\dx_vt05.7e+vt06.8e+comdelux\dx_vt07.9e+comdelux\dx_vt08.7h+vt09.8h+comdelux\dx_vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=da24fcf65015675db696af1c8eaff8ef
set ofile=Commando Deluxe - HB.rom
set fullname=Commando Deluxe - commando.zip (HBMame)
GOTO START

:COMDLUX1HB
set zip1m=HBMAME\commando.zip
set ifilesm=cm04.9m+cm03.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+comdlux1\dx1_vt05.7e+vt06.8e+comdelux\dx_vt07.9e+comdlux1\dx1_vt08.7h+vt09.8h+comdelux\dx_vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set zip1=HBMAME\commando.zip
set ifiles=cm04.9m+cm03.8m+cm02.9f+vt01.5d+vt11.5a+vt12.6a+vt15.9a+vt16.10a+vt13.7a+vt14.8a+vt15.9a+vt16.10a+comdlux1\dx1_vt05.7e+vt06.8e+comdelux\dx_vt07.9e+comdlux1\dx1_vt08.7h+vt09.8h+comdelux\dx_vt10.9h+vtb1.1d+vtb2.2d+vtb3.3d+vtb4.1h+vtb5.6l+vtb6.6e
set md5valid=bca4e0cfc8d09094bbb065d285c8370e
set ofile=Commando Deluxe Again - HB.rom
set fullname=Commando Deluxe Again - commando.zip (HBMame)
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
echo  _____                                           _       
echo /  __ \                                         ^| ^|      
echo ^| /  \/ ___  _ __ ___  _ __ ___   __ _ _ __   __^| ^| ___  
echo ^| ^|    / _ \^| '_ ` _ \^| '_ ` _ \ / _` ^| '_ \ / _` ^|/ _ \ 
echo ^| \__/\ (_) ^| ^| ^| ^| ^| ^| ^| ^| ^| ^| ^| (_^| ^| ^| ^| ^| (_^| ^| (_) ^|
echo  \____/\___/^|_^| ^|_^| ^|_^|_^| ^|_^| ^|_^|\__,_^|_^| ^|_^|\__,_^|\___/ 

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


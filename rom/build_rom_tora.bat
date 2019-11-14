rem version 2.20 - 2019/08/16 by Bruno Silva
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2 
Title Tiger Road's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

:MENU
cls
echo ^>^<^<^< ^>^<^<^<^<^<^<                                  ^>^<^<^<^<^<^<^<                             ^>^<^<
echo      ^>^<^<     ^>^<                               ^>^<^<    ^>^<^<                           ^>^<^<
echo      ^>^<^<          ^>^<^<      ^>^<^<    ^>^< ^>^<^<^<     ^>^<^<    ^>^<^<     ^>^<^<       ^>^<^<         ^>^<^<
echo      ^>^<^<    ^>^<^< ^>^<^<  ^>^<^< ^>^<   ^>^<^<  ^>^<^<        ^>^< ^>^<^<       ^>^<^<  ^>^<^<  ^>^<^<  ^>^<^<  ^>^<^< ^>^<^<
echo      ^>^<^<    ^>^<^<^>^<^<   ^>^<^<^>^<^<^<^<^< ^>^<^< ^>^<^<        ^>^<^<  ^>^<^<    ^>^<^<    ^>^<^<^>^<^<   ^>^<^< ^>^<   ^>^<^<
echo      ^>^<^<    ^>^<^< ^>^<^<  ^>^<^<^>^<         ^>^<^<        ^>^<^<    ^>^<^<   ^>^<^<  ^>^<^< ^>^<^<   ^>^<^< ^>^<   ^>^<^<
echo      ^>^<^<    ^>^<^<     ^>^<^<   ^>^<^<^<^<   ^>^<^<^<        ^>^<^<      ^>^<^<   ^>^<^<      ^>^<^< ^>^<^<^< ^>^<^< ^>^<^<
echo                  ^>^<^<                                                                  

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
echo 1 - Tiger Road (US) - Default
echo 2 - Tiger Road (US, Romstar license)
echo 3 - Tora e no Michi (Japan)

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
IF '%M%'=='1' GOTO TIGEROAD
IF '%M%'=='2' GOTO TIGEROADU
IF '%M%'=='3' GOTO TORAMICH

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

:TIGEROAD
set zip1m=MAME\tigeroad.zip
set ifilesm=tre_02.6j+tre_04.6k+tru_05.12k+tru_05.12k+tru_05.12k+tr_01.10d+tr_13.7l+tr_13.7l+tr-03a.2f+tr-06a.2h+tr-07a.2j+tr_08.2l+tr-01a.3f+tr-04a.3h+tr-02a.3j+tr-05.3l+tr-12a.2d+tr-11a.3d+tr-10a.2b+tr-09a.3b+tr.9e
set zip1=MAME\tigeroad.zip
set ifiles=tre_02.6j+tre_04.6k+tru_05.12k+tru_05.12k+tru_05.12k+tr_01.10d+tr_13.7l+tr_13.7l+tr-03a.2f+tr-06a.2h+tr-07a.2j+tr_08.2l+tr-01a.3f+tr-04a.3h+tr-02a.3j+tr-05.3l+tr-12a.2d+tr-11a.3d+tr-10a.2b+tr-09a.3b+tr.9e
set md5valid=153ab39a778af8b5b2240d9d1719ca97
set ofile=JTTORA.rom
set fullname=Tiger Road (US) - Default
GOTO START

:TIGEROADU
set zip1m=MAME\tigeroad.zip
set ifilesm=tigeroadu\tru_02.6j+tigeroadu\tru_04.6k+tru_05.12k+tru_05.12k+tru_05.12k+tr_01.10d+tr_13.7l+tr_13.7l+tr-03a.2f+tr-06a.2h+tr-07a.2j+tr_08.2l+tr-01a.3f+tr-04a.3h+tr-02a.3j+tr-05.3l+tr-12a.2d+tr-11a.3d+tr-10a.2b+tr-09a.3b+tr.9e
set zip1=MAME\tigeroadu.zip
set ifiles=tru_02.6j+tru_04.6k+tru_05.12k+tru_05.12k+tru_05.12k+tr_01.10d+tr_13.7l+tr_13.7l+tr-03a.2f+tr-06a.2h+tr-07a.2j+tr_08.2l+tr-01a.3f+tr-04a.3h+tr-02a.3j+tr-05.3l+tr-12a.2d+tr-11a.3d+tr-10a.2b+tr-09a.3b+tr.9e
set md5valid=42e21e4872ce725031d6511a7e4c1f27
set ofile=Tiger Road (US, Romstar license).rom
set fullname=Tiger Road (US, Romstar license)
GOTO START

:TORAMICH
set zip1m=MAME\tigeroad.zip
set ifilesm=toramich\tr_02.6j+toramich\tr_04.6k+toramich\tr_05.12k+toramich\tr_03.11j+tr_01.10d+tr_13.7l+tr_13.7l+tr-03a.2f+tr-06a.2h+tr-07a.2j+tr_08.2l+tr-01a.3f+tr-04a.3h+tr-02a.3j+tr-05.3l+tr-12a.2d+tr-11a.3d+tr-10a.2b+tr-09a.3b+tr.9e
set zip1=MAME\toramich.zip
set ifiles=tr_02.6j+tr_04.6k+tr_05.12k+tr_03.11j+tr_01.10d+tr_13.7l+tr_13.7l+tr-03a.2f+tr-06a.2h+tr-07a.2j+tr_08.2l+tr-01a.3f+tr-04a.3h+tr-02a.3j+tr-05.3l+tr-12a.2d+tr-11a.3d+tr-10a.2b+tr-09a.3b+tr.9e
set md5valid=2542a73d07de52ad2fd1c9fecd96ef5a
set ofile=Tora e no Michi (Japan).rom
set fullname=Tora e no Michi (Japan)
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
echo ^>^<^<^< ^>^<^<^<^<^<^<                                  ^>^<^<^<^<^<^<^<                             ^>^<^<
echo      ^>^<^<     ^>^<                               ^>^<^<    ^>^<^<                           ^>^<^<
echo      ^>^<^<          ^>^<^<      ^>^<^<    ^>^< ^>^<^<^<     ^>^<^<    ^>^<^<     ^>^<^<       ^>^<^<         ^>^<^<
echo      ^>^<^<    ^>^<^< ^>^<^<  ^>^<^< ^>^<   ^>^<^<  ^>^<^<        ^>^< ^>^<^<       ^>^<^<  ^>^<^<  ^>^<^<  ^>^<^<  ^>^<^< ^>^<^<
echo      ^>^<^<    ^>^<^<^>^<^<   ^>^<^<^>^<^<^<^<^< ^>^<^< ^>^<^<        ^>^<^<  ^>^<^<    ^>^<^<    ^>^<^<^>^<^<   ^>^<^< ^>^<   ^>^<^<
echo      ^>^<^<    ^>^<^< ^>^<^<  ^>^<^<^>^<         ^>^<^<        ^>^<^<    ^>^<^<   ^>^<^<  ^>^<^< ^>^<^<   ^>^<^< ^>^<   ^>^<^<
echo      ^>^<^<    ^>^<^<     ^>^<^<   ^>^<^<^<^<   ^>^<^<^<        ^>^<^<      ^>^<^<   ^>^<^<      ^>^<^< ^>^<^<^< ^>^<^< ^>^<^<
echo                  ^>^<^<                                                                  

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
echo Copy JTTORA.rom to SDCard's root or bootrom folder (mister) and the other roms to JTTORA folder.
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

